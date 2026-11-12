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

variable "tjeneste" {
  description = "Navnet på tjenesten denne instansen av stacken er. Går inn i alle ressursnavnene."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.tjeneste))
    error_message = "tjeneste må være 2–10 små bokstaver eller tall."
  }
}

variable "runtime" {
  description = "Kjøremiljøet: \"vm\" gir en Linux-VM med offentlig IP, \"webapp\" en App Service-plan og en web app med VNet-integrasjon."
  type        = string

  validation {
    condition     = contains(["vm", "webapp"], var.runtime)
    error_message = "runtime må være vm eller webapp."
  }
}

variable "prefix" {
  description = "Adresseområdet til tjenestens subnett. Må ligge innenfor VNet-ets adresserom."
  type        = string
}

variable "allow_http_from" {
  description = "Hvem som får nå tjenesten på port 80."
  type        = string
  default     = "Internet"
}

variable "vm_size" {
  description = "VM-størrelsen når runtime er vm."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "ssh_public_key" {
  description = "Offentlig SSH-nøkkel til VM-en. Ikke hemmelig. Trengs bare når runtime er vm."
  type        = string
  default     = null

  validation {
    condition     = var.runtime != "vm" || var.ssh_public_key != null
    error_message = "ssh_public_key må settes når runtime er vm."
  }
}

variable "webapp_sku" {
  description = "SKU for App Service-planen når runtime er webapp."
  type        = string
  default     = "B1"
}
