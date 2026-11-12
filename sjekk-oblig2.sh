#!/usr/bin/env bash
# =============================================================================
#  sjekk-oblig2.sh  -  selvtest for obligatorisk øving 2
# -----------------------------------------------------------------------------
#  Kjør det fra rota av repoet ditt:
#
#      bash sjekk-oblig2.sh --foer     K2: øyeblikksbilde før migreringen
#      bash sjekk-oblig2.sh --etter    K6: øyeblikksbilde etter, og sammenligning
#      bash sjekk-oblig2.sh            alle kravene
#
#  --foer og --etter skriver .oblig2/foer.txt og .oblig2/etter.txt. Ellers
#  LESER skriptet bare. Det endrer ingenting i Azure eller på GitHub.
#
#  Kortnavnet leses fra config/felles.tfvars, og state-kontoen fra
#  shared/backend.hcl. Er du logget inn med az og gh, kjøres også kontrollene
#  mot Azure og GitHub. Ellers blir de HOPPET.
#
#  Ressursene må være rullet ut i dag (nattjobben sletter dem) for at
#  --foer, --etter og K10 skal virke.
#
#  Merk: skriptet kan ta feil. Mener du et avvik er urimelig, skriv det i
#  innleveringen og forklar hvorfor.
# =============================================================================

set -uo pipefail

MODUS="alle"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --foer)  MODUS="foer"; shift ;;
    --etter) MODUS="etter"; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Ukjent argument: $1"; echo "Bruk: $0 [--foer | --etter]"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
#  Utskrift
# ---------------------------------------------------------------------------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  GRONN="$(tput setaf 2)"; ROD="$(tput setaf 1)"; GUL="$(tput setaf 3)"
  GRA="$(tput setaf 8 2>/dev/null || tput setaf 7)"; FET="$(tput bold)"; SLUTT="$(tput sgr0)"
else
  GRONN=""; ROD=""; GUL=""; GRA=""; FET=""; SLUTT=""
fi

ANTALL_OK=0; ANTALL_AVVIK=0; ANTALL_MANUELL=0; ANTALL_HOPPET=0
AVVIKSLISTE=""

ok()      { printf '  %sOK%s       %-5s %s\n' "$GRONN" "$SLUTT" "$1" "$2"; ANTALL_OK=$((ANTALL_OK+1)); }
avvik()   { printf '  %sAVVIK%s    %-5s %s\n' "$ROD" "$SLUTT" "$1" "$2"
            printf '           %s→ %s%s\n' "$GRA" "$3" "$SLUTT"
            ANTALL_AVVIK=$((ANTALL_AVVIK+1)); AVVIKSLISTE="$AVVIKSLISTE $1"; }
manuell() { printf '  %sMANUELL%s  %-5s %s\n' "$GUL" "$SLUTT" "$1" "$2"
            printf '           %s→ %s%s\n' "$GRA" "$3" "$SLUTT"
            ANTALL_MANUELL=$((ANTALL_MANUELL+1)); }
hoppet()  { printf '  %sHOPPET%s   %-5s %s\n' "$GRA" "$SLUTT" "$1" "$2"
            printf '           %s→ %s%s\n' "$GRA" "$3" "$SLUTT"
            ANTALL_HOPPET=$((ANTALL_HOPPET+1)); }
bolk()    { printf '\n%s%s%s\n' "$FET" "$1" "$SLUTT"; }
stopp()   { printf '\n  %s%s%s\n\n' "$ROD" "$1" "$SLUTT" >&2; exit 1; }

# ---------------------------------------------------------------------------
#  Hjelpere
# ---------------------------------------------------------------------------

fil_verdi() {
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" 2>/dev/null | head -1
}

# Verdiene i endringsordrene. Samme utregning som i endringsordrer.sh.
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

# Alle .tf-filer i arbeidstreet, uten .terraform/.
tf_filer() {
  find . -name '*.tf' -not -path '*/.terraform/*' -not -path './.git/*' 2>/dev/null
}

# Teller filer med treff, uten `| grep -q` (SIGPIPE under pipefail).
antall_treff() {
  local monster="$1"; shift
  grep -rIlE --exclude-dir=.git --exclude-dir=.terraform "$monster" "$@" 2>/dev/null | wc -l | tr -d ' '
}

