<#
.SYNOPSIS
    Oppretter de tre endringsordrene i oblig 2 som Issues.

.DESCRIPTION
    Kjør det fra rota av repoet ditt, når migreringen er ferdig:

        .\Endringsordrer.ps1
        .\Endringsordrer.ps1 -Kortnavn <ditt-kortnavn>

    Kortnavnet leses fra config/felles.tfvars hvis du ikke oppgir det.
    Verdiene i ordrene regnes ut fra kortnavnet, så ingen to studenter får de
    samme. Selvtesten regner ut de samme verdiene og kontrollerer K10.

    Skriptet nekter å kjøre før network, data og app er borte fra
    state-kontoen. Ordrene skal løses i den nye strukturen.

    Trenger: git, az (innlogget) og gh (innlogget, med tilgang til repoet).
    Oppretter bare Issues som ikke finnes fra før, så det er trygt å kjøre
    flere ganger.

    Denne fila skal gi nøyaktig de samme Issuene som endringsordrer.sh.
    Endrer du den ene, endrer du den andre.

    Virker i Windows PowerShell 5.1 (den som følger med Windows) og i
    PowerShell 7.

    Får du «cannot be loaded because running scripts is disabled on this
    system», er det Windows' standardinnstilling som stopper deg - ikke noe
    galt med skriptet. Start det slik i stedet:

        powershell -ExecutionPolicy Bypass -File .\Endringsordrer.ps1

    Det gjelder bare den ene kjøringen, og endrer ingen innstilling.

.PARAMETER Kortnavn
    Kortnavnet ditt. Må være det samme som i config/felles.tfvars.

.EXAMPLE
    .\Endringsordrer.ps1
#>

[CmdletBinding()]
param(
    [string]$Kortnavn = ""
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Argumenter med " i (gh --search og jq-uttrykket) skrives med \" og sendes
# slik Windows PowerShell 5.1 gjør det. PowerShell 7.3+ har en annen standard,
# så vi ber om den gamle, ellers blir argumentene ulike i 5.1 og 7.
$PSNativeCommandArgumentPassing = 'Legacy'

# ---------------------------------------------------------------------------
#  Verdiene. Samme utregning i selvtesten, i bash-utgavene og på
#  endringsordrer.html. Endrer du den her, må du endre den alle stedene.
# ---------------------------------------------------------------------------
function Set-Verdier {
    param([string]$Navn)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("oblig2:$Navn"))
    $h = -join ($hash | ForEach-Object { $_.ToString("x2") })
    $script:EoPort = 8000 + ([Convert]::ToInt32($h.Substring(0, 4), 16) % 1000)
    $script:EoKilde = "172.16.$([Convert]::ToInt32($h.Substring(4, 2), 16)).0/24"
    $script:EoOktett = 2 + ([Convert]::ToInt32($h.Substring(6, 2), 16) % 248)
    if (([Convert]::ToInt32($h.Substring(8, 2), 16) % 2) -eq 0) { $script:EoNavn = "sok" } else { $script:EoNavn = "betal" }
    $script:EoDev = "10.10.$($script:EoOktett).0/24"
    $script:EoProd = "10.20.$($script:EoOktett).0/24"
}

function Get-Sti {
    param([string]$Rel)
    return (Join-Path (Get-Location).Path $Rel)
}

function Get-FilVerdi {
    param([string]$Fil, [string]$Nokkel)
    $sti = Get-Sti $Fil
    if (-not (Test-Path -LiteralPath $sti -PathType Leaf)) { return "" }
    try { $tekst = [System.IO.File]::ReadAllText($sti) } catch { return "" }
    $m = '[ \t\v\f\r]'
    $monster = '^' + $m + '*' + $Nokkel + $m + '*=' + $m + '*"([^"]*)"'
    foreach ($linje in ($tekst -split "`n")) {
        if ($linje -cmatch $monster) { return $Matches[1] }
    }
    return ""
}

# Utdata fra et eksternt program som én tekst, slik $(...) gir den i bash.
function ConvertTo-Tekst {
    param($Ut)
    if ($null -eq $Ut) { return "" }
    $s = (@($Ut) | ForEach-Object { "$_" }) -join "`n"
    $s = $s.Replace("`r", "")
    return $s.TrimEnd("`n")
}

# Skriver til stderr og avslutter, som stopp i bash.
function Stopp {
    param([string]$Tekst)
    $Host.UI.WriteErrorLine("`n  $Tekst`n")
    exit 1
}

# ---------------------------------------------------------------------------
#  Forutsetninger
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath (Get-Sti ".git") -PathType Container)) { Stopp "Kjør skriptet fra rota av repoet ditt (der .git ligger)." }
if (-not (Test-Path -LiteralPath (Get-Sti "config/felles.tfvars") -PathType Leaf)) { Stopp "Fant ikke config/felles.tfvars. Er dette repoet for oblig 2?" }
if (-not (Test-Path -LiteralPath (Get-Sti "shared/backend.hcl") -PathType Leaf)) { Stopp "Fant ikke shared/backend.hcl." }
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { Stopp "Fant ikke az. Installer Azure CLI og kjør az login." }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Stopp "Fant ikke gh. Installer GitHub CLI og kjør gh auth login." }

$fraFil = Get-FilVerdi "config/felles.tfvars" "kortnavn"
if ($Kortnavn -eq "") {
    $Kortnavn = $fraFil
} elseif ($Kortnavn -cne $fraFil) {
    Stopp "Du oppga «$Kortnavn», men config/felles.tfvars sier «$fraFil». Bruk kortnavnet ressursene dine faktisk har."
}
if ($Kortnavn -cnotmatch '^[a-z0-9]{2,10}\z') { Stopp "Kortnavnet «$Kortnavn» er ikke gyldig. Er config/felles.tfvars endret?" }

gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Stopp "gh er ikke logget inn. Kjør gh auth login." }
$repo = ConvertTo-Tekst (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null)
if ($repo -eq "") { Stopp "gh finner ikke GitHub-repoet for denne mappa. Har repoet en remote på github.com?" }

$konto = Get-FilVerdi "shared/backend.hcl" "storage_account_name"
$container = Get-FilVerdi "shared/backend.hcl" "container_name"

Write-Host ""
Write-Host "Endringsordrer for oblig 2"
Write-Host "  Kortnavn: $Kortnavn"
Write-Host "  Repo:     $repo"
Write-Host "  State:    $konto/$container"

# ---------------------------------------------------------------------------
#  Er migreringen ferdig? De gamle state-filene skal være borte.
# ---------------------------------------------------------------------------
$blober = ConvertTo-Tekst (az storage blob list --account-name $konto --container-name $container `
        --prefix oblig2/ --auth-mode login --query "[].name" -o tsv 2>$null)
if ($LASTEXITCODE -ne 0) { Stopp "Fikk ikke lest state-kontoen. Er du logget inn med az login, i riktig abonnement?" }

$bloblinjer = @()
if ($blober -ne "") { $bloblinjer = $blober -split "`n" }
$gamle = ""
foreach ($miljo in @('dev', 'prod')) {
    foreach ($stack in @('network', 'data', 'app')) {
        if ($bloblinjer -ccontains "oblig2/$miljo/$stack.tfstate") {
            $gamle += " oblig2/$miljo/$stack.tfstate"
        }
    }
}
if ($gamle -ne "") {
    Stopp "Migreringen er ikke ferdig. Disse state-filene finnes fortsatt:$gamle`n  Endringsordrene skal løses i den nye strukturen. Fullfør K8 først."
}

# ---------------------------------------------------------------------------
#  Ordrene
# ---------------------------------------------------------------------------
Set-Verdier $Kortnavn

# Teksten står i '...'-blokker, så ` og " kan stå som de er. {PORT} osv.
# byttes ut under. Linjeskiftene gjøres om til LF, uansett hvordan fila er
# lagret.
function Format-Ordre {
    param([string]$Mal)
    $t = $Mal.Replace("`r`n", "`n")
    $t = $t.Replace('{PORT}', [string]$EoPort).Replace('{KILDE}', $EoKilde)
    $t = $t.Replace('{DEV}', $EoDev).Replace('{PROD}', $EoProd).Replace('{NAVN}', $EoNavn)
    return $t
}

$titler = @{}
$tekster = @{}

$titler[1] = "EO 1: ordre skal godta TCP $EoPort fra $EoKilde"
$tekster[1] = Format-Ordre @'
Tjenesten `ordre` skal godta innkommende TCP på port **{PORT}** fra **{KILDE}**, i både dev og prod.

Regelen gjelder bare `ordre`. Ingen andre tjenester skal få den.

**Ferdig når:** regelen finnes i NSG-en til `ordre` i dev og prod, og andre plan gir `No changes`.
'@

$titler[2] = "EO 2: Utvid adresserommet med $EoDev (dev) og $EoProd (prod)"
$tekster[2] = Format-Ordre @'
VNet-et skal få et nytt adresseområde i tillegg til det det har:

| Miljø | Nytt adresseområde |
|---|---|
| dev | **{DEV}** |
| prod | **{PROD}** |

Det eksisterende adresseområdet beholdes. Ingenting skal rives.

**Ferdig når:** VNet-et har begge adresseområdene i dev og prod, og andre plan gir `No changes`.
'@

$titler[3] = "EO 3: Ny tjeneste $EoNavn"
$tekster[3] = Format-Ordre @'
Ny tjeneste: **`{NAVN}`**, med kjøremiljø **web app**, i dev og prod.

| Miljø | Subnett |
|---|---|
| dev | **{DEV}** |
| prod | **{PROD}** |

Den skal ha det samme oppsettet som `meny`: subnett med NSG, storage account, Key Vault, App Service-plan og web app.

Avhenger av EO 2: subnettet ligger i det nye adresseområdet.

**Ferdig når:** tjenesten er rullet ut i dev og prod, og andre plan gir `No changes`. PR-en som innfører tjenesten, endrer bare filer under `config/` (K9).
'@

Write-Host ""
Write-Host "Oppretter Issues i ${repo}:"
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($i in 1, 2, 3) {
    $tittel = $titler[$i]
    $sok = '\"EO ' + $i + ':\" in:title'
    $jq = '.[] | select(.title | startswith(\"EO ' + $i + ':\")) | .title'
    $finnes = (ConvertTo-Tekst (gh issue list --repo $repo --state all --search $sok --json title -q $jq 2>$null)) -split "`n" |
        Select-Object -First 1
    if ($finnes -ne "") {
        Write-Host "  finnes fra før: $finnes"
        continue
    }
    # Teksten går via en fil (--body-file). Som argument kan Windows
    # PowerShell 5.1 ødelegge flerlinjet tekst med " og `.
    $fil = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllBytes($fil, $utf8.GetBytes($tekster[$i]))
    $url = ConvertTo-Tekst (gh issue create --repo $repo --title $tittel --body-file $fil 2>&1)
    $kode = $LASTEXITCODE
    Remove-Item -LiteralPath $fil -Force -ErrorAction SilentlyContinue
    if ($kode -eq 0) {
        Write-Host "  opprettet:      $tittel"
        Write-Host "                  $url"
    } else {
        Stopp "gh issue create feilet: $url"
    }
}

Write-Host ""
Write-Host "Lukk hver ordre med en PR (skriv «Closes #<nr>» i beskrivelsen), som går til dev og så til prod."
Write-Host ""
