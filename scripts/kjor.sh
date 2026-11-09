#!/usr/bin/env bash
# =============================================================================
#  scripts/kjor.sh  –  plan eller apply for alle stackene i ett miljø
# -----------------------------------------------------------------------------
#  Bruk:
#      bash scripts/kjor.sh <dev|prod> <plan|apply>
#
#  Hvilke stacker som kjøres, bestemmes av filene i config/<miljø>/, ikke av
#  en liste i dette skriptet. Hver fil er én instans av en stack, med sin egen
#  state-fil:
#
#      config/dev/network.tfvars    → stacks/network/   key oblig2/dev/network.tfstate
#      config/dev/<type>-<x>.tfvars → stacks/<type>/    key oblig2/dev/<type>-<x>.tfstate
#
#  Den andre linja gjelder bare når det ikke finnes en mappe som heter det
#  samme som fila. Da gir to filer to instanser av samme stack.
#
#  Rekkefølgen styres av LAG under. En stack som leser outputs fra en annen
#  med terraform_remote_state, må komme etter den. Mapper som ikke finnes,
#  hoppes over. En config-fil som ikke passer i noe lag, gir feil.
#
#    plan   Planlegger alle stackene. Fortsetter selv om én feiler.
#    apply  Planlegger og ruller ut, én stack om gangen. Stopper ved første
#           feil.
#
#  Alle stackene får -var-file=config/felles.tfvars i tillegg til sin egen
#  fil, og disse variablene fra miljøet:
#      TF_VAR_miljo                       dev eller prod
#      TF_VAR_state_resource_group_name   fra shared/backend.hcl
#      TF_VAR_state_storage_account_name  fra shared/backend.hcl
#      TF_VAR_state_container_name        fra shared/backend.hcl
#
#  Skriver et sammendrag i Markdown til rapport.md. Workflowene legger det på
#  PR-en eller i jobbsammendraget.
#
#  Lokalt kjører du som deg selv: `az login` først. Abonnementet hentes fra
#  az-økta hvis ARM_SUBSCRIPTION_ID ikke er satt.
# =============================================================================

set -uo pipefail

LAG="network shared-network data app service"

MILJO="${1:-}"
HANDLING="${2:-}"

case "$MILJO" in dev|prod) ;; *) echo "Miljø må være dev eller prod" >&2; exit 64 ;; esac
case "$HANDLING" in plan|apply) ;; *) echo "Handling må være plan eller apply" >&2; exit 64 ;; esac

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
ROT="$(pwd)"
RAPPORT="${RAPPORT:-$ROT/rapport.md}"
: > "$RAPPORT"

if [ -z "${ARM_SUBSCRIPTION_ID:-}" ]; then
  ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)" || exit 1
  export ARM_SUBSCRIPTION_ID
fi

# Leser én verdi fra shared/backend.hcl, f.eks. storage_account_name.
backend_verdi() {
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$ROT/shared/backend.hcl" | head -1
}

export TF_VAR_miljo="$MILJO"
export TF_VAR_state_resource_group_name="$(backend_verdi resource_group_name)"
export TF_VAR_state_storage_account_name="$(backend_verdi storage_account_name)"
export TF_VAR_state_container_name="$(backend_verdi container_name)"

# Hvilken mappe under stacks/ en config-fil hører til.
stackmappe() {
  if [ -d "$ROT/stacks/$1" ]; then
    echo "$1"
  elif [ -d "$ROT/stacks/${1%%-*}" ]; then
    echo "${1%%-*}"
  fi
}

# Bygg lista over config-filer i lagrekkefølge.
filer=""
for lag in $LAG; do
  for fil in "$ROT/config/$MILJO/"*.tfvars; do
    [ -e "$fil" ] || continue
    navn="$(basename "$fil" .tfvars)"
    [ "$(stackmappe "$navn")" = "$lag" ] && filer="$filer $navn"
  done
done

for fil in "$ROT/config/$MILJO/"*.tfvars; do
  [ -e "$fil" ] || continue
  navn="$(basename "$fil" .tfvars)"
  case " $filer " in
    *" $navn "*) ;;
    *)
      echo "::error::config/$MILJO/$navn.tfvars passer ikke i noe lag. Finnes stacks/$navn/ eller stacks/${navn%%-*}/, og står den i LAG i scripts/kjor.sh?" >&2
      exit 1
      ;;
  esac
done

echo "Rekkefølge i $MILJO:$filer"

resultat=0   # 0 = ingen endringer, 2 = endringer, 1 = feil

for navn in $filer; do
  stack="$(stackmappe "$navn")"
  echo "::group::$navn ($MILJO) → stacks/$stack"
  cd "$ROT/stacks/$stack" || exit 1

  if ! terraform init -input=false -reconfigure \
        -backend-config="$ROT/shared/backend.hcl" \
        -backend-config="key=oblig2/$MILJO/$navn.tfstate" > init.log 2>&1; then
    cat init.log
    echo "::endgroup::"
    echo "### ❌ $navn – init feilet" >> "$RAPPORT"
    resultat=1
    rm -f init.log
    [ "$HANDLING" = apply ] && break || continue
  fi

  VARFILER=(-var-file="$ROT/config/felles.tfvars" -var-file="$ROT/config/$MILJO/$navn.tfvars")

  if [ "$HANDLING" = apply ]; then
    # Vent på låsen i stedet for å feile hvis en annen kjøring holder den.
    if terraform plan -input=false -lock-timeout=5m "${VARFILER[@]}" -out=tfplan -no-color > plan.txt 2>&1; then
      terraform apply -input=false -lock-timeout=5m -no-color tfplan >> plan.txt 2>&1
      kode=$?
    else
      kode=1
    fi
    rm -f tfplan
  else
    # Planen skriver ingenting, så den skal ikke ta låsen fra en utrulling.
    terraform plan -input=false -lock=false -detailed-exitcode "${VARFILER[@]}" -no-color > plan.txt 2>&1
    kode=$?
  fi

  cat plan.txt
  echo "::endgroup::"

  # En stack som leser state fra en stack som ikke er rullet ut ennå, kan ikke
  # planlegges. Det skjer i første PR, før noe er rullet ut. Med azurerm-
  # backend er en state-fil som ikke finnes, et tomt objekt uten outputs. Ved
  # apply kjøres stacken den leser fra, først, så der er det en ekte feil.
  if [ "$HANDLING" = plan ] && [ $kode -eq 1 ] &&
     grep -qE "Unable to find remote state|is object with no attributes" plan.txt; then
    kode=3
  fi

  sammendrag="$(grep -E '^(Plan:|No changes|Apply complete)' plan.txt | head -2 | tr '\n' ' ')"
  case $kode in
    0) ikon="✅" ;;
    2) ikon="🟡"; [ $resultat -eq 0 ] && resultat=2 ;;
    3) ikon="⏳"; [ $resultat -eq 0 ] && resultat=2
       sammendrag="kan ikke planlegges ennå: leser state fra en stack som ikke er rullet ut i $MILJO. Planen for denne stacken er IKKE sjekket" ;;
    *) ikon="❌"; resultat=1; sammendrag="feilet – se loggen" ;;
  esac

  {
    echo "### $ikon $navn – ${sammendrag:-ingen oppsummering}"
    echo
    echo "<details><summary>Hele utskriften</summary>"
    echo
    echo '```text'
    cat plan.txt
    echo '```'
    echo
    echo "</details>"
    echo
  } >> "$RAPPORT"

  rm -f init.log plan.txt
  [ "$HANDLING" = apply ] && [ $kode -ne 0 ] && break
done

exit $resultat