# Ressurstypene en state-fil EIER (mode managed, ikke data-kilder).
managed_typer() {
  grep -A1 '"mode": "managed"' "$1" 2>/dev/null | sed -n 's/.*"type": "\([^"]*\)".*/\1/p'
}
eier_type() { managed_typer "$1" | grep -qx "$2"; }

# ---------------------------------------------------------------------------
#  Felles oppsett
# ---------------------------------------------------------------------------

echo
printf '%sSelvtest for obligatorisk øving 2%s\n' "$FET" "$SLUTT"
printf '%sRepo: %s%s\n' "$GRA" "$(pwd)" "$SLUTT"

[[ -d .git ]] || stopp "Dette ser ikke ut som rota av et git-repo. Kjør skriptet fra mappa der .git ligger."
[[ -f config/felles.tfvars ]] || stopp "Fant ikke config/felles.tfvars. Er dette repoet for oblig 2?"

KORTNAVN="$(fil_verdi config/felles.tfvars kortnavn)"
KONTO="$(fil_verdi shared/backend.hcl storage_account_name)"
CONTAINER="$(fil_verdi shared/backend.hcl container_name)"
printf '%sKortnavn: %s   State: %s/%s%s\n' "$GRA" "$KORTNAVN" "$KONTO" "$CONTAINER" "$SLUTT"

[[ "$KORTNAVN" =~ ^[a-z0-9]{2,10}$ ]] || stopp "Kortnavnet «${KORTNAVN}» i config/felles.tfvars er ikke gyldig."

AZ_OK=false
if command -v az >/dev/null 2>&1 && SUB="$(az account show --query id -o tsv 2>/dev/null | tr -d '\r')" && [[ -n "$SUB" ]]; then
  AZ_OK=true
fi
GH_OK=false
REPO=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
  [[ -n "$REPO" ]] && GH_OK=true
fi

verdier "$KORTNAVN"

# ---------------------------------------------------------------------------
#  Øyeblikksbilder (--foer og --etter)
# ---------------------------------------------------------------------------
#  Én linje per ressurs: miljø, ressurs-ID, type og createdTime. Ressurs-ID-en
#  er den samme også etter en replace. createdTime er det ikke.
#  /subscriptions/<id> fjernes fra ID-en, siden fila committes i repoet.

ta_bilde() {
  local fil="$1" tmp miljo rg
  $AZ_OK || stopp "Du må være logget inn med az login for å ta et øyeblikksbilde."
  mkdir -p .oblig2
  tmp="$(mktemp)"
  for miljo in dev prod; do
    rg="rg-$KORTNAVN-oblig2-$miljo"
    if [[ "$(az group exists -n "$rg" 2>/dev/null | tr -d '\r')" != "true" ]]; then
      rm -f "$tmp"
      stopp "Ressursgruppa $rg finnes ikke. Rull ut $miljo i dag (CD dev / CD prod) før du tar øyeblikksbildet."
    fi
    if ! ut="$(az rest --method get \
      --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$rg/resources?\$expand=createdTime&api-version=2021-04-01" \
      --query "value[].[id, type, createdTime]" -o tsv 2>/dev/null)"; then
      rm -f "$tmp"
      stopp "Fikk ikke lest ressursene i $rg (az rest feilet). Prøv igjen, og sjekk az account show."
    fi
    ut="$(printf '%s' "$ut" | tr -d '\r')"
    if [[ -z "$ut" ]]; then
      rm -f "$tmp"
      stopp "Fant ingen ressurser i $rg. Er $miljo rullet ut i dag?"
    fi
    printf '%s\n' "$ut" \
      | awk -F'\t' -v m="$miljo" 'NF>=3 { id = tolower($1); sub(/^\/subscriptions\/[^\/]+/, "", id); print m "\t" id "\t" $2 "\t" $3 }' >> "$tmp"
  done
  # LC_ALL=C: samme rekkefølge på alle maskiner, så filene kan sammenlignes.
  LC_ALL=C sort "$tmp" > "$fil"
  rm -f "$tmp"
  printf '\n  Lagret %s: %s ressurser (dev og prod)\n' "$fil" "$(wc -l < "$fil" | tr -d ' ')"
}

