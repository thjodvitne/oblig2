variable "service" {
  description = "Tjenestenavnet. Brukes i navnet på subnettet og NSG-en."
  type        = string
}

variable "resource_group_name" {
  description = "Ressursgruppa VNet-et står i."
  type        = string
}

variable "location" {
  description = "Azure-regionen."
  type        = string
}

variable "vnet_name" {
  description = "VNet-et subnettet skal ligge i."
  type        = string
}

variable "prefix" {
  description = "Adresseområdet til subnettet, f.eks. 10.10.0.0/24. Må ligge innenfor adresserommet til VNet-et."
  type        = string
}

variable "delegate_web" {
  description = "true hvis subnettet skal delegeres til App Service (for en web app med VNet-integrasjon)."
  type        = bool
  default     = false
}

variable "allow_http_from" {
  description = "Hvem som får nå tjenesten på port 80, som CIDR eller service tag (f.eks. Internet)."
  type        = string
}

variable "tags" {
  description = "Tagger på NSG-en."
  type        = map(string)
  default     = {}
}
