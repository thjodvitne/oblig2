# Adressen til state-lagringen, felles for alle stackene og begge miljøene.
# key settes per stack og miljø av scripts/kjor.sh.
#
# Bruk den samme state-kontoen som i oblig 1: kopier verdiene fra
# shared/backend.hcl i oblig 1-repoet ditt. State for oblig 2 havner under
# oblig2/ i containeren, så den blander seg ikke med oblig 1.

resource_group_name  = "rg-jml-tfstate"
storage_account_name = "stjmltfstate9843"
container_name       = "tfstate"
use_azuread_auth     = true
