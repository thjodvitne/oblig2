resource "azurerm_public_ip" "this" {
  name                = "pip-${var.service}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  #checkov:skip=CKV_AZURE_119:Offentlig IP er bevisst, så du kan se boot-id-en i nettleseren
  name                = "nic-${var.service}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "vm-${var.service}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.this.id]

  # Ingen VM-utvidelser. Alt oppsett skjer med cloud-init under.
  allow_extension_operations = false

  # Ved første oppstart installerer cloud-init nginx og skriver en tilfeldig
  # boot-id på forsiden. Den endres bare hvis VM-en bygges på nytt: samme
  # boot-id i nettleseren betyr samme VM.
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    packages: [nginx]
    runcmd:
      - echo "<h1>${var.service}</h1><p>boot-id $(cat /proc/sys/kernel/random/uuid)</p>" > /var/www/html/index.html
    CLOUDINIT
  )

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # custom_data brukes bare ved første oppstart, og Azure gir den aldri
  # tilbake. Terraform kan derfor ikke se om den er endret. Uten linja under
  # tolker Terraform en state uten custom_data som en endring, og bygger VM-en
  # på nytt. Se modul 8 side 8.
  lifecycle {
    ignore_changes = [custom_data]
  }

  tags = var.tags
}