# Sammenligner foer og etter. Skriver OK eller AVVIK for K6.
sammenlign_bilder() {
  local mangler endret borte linje id
  if [[ ! -f .oblig2/foer.txt ]]; then
    avvik "K6" "Ingenting ble revet" "Fant ikke .oblig2/foer.txt. Den lages med --foer (K2)"
    return
  fi
  if [[ ! -f .oblig2/etter.txt ]]; then
    avvik "K6" "Ingenting ble revet" "Fant ikke .oblig2/etter.txt. Kjør --etter samme dag som migreringen"
    return
  fi
  mangler="$(LC_ALL=C comm -23 <(cut -f1,2,4 .oblig2/foer.txt | LC_ALL=C sort) <(cut -f1,2,4 .oblig2/etter.txt | LC_ALL=C sort))"
  if [[ -z "$mangler" ]]; then
    ok "K6" "Alle $(wc -l < .oblig2/foer.txt | tr -d ' ') ressursene har samme ID og createdTime før og etter"
    return
  fi
  endret=""; borte=""
  while IFS=$'\t' read -r _ id _; do
    if cut -f2 .oblig2/etter.txt | grep -qxF "$id"; then
      endret="$endret ${id##*/}"
    else
      borte="$borte ${id##*/}"
    fi
  done <<< "$mangler"
  [[ -n "$endret" ]] && avvik "K6" "Ingenting ble revet" \
    "Ny createdTime, altså bygget på nytt:$endret. Ble foer.txt tatt en annen dag enn etter.txt?"
  [[ -n "$borte" ]] && avvik "K6" "Ingenting ble revet" "Finnes ikke lenger:$borte"
}

if [[ "$MODUS" == "foer" ]]; then
  bolk "K2 · Øyeblikksbilde før migreringen"
  [[ -f .oblig2/foer.txt ]] && printf '  %sErstatter forrige .oblig2/foer.txt%s\n' "$GUL" "$SLUTT"
  ta_bilde .oblig2/foer.txt
  printf '\n  Commit den nå, FØR første migrerings-commit:\n\n'
  printf '      git add .oblig2/foer.txt\n      git commit -m "K2: øyeblikksbilde før migreringen"\n\n'
  printf '  %sMigreringen må bli ferdig i dag. Nattjobben sletter ressursene.%s\n\n' "$GUL" "$SLUTT"
  exit 0
fi

if [[ "$MODUS" == "etter" ]]; then
  bolk "K6 · Øyeblikksbilde etter migreringen"
  ta_bilde .oblig2/etter.txt
  echo
  sammenlign_bilder
  printf '\n  Commit den:\n\n      git add .oblig2/etter.txt\n      git commit -m "K6: øyeblikksbilde etter migreringen"\n\n'
  [[ $ANTALL_AVVIK -eq 0 ]] && exit 0 || exit 1
fi

# ===========================================================================
#  A · UTGANGSPUNKT
# ===========================================================================

bolk "A · Utgangspunkt"

# --- K1: rullet ut av workflowen, i dev og prod ----------------------------
if $GH_OK; then
  DEV_OK="$(gh run list --workflow cd-dev.yml --status success --limit 1 --json databaseId -q 'length' 2>/dev/null)"
  PROD_OK="$(gh run list --workflow cd-prod.yml --status success --limit 1 --json databaseId -q 'length' 2>/dev/null)"
  if [[ "${DEV_OK:-0}" -ge 1 && "${PROD_OK:-0}" -ge 1 ]]; then
    ok "K1" "Vellykkede kjøringer av CD dev og CD prod finnes"
  else
    avvik "K1" "Rullet ut i dev og prod av workflowen" \
          "Fant ikke en vellykket kjøring av både cd-dev.yml og cd-prod.yml i $REPO"
  fi
else
  hoppet "K1" "Rullet ut i dev og prod av workflowen" "Logg inn med gh auth login for å sjekke kjøringene"
fi
if [[ "$(antall_treff 'id-token:[[:space:]]*write' .github/workflows)" -gt 0 && \
      "$(antall_treff 'creds:[[:space:]]*\$\{\{' .github/workflows)" -eq 0 ]]; then
  ok "K1" "Workflowene logger inn med OIDC (id-token: write, ingen creds:)"
else
  avvik "K1" "Workflowene logger inn med OIDC" "Fant ikke id-token: write, eller fant creds: med en secret"
fi

# --- K2: foer.txt committet før første migrerings-commit -------------------
FOER_COMMIT="$(git log -1 --format=%H -- .oblig2/foer.txt 2>/dev/null)"
if [[ -z "$FOER_COMMIT" ]]; then
  avvik "K2" "Øyeblikksbilde committet før migreringen" \
        "Fant ingen commit av .oblig2/foer.txt. Kjør --foer, og commit fila før du flytter noe"
