# Datalaget for ALLE tjenestene: én storage account og ett Key Vault per
# tjeneste. Ressursgruppa eies av network-stacken.

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = "oblig2/${var.miljo}/network.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  network = data.terraform_remote_state.network.outputs

  tags = {
    eier  = var.kortnavn
    miljo = var.miljo
    kurs  = "dcst3005-oblig2"
  }
}

module "storage" {
  source   = "../../modules/storage"
  for_each = var.tjenester

  service             = each.key
  kortnavn            = var.kortnavn
  miljo               = var.miljo
  resource_group_name = local.network.resource_group_name
  location            = var.location
  tags                = local.tags
}

module "keyvault" {
  source   = "../../modules/keyvault"
  for_each = var.tjenester

  service             = each.key
  kortnavn            = var.kortnavn
  miljo               = var.miljo
  resource_group_name = local.network.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags
}
