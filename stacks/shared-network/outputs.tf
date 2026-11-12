output "resource_group_name" {
  description = "Ressursgruppa alle tjenestene står i."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Ressurs-ID-en til ressursgruppa. Service-stacken bygger import-ID-ene sine fra den."
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "Regionen alt står i."
  value       = azurerm_resource_group.this.location
}

output "vnet_name" {
  description = "Navnet på VNet-et."
  value       = module.vnet.name
}

output "vnet_id" {
  description = "Ressurs-ID-en til VNet-et."
  value       = module.vnet.id
}
