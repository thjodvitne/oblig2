output "resource_group_name" {
  description = "Ressursgruppa alle stackene bruker."
  value       = local.rg_navn
}

output "location" {
  description = "Regionen alt står i."
  value       = var.location
}

output "vnet_name" {
  description = "Navnet på VNet-et."
  value       = local.vnet_navn
}

output "subnet_ids" {
  description = "Subnett-ID per tjeneste."
  value       = { for navn, s in module.subnet : navn => s.subnet_id }
}
