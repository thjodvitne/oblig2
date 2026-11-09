# Ett subnett med sin egen NSG. Modulen kalles én gang per tjeneste.
resource "azurerm_subnet" "this" {
  name                 = "snet-${var.service}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.prefix]

  # Et subnett som en web app skal kobles til med VNet-integrasjon, må være
  # delegert til App Service. Da kan ingenting annet stå i det.
  dynamic "delegation" {
    for_each = var.delegate_web ? [1] : []
    content {
      name = "web"
      service_delegation {
        name    = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.service}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "http" {
  #checkov:skip=CKV_AZURE_160:Nettsiden skal være åpen. Bare port 80, og ingen data bak den
  name                        = "allow-http"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = var.allow_http_from
  destination_address_prefix  = "*"
}

# Koblingen mellom subnettet og NSG-en er en egen ressurs, ikke et felt på
# subnettet. Den er lett å overse når du lister hva en stack eier.
resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}
