variable "name" {
  description = "Navnet på VNet-et."
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

variable "address_space" {
  description = "Adresserommet, som en liste med CIDR-blokker. Alle subnettene må ligge innenfor."
  type        = list(string)
}

variable "tags" {
  description = "Tagger på VNet-et."
  type        = map(string)
  default     = {}
}
