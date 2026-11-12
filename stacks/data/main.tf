# Tømt under migreringen. Storage account og Key Vault eies nå av hver
# sin instans av service. Stacken slettes i opprydnings-PR-en.

removed {
  from = module.storage

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.keyvault

  lifecycle {
    destroy = false
  }
}
