terraform {
  required_version = ">= 1.6.0"

  required_providers {
    powerscale = {
      source  = "dell/powerscale"
      version = ">= 1.4.0"
    }
  }
}
