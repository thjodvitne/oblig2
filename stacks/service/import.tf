# MIDLERTIDIG: flytter tjenestens ressurser hit fra network, data og app.
# De gamle stackene har removed med destroy = false for de samme ressursene.
# Slettes i opprydnings-PR-en (K8).
#
# ID-ene bygges av ID-ene shared-network gir ut, så ingen abonnements-ID
# står i koden (K5).

# --- fra network ---------------------------------------------------------

import {
  to = module.subnet.azurerm_subnet.this
  id = "${local.nett.vnet_id}/subnets/snet-${var.tjeneste}"
}

import {
  to = module.subnet.azurerm_network_security_group.this
  id = "${local.nett.resource_group_id}/providers/Microsoft.Network/networkSecurityGroups/nsg-${var.tjeneste}"
}

import {
  to = module.subnet.azurerm_network_security_rule.http
  id = "${local.nett.resource_group_id}/providers/Microsoft.Network/networkSecurityGroups/nsg-${var.tjeneste}/securityRules/allow-http"
}

# Lett å glemme: koblingen er en egen ressurs. Import-ID-en er subnettets ID.
import {
  to = module.subnet.azurerm_subnet_network_security_group_association.this
  id = "${local.nett.vnet_id}/subnets/snet-${var.tjeneste}"
}

# --- fra data ------------------------------------------------------------

import {
  to = module.storage.azurerm_storage_account.this
  id = "${local.nett.resource_group_id}/providers/Microsoft.Storage/storageAccounts/st${var.kortnavn}${var.tjeneste}${var.miljo}"
}

import {
  to = module.keyvault.azurerm_key_vault.this
  id = "${local.nett.resource_group_id}/providers/Microsoft.KeyVault/vaults/kv-${var.kortnavn}-${var.tjeneste}-${var.miljo}"
}

# --- fra app: VM (bare når runtime = vm) --------------------------------

import {
  for_each = local.vm
  to       = module.vm[each.key].azurerm_public_ip.this
  id       = "${local.nett.resource_group_id}/providers/Microsoft.Network/publicIPAddresses/pip-${each.key}"
}

import {
  for_each = local.vm
  to       = module.vm[each.key].azurerm_network_interface.this
  id       = "${local.nett.resource_group_id}/providers/Microsoft.Network/networkInterfaces/nic-${each.key}"
}

import {
  for_each = local.vm
  to       = module.vm[each.key].azurerm_linux_virtual_machine.this
  id       = "${local.nett.resource_group_id}/providers/Microsoft.Compute/virtualMachines/vm-${each.key}"
}

# --- fra app: web app (bare når runtime = webapp) ----------------------

import {
  for_each = local.webapp
  to       = module.webapp[each.key].azurerm_service_plan.this
  id       = "${local.nett.resource_group_id}/providers/Microsoft.Web/serverFarms/asp-${each.key}"
}

import {
  for_each = local.webapp
  to       = module.webapp[each.key].azurerm_linux_web_app.this
  id       = "${local.nett.resource_group_id}/providers/Microsoft.Web/sites/app-${var.kortnavn}-${each.key}-${var.miljo}"
}
