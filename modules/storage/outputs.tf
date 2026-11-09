output "id" {
  description = "Ressurs-ID-en til storage account-en."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Navnet på storage account-en."
  value       = azurerm_storage_account.this.name
}
