output "id" {
  description = "Ressurs-ID-en til VNet-et."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Navnet på VNet-et."
  value       = azurerm_virtual_network.this.name
}