else
  ETTER_FOER="$(git log --format=%H -S 'destroy = false' "$FOER_COMMIT"..HEAD -- '*.tf' 2>/dev/null | head -1)"
  if [[ -n "$ETTER_FOER" ]]; then
    ok "K2" "foer.txt (${FOER_COMMIT:0:7}) er committet før migrerings-commitene"
  else
    avvik "K2" "Øyeblikksbilde committet før migreringen" \
          "Fant ingen commit med 'destroy = false' etter ${FOER_COMMIT:0:7}. Ble foer.txt committet etter at flyttingen startet?"
  fi
fi

# ===========================================================================
#  B · MIGRERINGEN
# ===========================================================================

bolk "B · Migreringen"

# --- K3: shared-network og én service, ingen tjenestenavn under stacks/ ----
STACKMAPPER="$(find stacks -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|^stacks/||' | sort | tr '\n' ' ')"
if [[ -d stacks/shared-network && -d stacks/service ]]; then
  ok "K3" "stacks/shared-network og stacks/service finnes"
else
  avvik "K3" "stacks/shared-network og stacks/service" "Fant disse mappene under stacks/: ${STACKMAPPER:-ingen}"
fi
TJENESTESTIER="$(find stacks 2>/dev/null | grep -iE "ordre|meny|sok|betal" | head -3 | tr '\n' ' ')"
if [[ -z "$TJENESTESTIER" ]]; then
  ok "K3" "Ingen tjenestenavn i fil- eller mappenavn under stacks/"
else
  avvik "K3" "Ingen tjenestenavn under stacks/" \
        "Fant: $TJENESTESTIER. Tjenesten er en parameter (config/<miljø>/service-<navn>.tfvars), ikke en mappe"
fi

# --- K4: removed og import som kode ----------------------------------------
N_REMOVED="$(git log --format=%H -S 'destroy = false' -- '*.tf' 2>/dev/null | wc -l | tr -d ' ')"
N_IMPORT="$(git log --format=%H -S 'import {' -- '*.tf' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$N_REMOVED" -gt 0 && "$N_IMPORT" -gt 0 ]]; then
  ok "K4" "Historikken har removed med destroy = false ($N_REMOVED commits) og import ($N_IMPORT commits)"
else
  avvik "K4" "Flyttingen skrevet som kode" \
        "git log -S fant 'destroy = false' i $N_REMOVED og 'import {' i $N_IMPORT commits. Begge skal finnes"
fi

# --- K5: ingen /subscriptions/ i koden, heller ikke i historikken ----------
NAA="$(tf_filer | xargs grep -l '/subscriptions/' 2>/dev/null | tr '\n' ' ')"
HISTORIE="$(git log --format=%h -G '/subscriptions/' -- '*.tf' '*.tfvars' 2>/dev/null | head -3 | tr '\n' ' ')"
if [[ -n "$NAA" ]]; then
  avvik "K5" "Ingen /subscriptions/ i koden" "Fant det i: $NAA"
elif [[ -n "$HISTORIE" ]]; then
  avvik "K5" "Ingen /subscriptions/ i koden" \
        "Fant det i historikken (commits $HISTORIE). Import-ID-ene skal bygges, ikke skrives av"
else
  ok "K5" "Ingen /subscriptions/ i .tf- eller .tfvars-filer, heller ikke i historikken"
fi

# --- K6: samme ressurser før og etter --------------------------------------
sammenlign_bilder
manuell "K6" "Ingen migreringskjøring hadde to destroy > 0" \
        "Subnett, NSG-regler og NSG-koblinger er ikke med i øyeblikksbildet. Planene på migrerings-PR-ene viser dem"

