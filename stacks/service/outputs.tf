output "vm_public_ips" {
  description = "Offentlig IP hvis tjenesten kjører på en VM. Åpne http://<ip> for å se boot-id-en."
  value       = { for navn, v in module.vm : navn => v.public_ip }
}

output "webapp_hostnames" {
  description = "Adressen hvis tjenesten kjører på en web app."
  value       = { for navn, w in module.webapp : navn => w.hostname }
}

output "subnet_id" {
  description = "Subnettet til tjenesten."
  value       = module.subnet.subnet_id
}

output "storage_account_name" {
  description = "Storage account-en til tjenesten."
  value       = module.storage.name
}

output "key_vault_name" {
  description = "Key Vault-et til tjenesten."
  value       = module.keyvault.name
}
