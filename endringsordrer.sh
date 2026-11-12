#!/usr/bin/env bash
# =============================================================================
#  endringsordrer.sh  -  oppretter de tre endringsordrene i oblig 2 som Issues
# -----------------------------------------------------------------------------
#  Kjør det fra rota av repoet ditt, når migreringen er ferdig:
#
#      bash endringsordrer.sh
#      bash endringsordrer.sh --kortnavn <ditt-kortnavn>
#
#  Kortnavnet leses fra config/felles.tfvars hvis du ikke oppgir det.
#  Verdiene i ordrene regnes ut fra kortnavnet, så ingen to studenter får de
#  samme. Selvtesten regner ut de samme verdiene og kontrollerer K10.
#
#  Skriptet nekter å kjøre før network, data og app er borte fra
#  state-kontoen. Ordrene skal løses i den nye strukturen.
#
#  Trenger: git, az (innlogget) og gh (innlogget, med tilgang til repoet).
#  Oppretter bare Issues som ikke finnes fra før, så det er trygt å kjøre
#  flere ganger.
# =============================================================================

set -uo pipefail

KORTNAVN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kortnavn)
      [[ $# -ge 2 ]] || { echo "--kortnavn trenger en verdi"; exit 1; }
      KORTNAVN="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Ukjent argument: $1"; echo "Bruk: $0 [--kortnavn <kortnavn>]"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
#  Verdiene. Samme utregning i selvtesten, i PowerShell-utgavene og på
#  endringsordrer.html. Endrer du den her, må du endre den alle stedene.
# ---------------------------------------------------------------------------
verdier() {
  local h
  if command -v sha256sum >/dev/null 2>&1; then
    h="$(printf 'oblig2:%s' "$1" | sha256sum | cut -c1-64)"
  else
    h="$(printf 'oblig2:%s' "$1" | shasum -a 256 | cut -c1-64)"
  fi
  EO_PORT=$(( 8000 + 16#${h:0:4} % 1000 ))
  EO_KILDE="172.16.$(( 16#${h:4:2} )).0/24"
  EO_OKTETT=$(( 2 + 16#${h:6:2} % 248 ))
  if (( 16#${h:8:2} % 2 == 0 )); then EO_NAVN="sok"; else EO_NAVN="betal"; fi
  EO_DEV="10.10.$EO_OKTETT.0/24"
  EO_PROD="10.20.$EO_OKTETT.0/24"
}

fil_verdi() {
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" 2>/dev/null | head -1
}

stopp() { printf '\n  %s\n\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
#  Forutsetninger
# ---------------------------------------------------------------------------
[[ -d .git ]] || stopp "Kjør skriptet fra rota av repoet ditt (der .git ligger)."
[[ -f config/felles.tfvars ]] || stopp "Fant ikke config/felles.tfvars. Er dette repoet for oblig 2?"
[[ -f shared/backend.hcl ]] || stopp "Fant ikke shared/backend.hcl."
command -v az >/dev/null 2>&1 || stopp "Fant ikke az. Installer Azure CLI og kjør az login."
command -v gh >/dev/null 2>&1 || stopp "Fant ikke gh. Installer GitHub CLI og kjør gh auth login."

FRA_FIL="$(fil_verdi config/felles.tfvars kortnavn)"
if [[ -z "$KORTNAVN" ]]; then
  KORTNAVN="$FRA_FIL"
elif [[ "$KORTNAVN" != "$FRA_FIL" ]]; then
  stopp "Du oppga «${KORTNAVN}», men config/felles.tfvars sier «${FRA_FIL}». Bruk kortnavnet ressursene dine faktisk har."
fi
[[ "$KORTNAVN" =~ ^[a-z0-9]{2,10}$ ]] || stopp "Kortnavnet «${KORTNAVN}» er ikke gyldig. Er config/felles.tfvars endret?"

gh auth status >/dev/null 2>&1 || stopp "gh er ikke logget inn. Kjør gh auth login."
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[[ -n "$REPO" ]] || stopp "gh finner ikke GitHub-repoet for denne mappa. Har repoet en remote på github.com?"

KONTO="$(fil_verdi shared/backend.hcl storage_account_name)"
CONTAINER="$(fil_verdi shared/backend.hcl container_name)"

echo
echo "Endringsordrer for oblig 2"
echo "  Kortnavn: $KORTNAVN"
echo "  Repo:     $REPO"
echo "  State:    $KONTO/$CONTAINER"

# ---------------------------------------------------------------------------
#  Er migreringen ferdig? De gamle state-filene skal være borte.
# ---------------------------------------------------------------------------
BLOBER="$(az storage blob list --account-name "$KONTO" --container-name "$CONTAINER" \
            --prefix oblig2/ --auth-mode login --query "[].name" -o tsv 2>/dev/null)" \
  || stopp "Fikk ikke lest state-kontoen. Er du logget inn med az login, i riktig abonnement?"

# Git Bash på Windows kan gi CRLF fra az. Uten dette matcher grep -x aldri.
BLOBER="$(printf '%s' "$BLOBER" | tr -d '\r')"

GAMLE=""
for miljo in dev prod; do
  for stack in network data app; do
    if printf '%s\n' "$BLOBER" | grep -qx "oblig2/$miljo/$stack.tfstate"; then
      GAMLE="$GAMLE oblig2/$miljo/$stack.tfstate"
    fi
  done
done
if [[ -n "$GAMLE" ]]; then
  stopp "Migreringen er ikke ferdig. Disse state-filene finnes fortsatt:$GAMLE
  Endringsordrene skal løses i den nye strukturen. Fullfør K8 først."
fi

# ---------------------------------------------------------------------------
#  Ordrene
# ---------------------------------------------------------------------------
verdier "$KORTNAVN"

T1="EO 1: ordre skal godta TCP $EO_PORT fra $EO_KILDE"
B1="Tjenesten \`ordre\` skal godta innkommende TCP på port **$EO_PORT** fra **$EO_KILDE**, i både dev og prod.

Regelen gjelder bare \`ordre\`. Ingen andre tjenester skal få den.

**Ferdig når:** regelen finnes i NSG-en til \`ordre\` i dev og prod, og andre plan gir \`No changes\`."

T2="EO 2: Utvid adresserommet med $EO_DEV (dev) og $EO_PROD (prod)"
B2="VNet-et skal få et nytt adresseområde i tillegg til det det har:

| Miljø | Nytt adresseområde |
|---|---|
| dev | **$EO_DEV** |
| prod | **$EO_PROD** |

Det eksisterende adresseområdet beholdes. Ingenting skal rives.

**Ferdig når:** VNet-et har begge adresseområdene i dev og prod, og andre plan gir \`No changes\`."

T3="EO 3: Ny tjeneste $EO_NAVN"
B3="Ny tjeneste: **\`$EO_NAVN\`**, med kjøremiljø **web app**, i dev og prod.

| Miljø | Subnett |
|---|---|
| dev | **$EO_DEV** |
| prod | **$EO_PROD** |

Den skal ha det samme oppsettet som \`meny\`: subnett med NSG, storage account, Key Vault, App Service-plan og web app.

Avhenger av EO 2: subnettet ligger i det nye adresseområdet.

**Ferdig når:** tjenesten er rullet ut i dev og prod, og andre plan gir \`No changes\`. PR-en som innfører tjenesten, endrer bare filer under \`config/\` (K9)."

echo
echo "Oppretter Issues i $REPO:"
for i in 1 2 3; do
  eval "tittel=\$T$i; tekst=\$B$i"
  finnes="$(gh issue list --repo "$REPO" --state all --search "\"EO $i:\" in:title" \
              --json title -q ".[] | select(.title | startswith(\"EO $i:\")) | .title" 2>/dev/null | head -1)"
  if [[ -n "$finnes" ]]; then
    echo "  finnes fra før: $finnes"
  elif url="$(gh issue create --repo "$REPO" --title "$tittel" --body "$tekst" 2>&1)"; then
    echo "  opprettet:      $tittel"
    echo "                  $url"
  else
    stopp "gh issue create feilet: $url"
  fi
done

echo
echo "Lukk hver ordre med en PR (skriv «Closes #<nr>» i beskrivelsen), som går til dev og så til prod."
echo