# --- K7: samme commit til dev og prod --------------------------------------
if $GH_OK && [[ -n "$FOER_COMMIT" ]]; then
  MIG_COMMITS="$(git log --first-parent --format=%H "$FOER_COMMIT"..HEAD -- stacks modules config 2>/dev/null)"
  if [[ -z "$MIG_COMMITS" ]]; then
    avvik "K7" "Samme commit til dev og prod" "Fant ingen commits på main som endrer stacks/, modules/ eller config/ etter foer.txt"
  else
    TITLER="$(gh run list --status success --limit 300 --json displayTitle -q '.[].displayTitle' 2>/dev/null)"
    MANGLER=""
    for c in $MIG_COMMITS; do
      DEV="$(printf '%s\n' "$TITLER" | awk -v c="$c" '$1=="dev" && length($3)>=7 && index(c,$3)==1' | head -1)"
      PROD="$(printf '%s\n' "$TITLER" | awk -v c="$c" '$1=="prod" && length($3)>=7 && index(c,$3)==1' | head -1)"
      [[ -n "$DEV" && -n "$PROD" ]] || MANGLER="$MANGLER ${c:0:7}"
    done
    if [[ -z "$MANGLER" ]]; then
      ok "K7" "Alle $(echo "$MIG_COMMITS" | wc -l | tr -d ' ') commitene på main etter foer.txt er rullet ut i både dev og prod"
    else
      avvik "K7" "Samme commit til dev og prod" \
            "Fant ikke en vellykket CD dev- og CD prod-kjøring for:$MANGLER (CD prod tar hele SHA-en)"
    fi
  fi
elif ! $GH_OK; then
  hoppet "K7" "Samme commit til dev og prod" "Logg inn med gh auth login for å sjekke kjøringene"
else
  hoppet "K7" "Samme commit til dev og prod" "Krever at .oblig2/foer.txt er committet (K2)"
fi

# --- K8: ryddet etterpå -----------------------------------------------------
BLOKKER="$(tf_filer | xargs grep -lE '^[[:space:]]*(removed|import)[[:space:]]*\{' 2>/dev/null | tr '\n' ' ')"
if [[ -z "$BLOKKER" ]]; then
  ok "K8" "Ingen removed- eller import-blokker igjen"
else
  avvik "K8" "Ingen removed- eller import-blokker igjen" "Fant dem i: $BLOKKER"
fi
GAMLE_MAPPER=""; for s in network data app; do [[ -d "stacks/$s" ]] && GAMLE_MAPPER="$GAMLE_MAPPER stacks/$s"; done
GAMLE_FILER="$(ls config/dev/{network,data,app}.tfvars config/prod/{network,data,app}.tfvars 2>/dev/null | tr '\n' ' ')"
if [[ -z "$GAMLE_MAPPER$GAMLE_FILER" ]]; then
  ok "K8" "network, data og app er borte fra stacks/ og config/"
else
  avvik "K8" "De gamle stackene er borte fra repoet" "Fant fortsatt:$GAMLE_MAPPER $GAMLE_FILER"
fi

BLOBER=""
if $AZ_OK; then
  BLOBER="$(az storage blob list --account-name "$KONTO" --container-name "$CONTAINER" --prefix oblig2/ \
              --auth-mode login --query "[].name" -o tsv 2>/dev/null | tr -d '\r')"
  if [[ -z "$BLOBER" ]]; then
    hoppet "K8" "De gamle state-filene er slettet" "Fikk ikke lest $KONTO/$CONTAINER, eller den er tom under oblig2/"
  else
    GAMLE_BLOBER=""
    for m in dev prod; do for s in network data app; do
      printf '%s\n' "$BLOBER" | grep -qx "oblig2/$m/$s.tfstate" && GAMLE_BLOBER="$GAMLE_BLOBER oblig2/$m/$s.tfstate"
    done; done
    if [[ -z "$GAMLE_BLOBER" ]]; then
      ok "K8" "De gamle state-filene er slettet fra state-kontoen"
    else
      avvik "K8" "De gamle state-filene er slettet" "Finnes fortsatt:$GAMLE_BLOBER"
    fi
  fi
else
  hoppet "K8" "De gamle state-filene er slettet" "Logg inn med az login for å sjekke state-kontoen"
fi
manuell "K8" "Alle stackene gir No changes i begge miljøene" \
        "CI-planen på siste PR skal vise ✅ No changes for hver stack, både mot dev og prod"

# ===========================================================================
#  C · NY TJENESTE OG ENDRINGSORDRER
# ===========================================================================

bolk "C · Ny tjeneste og endringsordrer"
printf '  %sDine verdier: port %s fra %s · nytt område %s / %s · ny tjeneste %s%s\n' \
  "$GRA" "$EO_PORT" "$EO_KILDE" "$EO_DEV" "$EO_PROD" "$EO_NAVN" "$SLUTT"

