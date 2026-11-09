output "subnet_id" {
  description = "Ressurs-ID-en til subnettet."
  value       = azurerm_subnet.this.id
}

output "nsg_id" {
  description = "Ressurs-ID-en til NSG-en."
  value       = azurerm_network_security_group.this.id
}
