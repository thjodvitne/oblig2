variable "service" {
  description = "Tjenestenavnet. Går inn i navnet på hvelvet."
  type        = string
}

variable "kortnavn" {
  description = "Kortnavnet ditt. Går inn i navnet på hvelvet."
  type        = string
}

variable "miljo" {
  description = "Miljøet (dev eller prod). Går inn i navnet på hvelvet."
  type        = string
}

variable "resource_group_name" {
  description = "Ressursgruppa hvelvet står i."
  type        = string
}

variable "location" {
  description = "Azure-regionen."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID-tenanten hvelvet hører til."
  type        = string
}

variable "tags" {
  description = "Tagger på hvelvet."
  type        = map(string)
  default     = {}
}
