# =============================================================================
#  Reset.ps1  –  tilbake til utgangspunktet (samme som reset.sh)
# -----------------------------------------------------------------------------
#  Bruk (fra rota av repoet, med `az login` gjort):
#
#      powershell -ExecutionPolicy Bypass -File .\Reset.ps1
#
#  Gjør tre ting, i denne rekkefølgen:
#
#    1. Sletter ressursgruppene dine i dev og prod med `az group delete`.
#       Ikke `terraform destroy`: en ressurs som ingen state eier akkurat nå,
#       finner ikke destroy. az group delete tar alt.
#    2. Sletter state-filene dine under oblig2/ i state-kontoen.
#    3. Lager en ny gren med én commit som henter koden fra første commit i
#       repoet tilbake. config/felles.tfvars og shared/backend.hcl beholdes.
#
#  Deretter pusher du grenen, lager en PR og merger den. Da ruller CD dev ut
#  utgangspunktet på nytt, og du promoterer til prod som vanlig.
#
#  Historikken beholdes. Ingenting force-pushes.
# =============================================================================

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Hent-Verdi([string]$Fil, [string]$Navn) {
    foreach ($linje in Get-Content $Fil) {
        if ($linje -match "^\s*$Navn\s*=\s*`"([^`"]*)`"") { return $Matches[1] }
    }
    return ''
}

# Native kommandoer stopper ikke skriptet av seg selv når de feiler.
function Sjekk([string]$Hva) {
    if ($LASTEXITCODE -ne 0) { throw "$Hva feilet (exit-kode $LASTEXITCODE)." }
}

$Kortnavn  = Hent-Verdi 'config/felles.tfvars' 'kortnavn'
$StateRg   = Hent-Verdi 'shared/backend.hcl' 'resource_group_name'
$Konto     = Hent-Verdi 'shared/backend.hcl' 'storage_account_name'
$Container = Hent-Verdi 'shared/backend.hcl' 'container_name'

git diff --quiet
$uendret = ($LASTEXITCODE -eq 0)
git diff --cached --quiet
if (-not $uendret -or $LASTEXITCODE -ne 0) {
    Write-Host 'Du har endringer som ikke er committet. Commit eller forkast dem først.'
    exit 1
}

$Forste = (git rev-list --max-parents=0 HEAD | Select-Object -Last 1)
$Gren   = 'reset-' + (Get-Date -Format 'yyyyMMdd-HHmm')
$ForsteTekst = (git log -1 --format='%h %s' $Forste)
$Abonnement  = (az account show --query name -o tsv)

Write-Host ''
Write-Host 'Dette skjer nå:'
Write-Host ''
Write-Host "  1. az group delete:  rg-$Kortnavn-oblig2-dev og rg-$Kortnavn-oblig2-prod"
Write-Host "  2. Sletter blobene:  $Container/oblig2/* i $Konto (ressursgruppe $StateRg)"
Write-Host "  3. Ny gren:          $Gren, med koden fra $ForsteTekst"
Write-Host ''
Write-Host "Abonnement: $Abonnement"
Write-Host ''
$svar = Read-Host 'Skriv kortnavnet ditt for å bekrefte'
if ($svar -cne $Kortnavn) {
    Write-Host 'Avbrutt. Ingenting er endret.'
    exit 1
}

Write-Host ''
Write-Host '=== 1/3 Ressursgruppene'
foreach ($miljo in 'dev', 'prod') {
    $rg = "rg-$Kortnavn-oblig2-$miljo"
    $finnes = (az group exists -n $rg)
    Sjekk 'az group exists'
    if ($finnes -eq 'true') {
        Write-Host "Sletter $rg (tar noen minutter) ..."
        az group delete -n $rg --yes
        Sjekk "az group delete $rg"
    } else {
        Write-Host "$rg finnes ikke. Hopper over."
    }
}

Write-Host ''
Write-Host '=== 2/3 State-filene'
az storage blob delete-batch --account-name $Konto --source $Container --pattern 'oblig2/*' --auth-mode login --output none
Sjekk 'az storage blob delete-batch'
Write-Host 'Blobene under oblig2/ er slettet.'

Write-Host ''
Write-Host '=== 3/3 Koden'
git switch -c $Gren
Sjekk 'git switch'
git rm -r -q --ignore-unmatch stacks modules config/dev config/prod scripts .github .oblig2
Sjekk 'git rm'
git checkout $Forste -- stacks modules config/dev config/prod scripts .github
Sjekk 'git checkout'
git commit -q -m 'Reset til utgangspunktet'
Sjekk 'git commit'
Write-Host "Commit lagt på $Gren."

Write-Host ''
Write-Host 'Ferdig. Videre:'
Write-Host ''
Write-Host "  git push -u origin $Gren"
Write-Host '  gh pr create --fill'
Write-Host ''
Write-Host 'Merge PR-en. CD dev ruller ut utgangspunktet på nytt. Promoter så til prod.'
Write-Host 'Ta et nytt øyeblikksbilde (K2) før du begynner på migreringen igjen.'
Write-Host ''
Write-Host 'Key Vault-ene ligger i soft-delete i 7 dager. Terraform tar dem tilbake når'
Write-Host 'du ruller ut på nytt, så du trenger ikke gjøre noe med dem.'
