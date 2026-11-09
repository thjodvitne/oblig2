output "public_ip" {
  description = "Den offentlige IP-adressen. Åpne http://<ip> for å se boot-id-en."
  value       = azurerm_public_ip.this.ip_address
}

output "vm_id" {
  description = "Ressurs-ID-en til VM-en."
  value       = azurerm_linux_virtual_machine.this.id
}
