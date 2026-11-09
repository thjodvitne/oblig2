# Navnet er maks 24 tegn og bygges uten tilfeldig hale, som storage account-en.
#
# Når ressursgruppa slettes (av reset.sh eller nattjobben), blir hvelvet ikke
# borte. Det ligger i soft-delete i 7 dager, og navnet er opptatt så lenge.
# azurerm tar det tilbake av seg selv neste gang du ruller ut med samme navn,
# så du merker ingenting. Står det «already exists» i en feilmelding, er det
# dette det handler om.
resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV_AZURE_42:Krever purge protection, se under
  #checkov:skip=CKV_AZURE_110:Bevisst avvik, se kommentaren ved purge_protection_enabled
  #checkov:skip=CKV_AZURE_109:Brannmur ville stengt ute workflowen, som kjører fra skiftende IP-er
  #checkov:skip=CKV_AZURE_189:Offentlig endepunkt trengs for at workflowen skal nå hvelvet
  #checkov:skip=CKV2_AZURE_32:Private endpoint krever privat DNS og koster per time
  name                       = "kv-${var.kortnavn}-${var.service}-${var.miljo}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7

  # Med purge protection kan ingen slette hvelvet for godt før de 7 dagene er
  # gått. Riktig i produksjon, men feil her: du skal kunne rydde opp etter deg.
  purge_protection_enabled = false

  # Et sikkerhetsnett: Terraform nekter å slette hvelvet, også når en endring
  # ville erstattet det. Gjelder ikke sletting utenom Terraform.
  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}
