terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.9.0"
    }
    powerstore = {
      source  = "dell/powerstore"
      version = ">= 1.2.0"
    }
  }
}
