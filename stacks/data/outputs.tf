output "storage_account_names" {
  description = "Storage account per tjeneste."
  value       = { for navn, s in module.storage : navn => s.name }
}

output "key_vault_names" {
  description = "Key Vault per tjeneste."
  value       = { for navn, k in module.keyvault : navn => k.name }
}
