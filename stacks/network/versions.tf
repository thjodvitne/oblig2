terraform {
  required_version = ">= 1.16.0"

  # Tom med vilje. Adressen kommer fra shared/backend.hcl, og key fra
  # scripts/kjor.sh: oblig2/<miljø>/<navn på config-fila>.tfstate
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.4"
    }
  }
}

# Abonnementet kommer fra ARM_SUBSCRIPTION_ID, ikke fra koden.
provider "azurerm" {
  features {}
}
