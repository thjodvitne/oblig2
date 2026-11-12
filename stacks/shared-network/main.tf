# Det tjenestene faktisk deler: ressursgruppa og VNet-et. Subnettene eies av
# hver sin instans av stacks/service.

locals {
  rg_navn   = "rg-${var.kortnavn}-oblig2-${var.miljo}"
  vnet_navn = "vnet-${var.kortnavn}-${var.miljo}"

  tags = {
    eier  = var.kortnavn
    miljo = var.miljo
    kurs  = "dcst3005-oblig2"
  }
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_navn
  location = var.location
  tags     = local.tags
}

module "vnet" {
  source              = "../../modules/vnet"
  name                = local.vnet_navn
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = var.address_space
  tags                = local.tags
}
