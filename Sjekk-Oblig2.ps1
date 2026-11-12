<#
.SYNOPSIS
    Selvtest for obligatorisk øving 2.

.DESCRIPTION
    Kjør det fra rota av repoet ditt:

        .\Sjekk-Oblig2.ps1 -Foer     K2: øyeblikksbilde før migreringen
        .\Sjekk-Oblig2.ps1 -Etter    K6: øyeblikksbilde etter, og sammenligning
        .\Sjekk-Oblig2.ps1           alle kravene

    -Foer og -Etter skriver .oblig2/foer.txt og .oblig2/etter.txt. Ellers
    LESER skriptet bare. Det endrer ingenting i Azure eller på GitHub.

    Kortnavnet leses fra config/felles.tfvars, og state-kontoen fra
    shared/backend.hcl. Er du logget inn med az og gh, kjøres også kontrollene
    mot Azure og GitHub. Ellers blir de HOPPET.

    Ressursene må være rullet ut i dag (nattjobben sletter dem) for at
    -Foer, -Etter og K10 skal virke.

    Denne fila skal gi nøyaktig samme resultat som sjekk-oblig2.sh. Endrer du
    den ene, endrer du den andre. Utskriften nevner --foer og --etter, som i
    bash-utgaven. Her heter de -Foer og -Etter. Øyeblikksbildene har samme
    format, så du kan ta -Foer på én maskin og --etter på en annen.

    Virker i Windows PowerShell 5.1 (den som følger med Windows) og i
    PowerShell 7. Du trenger git i PATH, og az og gh for kontrollene mot Azure
    og GitHub.

    Får du «cannot be loaded because running scripts is disabled on this
    system», er det Windows' standardinnstilling som stopper deg - ikke noe
    galt med skriptet. Start det slik i stedet:

        powershell -ExecutionPolicy Bypass -File .\Sjekk-Oblig2.ps1

    Det gjelder bare den ene kjøringen, og endrer ingen innstilling.

    Merk: skriptet kan ta feil. Mener du et avvik er urimelig, skriv det i
    innleveringen og forklar hvorfor.

.PARAMETER Foer
    K2: tar øyeblikksbildet før migreringen (.oblig2/foer.txt).

.PARAMETER Etter
    K6: tar øyeblikksbildet etter migreringen (.oblig2/etter.txt), og
    sammenligner det med foer.txt.

.EXAMPLE
    .\Sjekk-Oblig2.ps1 -Foer

.EXAMPLE
    .\Sjekk-Oblig2.ps1
#>

[CmdletBinding()]
param(
    [switch]$Foer,
    [switch]$Etter
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Argumenter med " i (gh --search og jq-uttrykkene) skrives med \" og sendes
# slik Windows PowerShell 5.1 gjør det. PowerShell 7.3+ har en annen standard,
# så vi ber om den gamle, ellers blir argumentene ulike i 5.1 og 7.
$PSNativeCommandArgumentPassing = 'Legacy'

if ($Foer -and $Etter) {
    Write-Host "Bruk: .\Sjekk-Oblig2.ps1 [-Foer | -Etter]"
    exit 1
}
$Modus = "alle"
if ($Foer) { $Modus = "foer" }
if ($Etter) { $Modus = "etter" }

# ---------------------------------------------------------------------------
#  Utskrift
# ---------------------------------------------------------------------------

$script:AntallOk = 0
$script:AntallAvvik = 0
$script:AntallManuell = 0
$script:AntallHoppet = 0
$script:Avviksliste = @()

function Write-Ok {
    param([string]$Krav, [string]$Tekst)
    Write-Host "  OK       " -ForegroundColor Green -NoNewline
    Write-Host ("{0,-5} {1}" -f $Krav, $Tekst)
    $script:AntallOk++
}

function Write-Avvik {
    param([string]$Krav, [string]$Tekst, [string]$Hjelp)
    Write-Host "  AVVIK    " -ForegroundColor Red -NoNewline
    Write-Host ("{0,-5} {1}" -f $Krav, $Tekst)
    Write-Host ("           → {0}" -f $Hjelp) -ForegroundColor DarkGray
    $script:AntallAvvik++
    $script:Avviksliste += $Krav
}

function Write-Manuell {
    param([string]$Krav, [string]$Tekst, [string]$Hjelp)
    Write-Host "  MANUELL  " -ForegroundColor Yellow -NoNewline
    Write-Host ("{0,-5} {1}" -f $Krav, $Tekst)
    Write-Host ("           → {0}" -f $Hjelp) -ForegroundColor DarkGray
    $script:AntallManuell++
}

function Write-Hoppet {
    param([string]$Krav, [string]$Tekst, [string]$Hjelp)
    Write-Host "  HOPPET   " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-5} {1}" -f $Krav, $Tekst)
    Write-Host ("           → {0}" -f $Hjelp) -ForegroundColor DarkGray
    $script:AntallHoppet++
}

function Write-Bolk {
    param([string]$Tekst)
    Write-Host ""
    Write-Host $Tekst -ForegroundColor White
}

# Skriver til stderr (i rødt i konsollen) og avslutter, som stopp i bash.
function Stopp {
    param([string]$Tekst)
    $Host.UI.WriteErrorLine("`n  $Tekst`n")
    exit 1
}

# ---------------------------------------------------------------------------
#  Hjelpere
# ---------------------------------------------------------------------------

# Utdata fra et eksternt program som én tekst, slik $(...) gir den i bash:
# linjene skilt med LF, uten CR, uten tomme linjer på slutten.
function ConvertTo-Tekst {
    param($Ut)
    if ($null -eq $Ut) { return "" }
    $s = (@($Ut) | ForEach-Object { "$_" }) -join "`n"
    $s = $s.Replace("`r", "")
    return $s.TrimEnd("`n")
}

# Linjene i en tekst. Tom tekst gir ingen linjer.
function ConvertTo-Linjer {
    param([string]$Tekst)
    if ($Tekst -eq "") { return }
    $Tekst -split "`n"
}

