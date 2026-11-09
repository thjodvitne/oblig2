#!/usr/bin/env bash
# =============================================================================
#  reset.sh  –  tilbake til utgangspunktet
# -----------------------------------------------------------------------------
#  Bruk (fra rota av repoet, med `az login` gjort):
#
#      ./reset.sh
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

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

verdi() {
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}

KORTNAVN="$(verdi config/felles.tfvars kortnavn)"
STATE_RG="$(verdi shared/backend.hcl resource_group_name)"
KONTO="$(verdi shared/backend.hcl storage_account_name)"
CONTAINER="$(verdi shared/backend.hcl container_name)"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Du har endringer som ikke er committet. Commit eller forkast dem først." >&2
  exit 1
fi

FORSTE="$(git rev-list --max-parents=0 HEAD | tail -1)"
GREN="reset-$(date +%Y%m%d-%H%M)"

cat <<EOF

Dette skjer nå:

  1. az group delete:  rg-$KORTNAVN-oblig2-dev og rg-$KORTNAVN-oblig2-prod
  2. Sletter blobene:  $CONTAINER/oblig2/* i $KONTO (ressursgruppe $STATE_RG)
  3. Ny gren:          $GREN, med koden fra $(git log -1 --format='%h %s' "$FORSTE")

Abonnement: $(az account show --query name -o tsv)

EOF
read -r -p "Skriv kortnavnet ditt for å bekrefte: " svar
if [ "$svar" != "$KORTNAVN" ]; then
  echo "Avbrutt. Ingenting er endret."
  exit 1
fi

echo
echo "=== 1/3 Ressursgruppene"
for miljo in dev prod; do
  rg="rg-$KORTNAVN-oblig2-$miljo"
  if [ "$(az group exists -n "$rg")" = "true" ]; then
    echo "Sletter $rg (tar noen minutter) ..."
    az group delete -n "$rg" --yes
  else
    echo "$rg finnes ikke. Hopper over."
  fi
done

echo
echo "=== 2/3 State-filene"
az storage blob delete-batch \
  --account-name "$KONTO" \
  --source "$CONTAINER" \
  --pattern "oblig2/*" \
  --auth-mode login \
  --output none
echo "Blobene under oblig2/ er slettet."

echo
echo "=== 3/3 Koden"
git switch -c "$GREN"
git rm -r -q --ignore-unmatch stacks modules config/dev config/prod scripts .github .oblig2
git checkout "$FORSTE" -- stacks modules config/dev config/prod scripts .github
git commit -q -m "Reset til utgangspunktet"
echo "Commit lagt på $GREN."

cat <<EOF

Ferdig. Videre:

  git push -u origin $GREN
  gh pr create --fill

Merge PR-en. CD dev ruller ut utgangspunktet på nytt. Promoter så til prod.
Ta et nytt øyeblikksbilde (K2) før du begynner på migreringen igjen.

Key Vault-ene ligger i soft-delete i 7 dager. Terraform tar dem tilbake når
du ruller ut på nytt, så du trenger ikke gjøre noe med dem.
EOF
