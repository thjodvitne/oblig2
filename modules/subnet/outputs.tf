output "subnet_id" {
  description = "Ressurs-ID-en til subnettet."
  value       = azurerm_subnet.this.id
}

output "nsg_id" {
  description = "Ressurs-ID-en til NSG-en."
  value       = azurerm_network_security_group.this.id
}

output "nsg_name" {
  description = "Navnet på NSG-en. Brukes av stacken når den legger til egne regler."
  value       = azurerm_network_security_group.this.name
}