# Heltall som i [[ "${X:-0}" -ge 1 ]]. Alt som ikke er et tall, blir 0.
function ConvertTo-Tall {
    param([string]$Tekst)
    $n = 0
    if ([int]::TryParse($Tekst.Trim(), [ref]$n)) { return $n }
    return 0
}

function Get-Sti {
    param([string]$Rel)
    return (Join-Path (Get-Location).Path $Rel)
}

function Test-Fil   { param([string]$Rel) return (Test-Path -LiteralPath (Get-Sti $Rel) -PathType Leaf) }
function Test-Mappe { param([string]$Rel) return (Test-Path -LiteralPath (Get-Sti $Rel) -PathType Container) }

# Innholdet i en fil, eller $null om den ikke finnes eller ikke kan leses.
function Read-Fil {
    param([string]$Rel)
    $sti = Get-Sti $Rel
    if (-not (Test-Path -LiteralPath $sti -PathType Leaf)) { return $null }
    try { return [System.IO.File]::ReadAllText($sti) } catch { return $null }
}

function Sorter-Ordinal {
    param([string[]]$Liste)
    if ($null -eq $Liste -or $Liste.Count -eq 0) { return }
    [string[]]$kopi = $Liste.Clone()
    [Array]::Sort($kopi, [System.StringComparer]::Ordinal)
    $kopi
}

# Etterligner `find <rot>`: rota først, så hvert element dybde først, i den
# rekkefølgen filsystemet gir dem (samme som find). Stiene skrives med /.
# HoppNavn: mapper med dette navnet gås ikke inn i, uansett hvor de ligger.
# HoppStier: disse stiene gås ikke inn i.
function Get-FindStier {
    param([string]$Rot, [string[]]$HoppNavn = @(), [string[]]$HoppStier = @())
    $abs = Get-Sti $Rot
    if (-not (Test-Path -LiteralPath $abs)) { return }
    $Rot
    if (Test-Path -LiteralPath $abs -PathType Container) {
        Get-FindUnder ([System.IO.DirectoryInfo]$abs) $Rot $HoppNavn $HoppStier
    }
}