# --- K9: tjeneste C kom inn med en PR som bare endret config/ -------------
C_FIL="config/dev/service-$EO_NAVN.tfvars"
# --name-only i stedet for patch: --diff-merges slår ellers på -p.
C_COMMIT="$(git log --first-parent --diff-merges=first-parent --diff-filter=A --name-only --format='C %H' -- "$C_FIL" 2>/dev/null | sed -n 's/^C //p' | tail -1)"
if [[ -z "$C_COMMIT" ]]; then
  avvik "K9" "Tjeneste $EO_NAVN er en ny instans av service" \
        "Fant ingen commit på main som legger til $C_FIL"
else
  ENDRET="$(git diff --name-only "$C_COMMIT^1" "$C_COMMIT" 2>/dev/null)"
  UTENFOR="$(printf '%s\n' "$ENDRET" | grep -v '^config/' | grep -v '^$' | tr '\n' ' ')"
  if [[ -z "$ENDRET" ]]; then
    avvik "K9" "PR-en for tjeneste $EO_NAVN endrer bare config/" "Fikk ikke lest endringene i ${C_COMMIT:0:7}"
  elif [[ -z "$UTENFOR" ]]; then
    ok "K9" "Commiten som innførte $EO_NAVN (${C_COMMIT:0:7}) endret bare filer under config/"
  else
    avvik "K9" "PR-en for tjeneste $EO_NAVN endrer bare config/" \
          "${C_COMMIT:0:7} endret også: $UTENFOR"
  fi
fi

# --- K10: endringsordrene er lukket, og ressursene stemmer -----------------
if $GH_OK; then
  for i in 1 2 3; do
    STATUS="$(gh issue list --state all --search "\"EO $i:\" in:title" --json title,state \
                -q ".[] | select(.title | startswith(\"EO $i:\")) | .state" 2>/dev/null | head -1)"
    case "$STATUS" in
      CLOSED) ok "K10" "EO $i er lukket" ;;
      OPEN)   avvik "K10" "EO $i er lukket" "Issuet er fortsatt åpent. Lukk det med en PR (Closes #<nr>)" ;;
      *)      avvik "K10" "EO $i finnes" "Fant ikke Issuet. Kjør endringsordrer.sh når migreringen er ferdig" ;;
    esac
  done
else
  hoppet "K10" "Endringsordrene er lukket" "Logg inn med gh auth login"
fi

if ! $AZ_OK; then
  hoppet "K10" "Ressursene finnes med riktige verdier" "Logg inn med az login"
