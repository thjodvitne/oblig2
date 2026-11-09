variable "service" {
  description = "Tjenestenavnet. Brukes i navnet på planen og appen."
  type        = string
}

variable "kortnavn" {
  description = "Kortnavnet ditt. Går inn i navnet på appen, som må være globalt unikt."
  type        = string
}

variable "miljo" {
  description = "Miljøet (dev eller prod). Går inn i navnet på appen."
  type        = string
}

variable "resource_group_name" {
  description = "Ressursgruppa appen står i."
  type        = string
}

variable "location" {
  description = "Azure-regionen. Må være den samme som VNet-et, ellers virker ikke VNet-integrasjonen."
  type        = string
}

variable "subnet_id" {
  description = "Subnettet appen integreres med. Må være delegert til Microsoft.Web/serverFarms."
  type        = string
}

variable "sku" {
  description = "SKU-en til App Service-planen."
  type        = string
  default     = "B1"
}

variable "tags" {
  description = "Tagger på planen og appen."
  type        = map(string)
  default     = {}
}