function Get-FindUnder {
    param([System.IO.DirectoryInfo]$Mappe, [string]$Rel, [string[]]$HoppNavn, [string[]]$HoppStier)
    try { $elementer = @($Mappe.EnumerateFileSystemInfos()) } catch { return }
    foreach ($e in $elementer) {
        $sti = "$Rel/$($e.Name)"
        $sti
        $erLenke = ($e.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($e -is [System.IO.DirectoryInfo] -and -not $erLenke) {
            if ($HoppNavn -ccontains $e.Name) { continue }
            if ($HoppStier -ccontains $sti) { continue }
            Get-FindUnder $e $sti $HoppNavn $HoppStier
        }
    }
}

# [[:space:]] i grep, innenfor én linje.
$script:Mellomrom = '[ \t\v\f\r]'

function Get-FilVerdi {
    param([string]$Fil, [string]$Nokkel)
    $tekst = Read-Fil $Fil
    if ($null -eq $tekst) { return "" }
    $m = $script:Mellomrom
    $monster = '^' + $m + '*' + $Nokkel + $m + '*=' + $m + '*"([^"]*)"'
    foreach ($linje in ($tekst -split "`n")) {
        if ($linje -cmatch $monster) { return $Matches[1] }
    }
    return ""
}

# Verdiene i endringsordrene. Samme utregning som i endringsordrer.sh.
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

# Alle .tf-filer i arbeidstreet, uten .terraform/ og .git/.
function Get-TfFiler {
    @(Get-FindStier "." -HoppNavn @('.terraform') -HoppStier @('./.git') |
        Where-Object { $_.EndsWith(".tf", [System.StringComparison]::Ordinal) })
}

# Antall filer under $Sti med minst én linje som matcher $Monster
# (grep -rIlE --exclude-dir=.git --exclude-dir=.terraform | wc -l).
function Get-AntallTreff {
    param([string]$Monster, [string]$Sti)
    $n = 0
    foreach ($rel in @(Get-FindStier $Sti -HoppNavn @('.git', '.terraform'))) {
        $tekst = Read-Fil $rel
        if ($null -eq $tekst -or $tekst.Contains([string][char]0)) { continue }
        foreach ($linje in ($tekst -split "`n")) {
            if ($linje -cmatch $Monster) { $n++; break }
        }
    }
    return $n
}

# Eier state-fila (teksten) en ressurs av denne typen? Samme regel som
# managed_typer i bash: linja med "mode": "managed" og linja etter, og
# "type" på en av dem. Data-kilder (mode data) teller ikke.
function Test-EierType {
    param([string]$Tekst, [string]$Type)
    $linjer = $Tekst -split "`n"
    for ($i = 0; $i -lt $linjer.Count; $i++) {
        if (-not $linjer[$i].Contains('"mode": "managed"')) { continue }
        foreach ($j in @($i, ($i + 1))) {
            if ($j -ge $linjer.Count) { continue }
            if ($linjer[$j] -cmatch '.*"type": "([^"]*)"' -and $Matches[1] -ceq $Type) { return $true }
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
#  Felles oppsett
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Selvtest for obligatorisk øving 2" -ForegroundColor White
Write-Host ("Repo: {0}" -f (Get-Location).Path) -ForegroundColor DarkGray

if (-not (Test-Mappe ".git")) { Stopp "Dette ser ikke ut som rota av et git-repo. Kjør skriptet fra mappa der .git ligger." }
if (-not (Test-Fil "config/felles.tfvars")) { Stopp "Fant ikke config/felles.tfvars. Er dette repoet for oblig 2?" }

$Kortnavn = Get-FilVerdi "config/felles.tfvars" "kortnavn"
$Konto = Get-FilVerdi "shared/backend.hcl" "storage_account_name"
$Container = Get-FilVerdi "shared/backend.hcl" "container_name"
Write-Host ("Kortnavn: {0}   State: {1}/{2}" -f $Kortnavn, $Konto, $Container) -ForegroundColor DarkGray

if ($Kortnavn -cnotmatch '^[a-z0-9]{2,10}\z') { Stopp "Kortnavnet «$Kortnavn» i config/felles.tfvars er ikke gyldig." }

$script:AzOk = $false
$script:Sub = ""
if (Get-Command az -ErrorAction SilentlyContinue) {
    $script:Sub = ConvertTo-Tekst (az account show --query id -o tsv 2>$null)
    if ($LASTEXITCODE -eq 0 -and $script:Sub -ne "") { $script:AzOk = $true }
}
$GhOk = $false
$Repo = ""
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
        $Repo = ConvertTo-Tekst (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null)
        if ($Repo -ne "") { $GhOk = $true }
    }
}

Set-Verdier $Kortnavn

# ---------------------------------------------------------------------------
#  Øyeblikksbilder (-Foer og -Etter)
# ---------------------------------------------------------------------------
#  Én linje per ressurs: miljø, ressurs-ID, type og createdTime. Ressurs-ID-en
#  er den samme også etter en replace. createdTime er det ikke.
#  /subscriptions/<id> fjernes fra ID-en, siden fila committes i repoet.
#
#  Fila skal være byte for byte lik den bash-utgaven skriver: tab mellom
#  feltene, sortert byte for byte, LF og linjeskift til slutt, ingen BOM.

function Save-Bilde {
    param([string]$Fil)
    if (-not $script:AzOk) { Stopp "Du må være logget inn med az login for å ta et øyeblikksbilde." }
    [void](New-Item -ItemType Directory -Force -Path (Get-Sti ".oblig2"))
    $linjer = New-Object System.Collections.Generic.List[string]
    foreach ($miljo in @('dev', 'prod')) {
        $rg = "rg-$Kortnavn-oblig2-$miljo"
        if ((ConvertTo-Tekst (az group exists -n $rg 2>$null)) -cne "true") {
            Stopp "Ressursgruppa $rg finnes ikke. Rull ut $miljo i dag (CD dev / CD prod) før du tar øyeblikksbildet."
        }
        $url = "https://management.azure.com/subscriptions/$($script:Sub)/resourceGroups/$rg/resources?`$expand=createdTime&api-version=2021-04-01"
        # Anførselstegnene rundt URL-en er for az.cmd på Windows: uten dem
        # tolker cmd.exe & som et skille mellom to kommandoer.
        $ut = ConvertTo-Tekst (az rest --method get --url ('"' + $url + '"') --query "value[].[id, type, createdTime]" -o tsv 2>$null)
        if ($LASTEXITCODE -ne 0) {
            Stopp "Fikk ikke lest ressursene i $rg (az rest feilet). Prøv igjen, og sjekk az account show."
        }
        if ([string]::IsNullOrWhiteSpace($ut)) {
            Stopp "Fant ingen ressurser i $rg. Er $miljo rullet ut i dag?"
        }
        foreach ($l in @(ConvertTo-Linjer $ut)) {
            $f = $l.Split("`t")
            if ($f.Count -lt 3) { continue }
            $id = $f[0].ToLowerInvariant() -creplace '^/subscriptions/[^/]+', ''
            $linjer.Add("$miljo`t$id`t$($f[1])`t$($f[2])")
        }
    }
    $sortert = @(Sorter-Ordinal $linjer.ToArray())
    $tekst = ""
    if ($sortert.Count -gt 0) { $tekst = ($sortert -join "`n") + "`n" }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllBytes((Get-Sti $Fil), $utf8.GetBytes($tekst))
    Write-Host ""
    Write-Host ("  Lagret {0}: {1} ressurser (dev og prod)" -f $Fil, $sortert.Count)
}

# Linjene i et øyeblikksbilde. CR fjernes, i tilfelle git har gjort om
# linjeskiftene ved checkout på Windows.
function Read-Bilde {
    param([string]$Rel)
    $tekst = Read-Fil $Rel
    if ($null -eq $tekst -or $tekst -eq "") { return }
    $tekst = $tekst.Replace("`r", "")
    if ($tekst.EndsWith("`n")) { $tekst = $tekst.Substring(0, $tekst.Length - 1) }
    $tekst -split "`n"
}

# cut -f1,2,4
function Get-Felt124 {
    param([string]$Linje)
    if (-not $Linje.Contains("`t")) { return $Linje }
    $f = $Linje.Split("`t")
    $v = @($f[0], $f[1])
    if ($f.Count -ge 4) { $v += $f[3] }
    return ($v -join "`t")
}

# cut -f2
function Get-Felt2 {
    param([string]$Linje)
    if (-not $Linje.Contains("`t")) { return $Linje }
    return $Linje.Split("`t")[1]
}

# Sammenligner foer og etter. Skriver OK eller AVVIK for K6.
function Compare-Bilder {
    if (-not (Test-Fil ".oblig2/foer.txt")) {
        Write-Avvik "K6" "Ingenting ble revet" "Fant ikke .oblig2/foer.txt. Den lages med --foer (K2)"
        return
    }
    if (-not (Test-Fil ".oblig2/etter.txt")) {
        Write-Avvik "K6" "Ingenting ble revet" "Fant ikke .oblig2/etter.txt. Kjør --etter samme dag som migreringen"
        return
    }
    $foer = @(Read-Bilde ".oblig2/foer.txt")
    $etter = @(Read-Bilde ".oblig2/etter.txt")

    # comm -23: linjene (felt 1, 2 og 4) i foer som ikke finnes i etter.
    $igjen = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([System.StringComparer]::Ordinal)
    foreach ($l in $etter) {
        $k = Get-Felt124 $l
        if ($igjen.ContainsKey($k)) { $igjen[$k]++ } else { $igjen[$k] = 1 }
    }
    $mangler = @()
    foreach ($k in @(Sorter-Ordinal @($foer | ForEach-Object { Get-Felt124 $_ }))) {
        if ($igjen.ContainsKey($k) -and $igjen[$k] -gt 0) { $igjen[$k]-- } else { $mangler += $k }
    }
    if ($mangler.Count -eq 0) {
        $antall = ([regex]::Matches((Read-Fil ".oblig2/foer.txt"), "`n")).Count
        Write-Ok "K6" "Alle $antall ressursene har samme ID og createdTime før og etter"
        return
    }
    $etterIder = @($etter | ForEach-Object { Get-Felt2 $_ })
    $endret = ""; $borte = ""
    foreach ($linje in $mangler) {
        $felt = @($linje.Split("`t") | Where-Object { $_ -ne "" })
        $id = ""
        if ($felt.Count -ge 2) { $id = $felt[1] }
        $kort = $id.Substring($id.LastIndexOf('/') + 1)
        if ($etterIder -ccontains $id) { $endret += " $kort" } else { $borte += " $kort" }
    }
    if ($endret -ne "") {
        Write-Avvik "K6" "Ingenting ble revet" `
            "Ny createdTime, altså bygget på nytt:$endret. Ble foer.txt tatt en annen dag enn etter.txt?"
    }
    if ($borte -ne "") { Write-Avvik "K6" "Ingenting ble revet" "Finnes ikke lenger:$borte" }
}

if ($Modus -eq "foer") {
    Write-Bolk "K2 · Øyeblikksbilde før migreringen"
    if (Test-Fil ".oblig2/foer.txt") { Write-Host "  Erstatter forrige .oblig2/foer.txt" -ForegroundColor Yellow }
    Save-Bilde ".oblig2/foer.txt"
    Write-Host ""
    Write-Host "  Commit den nå, FØR første migrerings-commit:"
    Write-Host ""
    Write-Host "      git add .oblig2/foer.txt"
    Write-Host '      git commit -m "K2: øyeblikksbilde før migreringen"'
    Write-Host ""
    Write-Host "  Migreringen må bli ferdig i dag. Nattjobben sletter ressursene." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

if ($Modus -eq "etter") {
    Write-Bolk "K6 · Øyeblikksbilde etter migreringen"
    Save-Bilde ".oblig2/etter.txt"
    Write-Host ""
    Compare-Bilder
    Write-Host ""
    Write-Host "  Commit den:"
    Write-Host ""
    Write-Host "      git add .oblig2/etter.txt"
    Write-Host '      git commit -m "K6: øyeblikksbilde etter migreringen"'
    Write-Host ""
    if ($script:AntallAvvik -eq 0) { exit 0 } else { exit 1 }
}

# ===========================================================================
#  A · UTGANGSPUNKT
# ===========================================================================

Write-Bolk "A · Utgangspunkt"

# --- K1: rullet ut av workflowen, i dev og prod ----------------------------
if ($GhOk) {
    $devOk = ConvertTo-Tall (ConvertTo-Tekst (gh run list --workflow cd-dev.yml --status success --limit 1 --json databaseId -q 'length' 2>$null))
    $prodOk = ConvertTo-Tall (ConvertTo-Tekst (gh run list --workflow cd-prod.yml --status success --limit 1 --json databaseId -q 'length' 2>$null))
    if ($devOk -ge 1 -and $prodOk -ge 1) {
        Write-Ok "K1" "Vellykkede kjøringer av CD dev og CD prod finnes"
    } else {
        Write-Avvik "K1" "Rullet ut i dev og prod av workflowen" `
            "Fant ikke en vellykket kjøring av både cd-dev.yml og cd-prod.yml i $Repo"
    }
} else {
    Write-Hoppet "K1" "Rullet ut i dev og prod av workflowen" "Logg inn med gh auth login for å sjekke kjøringene"
}
$m = $script:Mellomrom
if ((Get-AntallTreff "id-token:$m*write" ".github/workflows") -gt 0 -and
    (Get-AntallTreff ("creds:$m*" + '\$\{\{') ".github/workflows") -eq 0) {
    Write-Ok "K1" "Workflowene logger inn med OIDC (id-token: write, ingen creds:)"
} else {
    Write-Avvik "K1" "Workflowene logger inn med OIDC" "Fant ikke id-token: write, eller fant creds: med en secret"
}

# --- K2: foer.txt committet før første migrerings-commit -------------------
$FoerCommit = ConvertTo-Tekst (git log -1 --format=%H -- .oblig2/foer.txt 2>$null)
if ($FoerCommit -eq "") {
    Write-Avvik "K2" "Øyeblikksbilde committet før migreringen" `
        "Fant ingen commit av .oblig2/foer.txt. Kjør --foer, og commit fila før du flytter noe"
} else {
    $etterFoer = @(ConvertTo-Linjer (ConvertTo-Tekst (git log --format=%H -S 'destroy = false' "$($FoerCommit)..HEAD" -- '*.tf' 2>$null)))
    $foerKort = $FoerCommit.Substring(0, [Math]::Min(7, $FoerCommit.Length))
    if ($etterFoer.Count -gt 0 -and $etterFoer[0] -ne "") {
        Write-Ok "K2" "foer.txt ($foerKort) er committet før migrerings-commitene"
    } else {
        Write-Avvik "K2" "Øyeblikksbilde committet før migreringen" `
            "Fant ingen commit med 'destroy = false' etter $foerKort. Ble foer.txt committet etter at flyttingen startet?"
    }
}

# ===========================================================================
#  B · MIGRERINGEN
# ===========================================================================

Write-Bolk "B · Migreringen"

# --- K3: shared-network og én service, ingen tjenestenavn under stacks/ ----
$stackmapper = ""
if (Test-Mappe "stacks") {
    $navn = @(([System.IO.DirectoryInfo](Get-Sti "stacks")).EnumerateDirectories() |
        Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0 } |
        ForEach-Object { $_.Name })
    foreach ($n in @(Sorter-Ordinal $navn)) { $stackmapper += "$n " }
}
if ((Test-Mappe "stacks/shared-network") -and (Test-Mappe "stacks/service")) {
    Write-Ok "K3" "stacks/shared-network og stacks/service finnes"
} else {
    $vis = $stackmapper; if ($vis -eq "") { $vis = "ingen" }
    Write-Avvik "K3" "stacks/shared-network og stacks/service" "Fant disse mappene under stacks/: $vis"
}
$tjenestestier = ""
foreach ($s in @(Get-FindStier "stacks" | Where-Object { $_ -imatch 'ordre|meny|sok|betal' } | Select-Object -First 3)) {
    $tjenestestier += "$s "
}
if ($tjenestestier -eq "") {
    Write-Ok "K3" "Ingen tjenestenavn i fil- eller mappenavn under stacks/"
} else {
    Write-Avvik "K3" "Ingen tjenestenavn under stacks/" `
        "Fant: $tjenestestier. Tjenesten er en parameter (config/<miljø>/service-<navn>.tfvars), ikke en mappe"
}

# --- K4: removed og import som kode ----------------------------------------
$nRemoved = @(ConvertTo-Linjer (ConvertTo-Tekst (git log --format=%H -S 'destroy = false' -- '*.tf' 2>$null))).Count
$nImport = @(ConvertTo-Linjer (ConvertTo-Tekst (git log --format=%H -S 'import {' -- '*.tf' 2>$null))).Count
if ($nRemoved -gt 0 -and $nImport -gt 0) {
    Write-Ok "K4" "Historikken har removed med destroy = false ($nRemoved commits) og import ($nImport commits)"
} else {
    Write-Avvik "K4" "Flyttingen skrevet som kode" `
        "git log -S fant 'destroy = false' i $nRemoved og 'import {' i $nImport commits. Begge skal finnes"
}

