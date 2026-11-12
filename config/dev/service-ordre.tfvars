tjeneste = "ordre"
runtime  = "vm"
prefix   = "10.10.0.0/24"

# Offentlig nøkkel uten privat nøkkel. Ikke hemmelig.
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMQ32gu8mGVI86gkUex5JsBeg7WC58bsUOVuxmeHDJW oblig2-ingen-privat-nokkel"

# EO 1: TCP 8110 fra 172.16.91.0/24, bare for ordre.
ekstra_innkommende = {
  "allow-tcp-8110" = { port = 8110, kilde = "172.16.91.0/24", prioritet = 110 }
}
