resource "azurerm_service_plan" "this" {
  #checkov:skip=CKV_AZURE_211:B1 er bevisst. Det er den minste SKU-en med VNet-integrasjon
  #checkov:skip=CKV_AZURE_212:Én instans holder. Flere koster mer og gir ingenting her
  #checkov:skip=CKV_AZURE_225:Soneredundans krever Premium
  name                = "asp-${var.service}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.sku
  tags                = var.tags
}

# Navnet blir en del av adressen (<navn>.azurewebsites.net) og må være
# globalt unikt.
# tflint-ignore: azurerm_app_service_missing_auto_heal_setting # Appen har ingen kode å starte på nytt
resource "azurerm_linux_web_app" "this" {
  #checkov:skip=CKV_AZURE_13:Appen har ikke noe innhold som krever innlogging
  #checkov:skip=CKV_AZURE_16:Appen kaller ingen andre tjenester, så den trenger ingen identitet
  #checkov:skip=CKV_AZURE_71:Appen kaller ingen andre tjenester, så den trenger ingen identitet
  #checkov:skip=CKV_AZURE_17:Klientsertifikater ville stengt ute nettleseren
  #checkov:skip=CKV_AZURE_63:Logging er utenfor oppgaven
  #checkov:skip=CKV_AZURE_65:Logging er utenfor oppgaven
  #checkov:skip=CKV_AZURE_66:Logging er utenfor oppgaven
  #checkov:skip=CKV_AZURE_88:Appen lagrer ingenting
  #checkov:skip=CKV_AZURE_213:Appen har ingen kode å helsesjekke
  #checkov:skip=CKV_AZURE_222:Appen skal være åpen
  name                = "app-${var.kortnavn}-${var.service}-${var.miljo}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true

  # VNet-integrasjon: utgående trafikk fra appen går gjennom dette subnettet.
  # Subnettet må være delegert til App Service (se modules/subnet).
  virtual_network_subnet_id = var.subnet_id

  site_config {
    ftps_state    = "Disabled"
    http2_enabled = true

    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    TJENESTE = var.service
  }

  tags = var.tags
}
