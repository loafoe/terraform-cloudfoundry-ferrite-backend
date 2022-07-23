terraform {
  required_version = ">= 0.13.0"

  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry-community/cloudfoundry"
      version = ">= 0.14.1"
    }
    hsdp = {
      source  = "philips-software/hsdp"
      version = ">= 0.15.0"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = ">= 2.1.0"
    }

    random = {
      source  = "random"
      version = ">= 2.2.1"
    }
  }
}
