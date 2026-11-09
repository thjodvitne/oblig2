variable "kortnavn" {
  description = "Kortnavnet ditt. Settes i config/felles.tfvars."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.kortnavn))
    error_message = "kortnavn må være 2–10 små bokstaver eller tall. Sett det i config/felles.tfvars."
  }
}

variable "location" {
  description = "Azure-regionen. Settes i config/felles.tfvars."
  type        = string
}

variable "miljo" {
  description = "Miljøet. Settes av scripts/kjor.sh (TF_VAR_miljo), ikke i en .tfvars-fil."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.miljo)
    error_message = "miljo må være dev eller prod."
  }
}

variable "state_resource_group_name" {
  description = "Ressursgruppa til state-kontoen. Settes av scripts/kjor.sh fra shared/backend.hcl."
  type        = string
}

variable "state_storage_account_name" {
  description = "State-kontoen. Settes av scripts/kjor.sh fra shared/backend.hcl."
  type        = string
}

variable "state_container_name" {
  description = "Containeren state ligger i. Settes av scripts/kjor.sh fra shared/backend.hcl."
  type        = string
}

variable "tjenester" {
  description = "Tjenestene som skal ha en storage account og et Key Vault."
  type        = set(string)
}
