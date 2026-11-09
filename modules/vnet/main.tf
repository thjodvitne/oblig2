# Bare selve VNet-et. Subnettene er egne ressurser i modules/subnet, ikke
# inline-blokker her: da kan hvert subnett eies av en annen stack enn VNet-et.
resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}
