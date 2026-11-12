# Nettverkslaget for ALLE tjenestene. Under migrering: ressursgruppa og VNet-et
# er flyttet til stacks/shared-network. Bare subnettene står igjen her.

locals {
  # Navnene, ikke ressursene: de eies nå av shared-network.
  rg_navn   = "rg-${var.kortnavn}-oblig2-${var.miljo}"
  vnet_navn = "vnet-${var.kortnavn}-${var.miljo}"

  tags = {
    eier  = var.kortnavn
    miljo = var.miljo
    kurs  = "dcst3005-oblig2"
  }
}

# Flyttet til shared-network. Glem dem her, uten å slette dem i Azure.
removed {
  from = azurerm_resource_group.this

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.vnet

  lifecycle {
    destroy = false
  }
}

module "subnet" {
  source   = "../../modules/subnet"
  for_each = var.tjenester

  service             = each.key
  resource_group_name = local.rg_navn
  location            = var.location
  vnet_name           = local.vnet_navn
  prefix              = each.value.prefix
  delegate_web        = each.value.runtime == "webapp"
  allow_http_from     = var.allow_http_from
  tags                = local.tags
}
