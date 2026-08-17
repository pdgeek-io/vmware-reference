terraform {
  required_version = ">= 1.6.0"

  required_providers {
    powerstore = {
      source  = "dell/powerstore"
      version = ">= 1.2.0"
    }
  }
}
