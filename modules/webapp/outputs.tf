output "hostname" {
  description = "Adressen til appen."
  value       = azurerm_linux_web_app.this.default_hostname
}

output "app_id" {
  description = "Ressurs-ID-en til appen."
  value       = azurerm_linux_web_app.this.id
}
