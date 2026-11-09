# Applaget for ALLE tjenestene: en VM eller en web app per tjeneste, koblet til
# subnettet som network-stacken har laget for den.

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

module "vm" {
  source   = "../../modules/vm"
  for_each = { for navn, runtime in var.tjenester : navn => runtime if runtime == "vm" }

  service             = each.key
  resource_group_name = local.network.resource_group_name
  location            = var.location
  subnet_id           = local.network.subnet_ids[each.key]
  size                = var.vm_size
  ssh_public_key      = var.ssh_public_key
  tags                = local.tags
}

module "webapp" {
  source   = "../../modules/webapp"
  for_each = { for navn, runtime in var.tjenester : navn => runtime if runtime == "webapp" }

  service             = each.key
  kortnavn            = var.kortnavn
  miljo               = var.miljo
  resource_group_name = local.network.resource_group_name
  location            = var.location
  subnet_id           = local.network.subnet_ids[each.key]
  sku                 = var.webapp_sku
  tags                = local.tags
}
