# MIDLERTIDIG: flytter ressursgruppa og VNet-et hit fra network-stacken.
# network har removed med destroy = false for de samme ressursene.
# Slettes i opprydnings-PR-en (K8).
#
# ID-ene bygges, de skrives ikke av (K5): abonnementet kommer fra
# data-kilden, ikke fra koden.

# tflint-ignore: terraform_unused_declarations # Brukes bare av import-blokkene under
data "azurerm_subscription" "current" {}

import {
  to = azurerm_resource_group.this
  id = "${data.azurerm_subscription.current.id}/resourceGroups/${local.rg_navn}"
}

import {
  to = module.vnet.azurerm_virtual_network.this
  id = "${data.azurerm_subscription.current.id}/resourceGroups/${local.rg_navn}/providers/Microsoft.Network/virtualNetworks/${local.vnet_navn}"
}
