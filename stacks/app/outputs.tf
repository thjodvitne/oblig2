output "vm_public_ips" {
  description = "Offentlig IP per VM-tjeneste. Åpne http://<ip> for å se boot-id-en."
  value       = { for navn, v in module.vm : navn => v.public_ip }
}

output "webapp_hostnames" {
  description = "Adresse per web app-tjeneste."
  value       = { for navn, w in module.webapp : navn => w.hostname }
}
