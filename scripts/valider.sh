#!/usr/bin/env bash
# =============================================================================
#  scripts/valider.sh  –  porten: fmt, validate, TFLint og Checkov
# -----------------------------------------------------------------------------
#  Samme skript lokalt og i CI (jobben «kodekontroll» i ci.yml):
#
#      bash scripts/valider.sh
#
#  Trenger ingen tilgang til Azure. Kjører alle kontrollene selv om en tidlig
#  feiler, så du ser alle funnene på én gang. Reglene står i .tflint.hcl og
#  .checkov.yaml, ikke her. Alle mappene under stacks/ valideres.
# =============================================================================

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

feilet=""

kontroll() {
  echo
  echo "=== $1 ==="
}

kontroll "1/4 terraform fmt"
if ! terraform fmt -check -recursive; then
  echo "→ Rett med: terraform fmt -recursive"
  feilet="$feilet fmt"
fi

kontroll "2/4 terraform validate"
for mappe in stacks/*/; do
  stack="$(basename "$mappe")"
  echo "--- $stack"
  if ! (cd "$mappe" &&
        terraform init -backend=false -input=false > /dev/null &&
        terraform validate -no-color); then
    feilet="$feilet validate($stack)"
  fi
done

kontroll "3/4 TFLint"
tflint --init > /dev/null
if ! tflint --recursive --config "$(pwd)/.tflint.hcl"; then
  feilet="$feilet tflint"
fi

kontroll "4/4 Checkov"
if ! checkov -d . --config-file .checkov.yaml; then
  feilet="$feilet checkov"
fi

echo
if [ -z "$feilet" ]; then
  echo "✅ Alle kontrollene er grønne."
  exit 0
else
  echo "❌ Feilet:$feilet"
  exit 1
fi
