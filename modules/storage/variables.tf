variable "service" {
  description = "Tjenestenavnet. Går inn i navnet på kontoen."
  type        = string
}

variable "kortnavn" {
  description = "Kortnavnet ditt. Går inn i navnet på kontoen."
  type        = string
}

variable "miljo" {
  description = "Miljøet (dev eller prod). Går inn i navnet på kontoen."
  type        = string
}

variable "resource_group_name" {
  description = "Ressursgruppa kontoen står i."
  type        = string
}

variable "location" {
  description = "Azure-regionen."
  type        = string
}

variable "tags" {
  description = "Tagger på kontoen."
  type        = map(string)
  default     = {}
}
