output "id" {
  description = "Ressurs-ID-en til hvelvet."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Navnet på hvelvet."
  value       = azurerm_key_vault.this.name
}