else
  STATEMAPPE="$(mktemp -d)"
  for b in $BLOBER; do
    az storage blob download --account-name "$KONTO" --container-name "$CONTAINER" --name "$b" \
      --file "$STATEMAPPE/$(echo "$b" | tr '/' '_')" --auth-mode login -o none 2>/dev/null
  done

  for miljo in dev prod; do
    rg="rg-$KORTNAVN-oblig2-$miljo"
    if [[ "$miljo" == "dev" ]]; then OMRAADE="$EO_DEV"; else OMRAADE="$EO_PROD"; fi
    if [[ "$(az group exists -n "$rg" 2>/dev/null | tr -d '\r')" != "true" ]]; then
      hoppet "K10" "Ressursene i $miljo" "$rg finnes ikke. Rull ut $miljo i dag først"
      continue
    fi

    # EO 1: NSG-regelen på ordre, og i ordre sin state
    REGEL="$(az network nsg rule list -g "$rg" --nsg-name nsg-ordre \
      --query "[?access=='Allow' && direction=='Inbound' && (destinationPortRange=='$EO_PORT' || contains(destinationPortRanges || \`[]\`, '$EO_PORT')) && (sourceAddressPrefix=='$EO_KILDE' || contains(sourceAddressPrefixes || \`[]\`, '$EO_KILDE'))] | length(@)" \
      -o tsv 2>/dev/null | tr -d '\r')"
    if [[ "${REGEL:-0}" -ge 1 ]]; then
      NOKKEL=""
      for f in "$STATEMAPPE"/oblig2_"$miljo"_*.tfstate; do
        [[ -e "$f" ]] || continue
        if eier_type "$f" azurerm_network_security_rule && grep -q "\"$EO_PORT\"" "$f" && grep -q '"vm-ordre"' "$f"; then
          NOKKEL="$(basename "$f" .tfstate | sed "s/^oblig2_${miljo}_//")"
        fi
      done
      if [[ -n "$NOKKEL" ]]; then
        ok "K10" "EO 1 ($miljo): regelen finnes, og eies av samme state som ordre ($NOKKEL)"
      else
        avvik "K10" "EO 1 ($miljo): regelen i riktig state" \
              "Regelen finnes i Azure, men ikke i state-fila som eier vm-ordre"
      fi
    else
      avvik "K10" "EO 1 ($miljo): TCP $EO_PORT fra $EO_KILDE på nsg-ordre" "Fant ingen slik Allow/Inbound-regel"
    fi

    # EO 2: adresserommet, i shared-network sin state
    ROM="$(az network vnet show -g "$rg" -n "vnet-$KORTNAVN-$miljo" --query "addressSpace.addressPrefixes" -o tsv 2>/dev/null | tr -d '\r')"
    if printf '%s\n' "$ROM" | grep -qxF "$OMRAADE"; then
      SN="$STATEMAPPE/oblig2_${miljo}_shared-network.tfstate"
      if [[ -f "$SN" ]] && eier_type "$SN" azurerm_virtual_network && grep -qF "\"$OMRAADE\"" "$SN"; then
        ok "K10" "EO 2 ($miljo): $OMRAADE er i adresserommet, og eies av shared-network"
      else
        avvik "K10" "EO 2 ($miljo): adresserommet i riktig state" \
              "$OMRAADE finnes i Azure, men ikke i VNet-et i oblig2/$miljo/shared-network.tfstate"
      fi
    else
      avvik "K10" "EO 2 ($miljo): $OMRAADE i adresserommet" "VNet-et har: $(echo $ROM)"
    fi

    # EO 3: ny tjeneste, i sin egen state
    APP="app-$KORTNAVN-$EO_NAVN-$miljo"
    APP_STATE="$(az webapp show -g "$rg" -n "$APP" --query state -o tsv 2>/dev/null | tr -d '\r')"
    SNETT="$(az network vnet subnet show -g "$rg" --vnet-name "vnet-$KORTNAVN-$miljo" -n "snet-$EO_NAVN" \
               --query "addressPrefix || addressPrefixes[0]" -o tsv 2>/dev/null | tr -d '\r')"
    if [[ -n "$APP_STATE" && "$SNETT" == "$OMRAADE" ]]; then
      NOKKEL=""
      for f in "$STATEMAPPE"/oblig2_"$miljo"_*.tfstate; do
        [[ -e "$f" ]] || continue
        if eier_type "$f" azurerm_linux_web_app && grep -q "\"$APP\"" "$f"; then
          NOKKEL="$(basename "$f" .tfstate | sed "s/^oblig2_${miljo}_//")"
          if grep -q '"vm-ordre"' "$f" || grep -q "\"app-$KORTNAVN-meny-$miljo\"" "$f"; then NOKKEL="DELT:$NOKKEL"; fi
        fi
      done
      case "$NOKKEL" in
        "")     avvik "K10" "EO 3 ($miljo): $EO_NAVN i egen state" "Web app-en finnes i Azure, men ikke i noen state-fil" ;;
        DELT:*) avvik "K10" "EO 3 ($miljo): $EO_NAVN i egen state" "${NOKKEL#DELT:} eier også ordre eller meny. Hver tjeneste skal ha sin egen instans" ;;
        *)      ok "K10" "EO 3 ($miljo): $APP kjører med subnett $SNETT, i egen state ($NOKKEL)" ;;
      esac
    else
      avvik "K10" "EO 3 ($miljo): $APP med subnett $OMRAADE" \
            "Fant web app: ${APP_STATE:-nei}. Fant snet-$EO_NAVN med: ${SNETT:-ingenting}"
    fi
  done
  rm -rf "$STATEMAPPE"
fi

# ===========================================================================
#  D · KVALITET
# ===========================================================================

bolk "D · Kvalitet"

# --- K11: porten og beskyttet main -----------------------------------------
if [[ -f .tflint.hcl && -f .checkov.yaml ]] && [[ "$(antall_treff 'valider\.sh' .github/workflows)" -gt 0 ]]; then
  ok "K11" "Porten (valider.sh med TFLint og Checkov) kjører i en workflow"
else
  avvik "K11" "Porten kjører på PR" "Fant ikke .tflint.hcl og .checkov.yaml, eller ingen workflow som kjører valider.sh"
fi
if [[ "$(grep -c 'skip-check' .checkov.yaml 2>/dev/null)" -gt 0 ]]; then
  manuell "K11" "Checkov-skip i .checkov.yaml" "Skip som gjelder hele repoet, må begrunnes i innleveringen"
fi
if $GH_OK; then
  KRAV="$( { gh api "repos/$REPO/branches/main/protection" -q '.required_status_checks.contexts[]?, .required_status_checks.checks[]?.context' 2>/dev/null
             gh api "repos/$REPO/rules/branches/main" -q '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context' 2>/dev/null; } | sort -u)"
  MANGLER=""
  for k in "kodekontroll" "plan mot dev" "plan mot prod"; do
    printf '%s\n' "$KRAV" | grep -qxF "$k" || MANGLER="$MANGLER «${k}»"
  done
  if [[ -z "$MANGLER" ]]; then
    ok "K11" "main krever kodekontroll, plan mot dev og plan mot prod"
  else
    avvik "K11" "main er beskyttet med required status checks" "Mangler:$MANGLER"
  fi
else
  hoppet "K11" "main er beskyttet" "Logg inn med gh auth login"
fi

# --- K12: konfigurasjon i config/, ingen hemmeligheter ---------------------
UTENFOR="$(git ls-files '*.tfvars' | grep -v '^config/' | tr '\n' ' ')"
if [[ -z "$UTENFOR" ]]; then
  ok "K12" "Alle .tfvars-filene ligger under config/"
else
  avvik "K12" "Konfigurasjonen ligger i config/" "Fant .tfvars utenfor config/: $UTENFOR"
fi
HEMMELIG='BEGIN [A-Z ]*PRIVATE KEY|AccountKey=|client_secret[[:space:]]*=[[:space:]]*"[^"]+"|ARM_CLIENT_SECRET[[:space:]]*[:=][[:space:]]*[^[:space:]$]|password[[:space:]]*=[[:space:]]*"[^"]+"|[?&]sig=[A-Za-z0-9%]{20,}|[0-9A-Za-z_~.-]{3}[0-9]Q~[0-9A-Za-z_~.-]{31,34}'
FUNN="$(git log --all -p 2>/dev/null | grep -E '^\+' | grep -cE "$HEMMELIG")"
if [[ "$FUNN" -eq 0 ]]; then
  ok "K12" "Fant ingen kjente hemmelighetsmønstre i historikken"
else
  avvik "K12" "Ingen hemmeligheter i repoet" \
        "Fant $FUNN linje(r) som ligner en privat nøkkel, kontonøkkel, client secret eller passord. Søk: git log --all -p | grep -E 'PRIVATE KEY|AccountKey|secret|password'"
fi

# ===========================================================================
#  Oppsummering
# ===========================================================================

echo
printf '%s─────────────────────────────────────────────%s\n' "$GRA" "$SLUTT"
printf '  %sOK: %d%s   %sAvvik: %d%s   %sManuell: %d%s   %sHoppet over: %d%s\n' \
  "$GRONN" "$ANTALL_OK" "$SLUTT" "$ROD" "$ANTALL_AVVIK" "$SLUTT" \
  "$GUL" "$ANTALL_MANUELL" "$SLUTT" "$GRA" "$ANTALL_HOPPET" "$SLUTT"

if [[ "$ANTALL_AVVIK" -gt 0 ]]; then
  UNIKE="$(printf '%s\n' $AVVIKSLISTE | sort -u | sort -t K -k 2 -n | tr '\n' ' ' | sed 's/ $//')"
  printf '\n  Avvik på: %s\n' "$UNIKE"
  printf '  %sRett dem, og kjør skriptet på nytt.%s\n\n' "$GRA" "$SLUTT"
  exit 1
fi
if [[ "$ANTALL_HOPPET" -gt 0 ]]; then
  printf '\n  %sIngen avvik, men noen kontroller ble hoppet over.%s\n' "$GUL" "$SLUTT"
  printf '  %sLogg inn med az login og gh auth login, og rull ut begge miljøene i dag, før du leverer.%s\n\n' "$GRA" "$SLUTT"
  exit 0
fi
printf '\n  %sIngen avvik. Husk de manuelle punktene i innleveringen.%s\n\n' "$GRONN" "$SLUTT"
exit 0