# --- K5: ingen /subscriptions/ i koden, heller ikke i historikken ----------
$TfFiler = Get-TfFiler
$naa = ""
foreach ($f in $TfFiler) {
    $tekst = Read-Fil $f
    if ($null -ne $tekst -and $tekst.Contains('/subscriptions/')) { $naa += "$f " }
}
$historie = ""
foreach ($c in @(ConvertTo-Linjer (ConvertTo-Tekst (git log --format=%h -G '/subscriptions/' -- '*.tf' '*.tfvars' 2>$null)) | Select-Object -First 3)) {
    $historie += "$c "
}
if ($naa -ne "") {
    Write-Avvik "K5" "Ingen /subscriptions/ i koden" "Fant det i: $naa"
} elseif ($historie -ne "") {
    Write-Avvik "K5" "Ingen /subscriptions/ i koden" `
        "Fant det i historikken (commits $historie). Import-ID-ene skal bygges, ikke skrives av"
} else {
    Write-Ok "K5" "Ingen /subscriptions/ i .tf- eller .tfvars-filer, heller ikke i historikken"
}

# --- K6: samme ressurser før og etter --------------------------------------
Compare-Bilder
Write-Manuell "K6" "Ingen migreringskjøring hadde to destroy > 0" `
    "Subnett, NSG-regler og NSG-koblinger er ikke med i øyeblikksbildet. Planene på migrerings-PR-ene viser dem"

# --- K7: samme commit til dev og prod --------------------------------------
if ($GhOk -and $FoerCommit -ne "") {
    $migCommits = @((ConvertTo-Tekst (git log --first-parent --format=%H "$($FoerCommit)..HEAD" -- stacks modules config 2>$null)) -split '\s+' |
        Where-Object { $_ -ne "" })
    if ($migCommits.Count -eq 0) {
        Write-Avvik "K7" "Samme commit til dev og prod" "Fant ingen commits på main som endrer stacks/, modules/ eller config/ etter foer.txt"
    } else {
        $titler = @(ConvertTo-Linjer (ConvertTo-Tekst (gh run list --status success --limit 300 --json displayTitle -q '.[].displayTitle' 2>$null)))
        # awk: felt 1 er miljøet, felt 3 er starten på SHA-en (minst 7 tegn).
        $felter = @(foreach ($t in $titler) { , @($t.Trim(" `t") -split '[ \t]+') })
        $mangler = ""
        foreach ($c in $migCommits) {
            $dev = $false; $prod = $false
            foreach ($f in $felter) {
                if ($f.Count -lt 3 -or $f[2].Length -lt 7 -or -not $c.StartsWith($f[2], [System.StringComparison]::Ordinal)) { continue }
                if ($f[0] -ceq "dev") { $dev = $true }
                if ($f[0] -ceq "prod") { $prod = $true }
            }
            if (-not ($dev -and $prod)) { $mangler += " $($c.Substring(0, [Math]::Min(7, $c.Length)))" }
        }
        if ($mangler -eq "") {
            Write-Ok "K7" "Alle $($migCommits.Count) commitene på main etter foer.txt er rullet ut i både dev og prod"
        } else {
            Write-Avvik "K7" "Samme commit til dev og prod" `
                "Fant ikke en vellykket CD dev- og CD prod-kjøring for:$mangler (CD prod tar hele SHA-en)"
        }
    }
} elseif (-not $GhOk) {
    Write-Hoppet "K7" "Samme commit til dev og prod" "Logg inn med gh auth login for å sjekke kjøringene"
} else {
    Write-Hoppet "K7" "Samme commit til dev og prod" "Krever at .oblig2/foer.txt er committet (K2)"
}

# --- K8: ryddet etterpå -----------------------------------------------------
$blokker = ""
$blokkMonster = "(?m)^$m*(removed|import)$m*\{"
foreach ($f in $TfFiler) {
    $tekst = Read-Fil $f
    if ($null -ne $tekst -and $tekst -cmatch $blokkMonster) { $blokker += "$f " }
}
if ($blokker -eq "") {
    Write-Ok "K8" "Ingen removed- eller import-blokker igjen"
} else {
    Write-Avvik "K8" "Ingen removed- eller import-blokker igjen" "Fant dem i: $blokker"
}
$gamleMapper = ""
foreach ($s in @('network', 'data', 'app')) { if (Test-Mappe "stacks/$s") { $gamleMapper += " stacks/$s" } }
$gamleFiler = ""
$kandidater = @(foreach ($mi in @('dev', 'prod')) { foreach ($s in @('network', 'data', 'app')) { "config/$mi/$s.tfvars" } })
foreach ($f in @(Sorter-Ordinal @($kandidater | Where-Object { Test-Path -LiteralPath (Get-Sti $_) }))) { $gamleFiler += "$f " }
if (($gamleMapper + $gamleFiler) -eq "") {
    Write-Ok "K8" "network, data og app er borte fra stacks/ og config/"
} else {
    Write-Avvik "K8" "De gamle stackene er borte fra repoet" "Fant fortsatt:$gamleMapper $gamleFiler"
}

$Blober = ""
if ($script:AzOk) {
    $Blober = ConvertTo-Tekst (az storage blob list --account-name $Konto --container-name $Container --prefix oblig2/ `
            --auth-mode login --query "[].name" -o tsv 2>$null)
    if ($Blober -eq "") {
        Write-Hoppet "K8" "De gamle state-filene er slettet" "Fikk ikke lest $Konto/$Container, eller den er tom under oblig2/"
    } else {
        $bloblinjer = @(ConvertTo-Linjer $Blober)
        $gamleBlober = ""
        foreach ($mi in @('dev', 'prod')) {
            foreach ($s in @('network', 'data', 'app')) {
                if ($bloblinjer -ccontains "oblig2/$mi/$s.tfstate") { $gamleBlober += " oblig2/$mi/$s.tfstate" }
            }
        }
        if ($gamleBlober -eq "") {
            Write-Ok "K8" "De gamle state-filene er slettet fra state-kontoen"
        } else {
            Write-Avvik "K8" "De gamle state-filene er slettet" "Finnes fortsatt:$gamleBlober"
        }
    }
} else {
    Write-Hoppet "K8" "De gamle state-filene er slettet" "Logg inn med az login for å sjekke state-kontoen"
}
Write-Manuell "K8" "Alle stackene gir No changes i begge miljøene" `
    "CI-planen på siste PR skal vise ✅ No changes for hver stack, både mot dev og prod"

# ===========================================================================
#  C · NY TJENESTE OG ENDRINGSORDRER
# ===========================================================================

Write-Bolk "C · Ny tjeneste og endringsordrer"
Write-Host ("  Dine verdier: port {0} fra {1} · nytt område {2} / {3} · ny tjeneste {4}" -f `
        $EoPort, $EoKilde, $EoDev, $EoProd, $EoNavn) -ForegroundColor DarkGray

# --- K9: tjeneste C kom inn med en PR som bare endret config/ -------------
$cFil = "config/dev/service-$EoNavn.tfvars"
# --name-only i stedet for patch: --diff-merges slår ellers på -p.
$cCommit = ""
foreach ($l in @(ConvertTo-Linjer (ConvertTo-Tekst (git log --first-parent --diff-merges=first-parent --diff-filter=A --name-only '--format=C %H' -- $cFil 2>$null)))) {
    if ($l.StartsWith("C ", [System.StringComparison]::Ordinal)) { $cCommit = $l.Substring(2) }
}
if ($cCommit -eq "") {
    Write-Avvik "K9" "Tjeneste $EoNavn er en ny instans av service" `
        "Fant ingen commit på main som legger til $cFil"
} else {
    $cKort = $cCommit.Substring(0, [Math]::Min(7, $cCommit.Length))
    $endret = ConvertTo-Tekst (git diff --name-only "$($cCommit)^1" $cCommit 2>$null)
    $utenfor = ""
    foreach ($l in @(ConvertTo-Linjer $endret)) {
        if ($l -ne "" -and -not $l.StartsWith("config/", [System.StringComparison]::Ordinal)) { $utenfor += "$l " }
    }
    if ($endret -eq "") {
        Write-Avvik "K9" "PR-en for tjeneste $EoNavn endrer bare config/" "Fikk ikke lest endringene i $cKort"
    } elseif ($utenfor -eq "") {
        Write-Ok "K9" "Commiten som innførte $EoNavn ($cKort) endret bare filer under config/"
    } else {
        Write-Avvik "K9" "PR-en for tjeneste $EoNavn endrer bare config/" `
            "$cKort endret også: $utenfor"
    }
}

