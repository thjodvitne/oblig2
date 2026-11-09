address_space = ["10.20.0.0/23"]

tjenester = {
  ordre = { prefix = "10.20.0.0/24", runtime = "vm" }
  meny  = { prefix = "10.20.1.0/24", runtime = "webapp" }
}
