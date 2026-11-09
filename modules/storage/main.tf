# Navnet må være globalt unikt, maks 24 tegn, og bare små bokstaver og tall.
# Det bygges av kortnavnet, tjenesten og miljøet, så det er det samme hver gang:
# ingen tilfeldig hale.
resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV_AZURE_33:Ingen køer i bruk, så det er ingenting å logge
  #checkov:skip=CKV_AZURE_59:Offentlig endepunkt trengs for at workflowen skal nå kontoen
  #checkov:skip=CKV_AZURE_206:LRS er bevisst. Geo-replikering koster mer og gir ingenting her
  #checkov:skip=CKV2_AZURE_1:Microsoft-styrte nøkler holder. Kundestyrte nøkler krever et eget oppsett
  #checkov:skip=CKV2_AZURE_33:Private endpoint krever privat DNS og koster per time
  #checkov:skip=CKV2_AZURE_38:Kontoen har ingen data som trenger soft-delete
  #checkov:skip=CKV2_AZURE_40:azurerm leser kontoen med delt nøkkel. Uten den må SP-en ha egne dataplanroller
  #checkov:skip=CKV2_AZURE_41:Ingen SAS-tokens utstedes
  name                     = "st${var.kortnavn}${var.service}${var.miljo}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Et sikkerhetsnett: Terraform nekter å slette kontoen, også når en endring
  # ville erstattet den. Gjelder ikke sletting utenom Terraform (portalen,
  # az group delete eller nattjobben).
  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}
