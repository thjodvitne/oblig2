# Tømt under migreringen. Alt som sto her, eies nå av shared-network eller
# service. Stacken slettes i opprydnings-PR-en.

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

removed {
  from = module.subnet

  lifecycle {
    destroy = false
  }
}
