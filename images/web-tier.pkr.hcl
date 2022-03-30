packer {
  required_plugins {
    azure-rm = {
      version = ">= 1.0.6"
      source  = "github.com/hashicorp/azure"
    }
  }
}


// variable "resource_group_name" {
//   type        = string
//   description = "Specifies the resource group name used where image is saved"
// }

// variable "env" {
//   type        = string
//   description = "Specifies the lifecycle notation used in image name"

//   validation {
//     condition     = can(regex("dev|test|qa|prod|uat|lab", var.env))
//     error_message = "The env variable does not match regex."
//   }
// }

locals {
  location_abbreviations = {
    "westeurope"  = "weeu",
    "northeurope" = "noeu",
    "westus"      = "weus",
    "westus"      = "weus"
  }
}

# source block configures a specific builder plugin, which is then invoked by a build block.
source "azure-arm" "agent-ubuntu" {
//   client_id       = var.client_id
//   client_secret   = var.client_secret
//   tenant_id       = var.tenant_id
//   subscription_id = var.subscription_id

  managed_image_resource_group_name = "General_Ben"
  managed_image_name                = "demo-webtier-weeu-dev-001"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer"
  image_sku       = "18.04-LTS"

  location = "West Europe"
  vm_size  = "Standard_B1s"
}

# The build block defines what Packer should do with the Docker container after it launches.
build {
  name = "learn-packer"
  sources = [
    "source.azure-arm.agent-ubuntu"
  ]

    provisioner "file" {
        source = "../files/web_tier/index.html"
        destination = "/usr/share/nginx/www"
    }
}