# --- K10: endringsordrene er lukket, og ressursene stemmer -----------------
if ($GhOk) {
    foreach ($i in 1, 2, 3) {
        $sok = '\"EO ' + $i + ':\" in:title'
        $jq = '.[] | select(.title | startswith(\"EO ' + $i + ':\")) | .state'
        $status = @(ConvertTo-Linjer (ConvertTo-Tekst (gh issue list --state all --search $sok --json 'title,state' -q $jq 2>$null))) |
            Select-Object -First 1
        if ($status -ceq "CLOSED") {
            Write-Ok "K10" "EO $i er lukket"
        } elseif ($status -ceq "OPEN") {
            Write-Avvik "K10" "EO $i er lukket" "Issuet er fortsatt åpent. Lukk det med en PR (Closes #<nr>)"
        } else {
            Write-Avvik "K10" "EO $i finnes" "Fant ikke Issuet. Kjør endringsordrer.sh når migreringen er ferdig"
        }
    }
} else {
    Write-Hoppet "K10" "Endringsordrene er lukket" "Logg inn med gh auth login"
}

# State-filene for et miljø, i samme rekkefølge som globben i bash.
function Get-StateFiler {
    param([string]$Mappe, [string]$Miljo)
    $navn = @(Get-ChildItem -LiteralPath $Mappe -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -clike "oblig2_$($Miljo)_*.tfstate" } | ForEach-Object { $_.Name })
    foreach ($n in @(Sorter-Ordinal $navn)) {
        [pscustomobject]@{
            Sti    = (Join-Path $Mappe $n)
            Nokkel = $n.Substring(0, $n.Length - ".tfstate".Length).Substring("oblig2_$($Miljo)_".Length)
        }
    }
}

