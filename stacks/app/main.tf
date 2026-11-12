# Tømt under migreringen. VM-en og web app-en eies nå av hver sin instans
# av service. Stacken slettes i opprydnings-PR-en.

removed {
  from = module.vm

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.webapp

  lifecycle {
    destroy = false
  }
}
