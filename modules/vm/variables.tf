variable "service" {
  description = "Tjenestenavnet. Brukes i navnet på VM-en, NIC-en og den offentlige IP-en."
  type        = string
}

variable "resource_group_name" {
  description = "Ressursgruppa VM-en står i."
  type        = string
}

variable "location" {
  description = "Azure-regionen."
  type        = string
}

variable "subnet_id" {
  description = "Subnettet NIC-en kobles til."
  type        = string
}

variable "size" {
  description = "VM-størrelsen."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "ssh_public_key" {
  description = "Den OFFENTLIGE SSH-nøkkelen (innholdet i .pub-fila). Ikke hemmelig. Den private nøkkelen skal aldri i repoet."
  type        = string
}

variable "tags" {
  description = "Tagger på ressursene."
  type        = map(string)
  default     = {}
}