if (-not $script:AzOk) {
    Write-Hoppet "K10" "Ressursene finnes med riktige verdier" "Logg inn med az login"
} else {
    $statemappe = Join-Path ([System.IO.Path]::GetTempPath()) ("oblig2-" + [guid]::NewGuid().ToString("N"))
    [void](New-Item -ItemType Directory -Force -Path $statemappe)
    foreach ($b in @($Blober -split '\s+' | Where-Object { $_ -ne "" })) {
        az storage blob download --account-name $Konto --container-name $Container --name $b `
            --file (Join-Path $statemappe $b.Replace('/', '_')) --auth-mode login -o none 2>$null | Out-Null
    }

    foreach ($miljo in @('dev', 'prod')) {
        $rg = "rg-$Kortnavn-oblig2-$miljo"
        if ($miljo -eq "dev") { $omraade = $EoDev } else { $omraade = $EoProd }
        if ((ConvertTo-Tekst (az group exists -n $rg 2>$null)) -cne "true") {
            Write-Hoppet "K10" "Ressursene i $miljo" "$rg finnes ikke. Rull ut $miljo i dag først"
            continue
        }
        $stater = @(Get-StateFiler $statemappe $miljo | ForEach-Object {
                $_ | Add-Member -NotePropertyName Tekst -NotePropertyValue ([System.IO.File]::ReadAllText($_.Sti)) -PassThru
            })

        # EO 1: NSG-regelen på ordre, og i ordre sin state
        $q = ('[?access==''Allow'' && direction==''Inbound'' && (destinationPortRange==''{0}'' || contains(destinationPortRanges || `[]`, ''{0}'')) && (sourceAddressPrefix==''{1}'' || contains(sourceAddressPrefixes || `[]`, ''{1}''))] | length(@)' -f $EoPort, $EoKilde)
        $regel = ConvertTo-Tall (ConvertTo-Tekst (az network nsg rule list -g $rg --nsg-name nsg-ordre --query $q -o tsv 2>$null))
        if ($regel -ge 1) {
            $nokkel = ""
            foreach ($s in $stater) {
                if ((Test-EierType $s.Tekst "azurerm_network_security_rule") -and $s.Tekst.Contains("`"$EoPort`"") -and $s.Tekst.Contains('"vm-ordre"')) {
                    $nokkel = $s.Nokkel
                }
            }
            if ($nokkel -ne "") {
                Write-Ok "K10" "EO 1 ($miljo): regelen finnes, og eies av samme state som ordre ($nokkel)"
            } else {
                Write-Avvik "K10" "EO 1 ($miljo): regelen i riktig state" `
                    "Regelen finnes i Azure, men ikke i state-fila som eier vm-ordre"
            }
        } else {
            Write-Avvik "K10" "EO 1 ($miljo): TCP $EoPort fra $EoKilde på nsg-ordre" "Fant ingen slik Allow/Inbound-regel"
        }

        # EO 2: adresserommet, i shared-network sin state
        $rom = ConvertTo-Tekst (az network vnet show -g $rg -n "vnet-$Kortnavn-$miljo" --query "addressSpace.addressPrefixes" -o tsv 2>$null)
        if (@(ConvertTo-Linjer $rom) -ccontains $omraade) {
            $sn = Join-Path $statemappe "oblig2_$($miljo)_shared-network.tfstate"
            $snTekst = $null
            if (Test-Path -LiteralPath $sn -PathType Leaf) { $snTekst = [System.IO.File]::ReadAllText($sn) }
            if ($null -ne $snTekst -and (Test-EierType $snTekst "azurerm_virtual_network") -and $snTekst.Contains("`"$omraade`"")) {
                Write-Ok "K10" "EO 2 ($miljo): $omraade er i adresserommet, og eies av shared-network"
            } else {
                Write-Avvik "K10" "EO 2 ($miljo): adresserommet i riktig state" `
                    "$omraade finnes i Azure, men ikke i VNet-et i oblig2/$miljo/shared-network.tfstate"
            }
        } else {
            $romVis = @($rom -split '\s+' | Where-Object { $_ -ne "" }) -join " "
            Write-Avvik "K10" "EO 2 ($miljo): $omraade i adresserommet" "VNet-et har: $romVis"
        }

        # EO 3: ny tjeneste, i sin egen state
        $app = "app-$Kortnavn-$EoNavn-$miljo"
        $appState = ConvertTo-Tekst (az webapp show -g $rg -n $app --query state -o tsv 2>$null)
        $snett = ConvertTo-Tekst (az network vnet subnet show -g $rg --vnet-name "vnet-$Kortnavn-$miljo" -n "snet-$EoNavn" `
                --query "addressPrefix || addressPrefixes[0]" -o tsv 2>$null)
        if ($appState -ne "" -and $snett -ceq $omraade) {
            $nokkel = ""
            foreach ($s in $stater) {
                if ((Test-EierType $s.Tekst "azurerm_linux_web_app") -and $s.Tekst.Contains("`"$app`"")) {
                    $nokkel = $s.Nokkel
                    if ($s.Tekst.Contains('"vm-ordre"') -or $s.Tekst.Contains("`"app-$Kortnavn-meny-$miljo`"")) { $nokkel = "DELT:$nokkel" }
                }
            }
            if ($nokkel -eq "") {
                Write-Avvik "K10" "EO 3 ($miljo): $EoNavn i egen state" "Web app-en finnes i Azure, men ikke i noen state-fil"
            } elseif ($nokkel.StartsWith("DELT:")) {
                Write-Avvik "K10" "EO 3 ($miljo): $EoNavn i egen state" "$($nokkel.Substring(5)) eier også ordre eller meny. Hver tjeneste skal ha sin egen instans"
            } else {
                Write-Ok "K10" "EO 3 ($miljo): $app kjører med subnett $snett, i egen state ($nokkel)"
            }
        } else {
            $appVis = $appState; if ($appVis -eq "") { $appVis = "nei" }
            $snettVis = $snett; if ($snettVis -eq "") { $snettVis = "ingenting" }
            Write-Avvik "K10" "EO 3 ($miljo): $app med subnett $omraade" `
                "Fant web app: $appVis. Fant snet-$EoNavn med: $snettVis"
        }
    }
    Remove-Item -LiteralPath $statemappe -Recurse -Force -ErrorAction SilentlyContinue
}

# ===========================================================================
#  D · KVALITET
# ===========================================================================

Write-Bolk "D · Kvalitet"

# --- K11: porten og beskyttet main -----------------------------------------
if ((Test-Fil ".tflint.hcl") -and (Test-Fil ".checkov.yaml") -and (Get-AntallTreff 'valider\.sh' ".github/workflows") -gt 0) {
    Write-Ok "K11" "Porten (valider.sh med TFLint og Checkov) kjører i en workflow"
} else {
    Write-Avvik "K11" "Porten kjører på PR" "Fant ikke .tflint.hcl og .checkov.yaml, eller ingen workflow som kjører valider.sh"
}
$checkov = Read-Fil ".checkov.yaml"
if ($null -ne $checkov -and @($checkov -split "`n" | Where-Object { $_.Contains('skip-check') }).Count -gt 0) {
    Write-Manuell "K11" "Checkov-skip i .checkov.yaml" "Skip som gjelder hele repoet, må begrunnes i innleveringen"
}
if ($GhOk) {
    $krav1 = ConvertTo-Tekst (gh api "repos/$Repo/branches/main/protection" -q '.required_status_checks.contexts[]?, .required_status_checks.checks[]?.context' 2>$null)
    $krav2 = ConvertTo-Tekst (gh api "repos/$Repo/rules/branches/main" -q '.[] | select(.type==\"required_status_checks\") | .parameters.required_status_checks[].context' 2>$null)
    $krav = @(ConvertTo-Linjer $krav1) + @(ConvertTo-Linjer $krav2)
    $mangler = ""
    foreach ($k in @("kodekontroll", "plan mot dev", "plan mot prod")) {
        if (-not ($krav -ccontains $k)) { $mangler += " «$k»" }
    }
    if ($mangler -eq "") {
        Write-Ok "K11" "main krever kodekontroll, plan mot dev og plan mot prod"
    } else {
        Write-Avvik "K11" "main er beskyttet med required status checks" "Mangler:$mangler"
    }
} else {
    Write-Hoppet "K11" "main er beskyttet" "Logg inn med gh auth login"
}

# --- K12: konfigurasjon i config/, ingen hemmeligheter ---------------------
$utenfor = ""
foreach ($l in @(ConvertTo-Linjer (ConvertTo-Tekst (git ls-files '*.tfvars')))) {
    if (-not $l.StartsWith("config/", [System.StringComparison]::Ordinal)) { $utenfor += "$l " }
}
if ($utenfor -eq "") {
    Write-Ok "K12" "Alle .tfvars-filene ligger under config/"
} else {
    Write-Avvik "K12" "Konfigurasjonen ligger i config/" "Fant .tfvars utenfor config/: $utenfor"
}
$hemmelig = 'BEGIN [A-Z ]*PRIVATE KEY|AccountKey=|client_secret' + $m + '*=' + $m + '*"[^"]+"|ARM_CLIENT_SECRET' + $m + '*[:=]' + $m + '*[^ \t\v\f\r$]|password' + $m + '*=' + $m + '*"[^"]+"|[?&]sig=[A-Za-z0-9%]{20,}|[0-9A-Za-z_~.-]{3}[0-9]Q~[0-9A-Za-z_~.-]{31,34}'
$historikk = @(git log --all -p 2>$null)
$funn = @(@($historikk -cmatch '^\+') -cmatch $hemmelig).Count
if ($funn -eq 0) {
    Write-Ok "K12" "Fant ingen kjente hemmelighetsmønstre i historikken"
} else {
    Write-Avvik "K12" "Ingen hemmeligheter i repoet" `
        "Fant $funn linje(r) som ligner en privat nøkkel, kontonøkkel, client secret eller passord. Søk: git log --all -p | grep -E 'PRIVATE KEY|AccountKey|secret|password'"
}

# ===========================================================================
#  Oppsummering
# ===========================================================================

Write-Host ""
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  OK: $($script:AntallOk)" -ForegroundColor Green -NoNewline
Write-Host "   Avvik: $($script:AntallAvvik)" -ForegroundColor Red -NoNewline
Write-Host "   Manuell: $($script:AntallManuell)" -ForegroundColor Yellow -NoNewline
Write-Host "   Hoppet over: $($script:AntallHoppet)" -ForegroundColor DarkGray

if ($script:AntallAvvik -gt 0) {
    $unike = @($script:Avviksliste | Sort-Object -Unique | Sort-Object { [int]$_.Substring(1) }) -join " "
    Write-Host ""
    Write-Host "  Avvik på: $unike"
    Write-Host "  Rett dem, og kjør skriptet på nytt." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}
if ($script:AntallHoppet -gt 0) {
    Write-Host ""
    Write-Host "  Ingen avvik, men noen kontroller ble hoppet over." -ForegroundColor Yellow
    Write-Host "  Logg inn med az login og gh auth login, og rull ut begge miljøene i dag, før du leverer." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}
Write-Host ""
Write-Host "  Ingen avvik. Husk de manuelle punktene i innleveringen." -ForegroundColor Green
Write-Host ""
exit 0
