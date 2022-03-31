packer {
  required_plugins {
    azure-rm = {
      version = ">= 1.0.6"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "client_id" {
  type        = string
  description = "Specifies the service principal client-id"
}

variable "client_secret" {
  type        = string
  description = "Specifies the service principal secret"
  sensitive   = true
}

variable "tenant_id" {
  type        = string
  description = "Specifies the Azure tenant id"
}

variable "subscription_id" {
  type        = string
  description = "Specifies the Azure subscription id where image should be saved"
  sensitive   = true
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Specifies in what region the image(s) is saved"
}

variable "resource_group_name" {
  type        = string
  description = "Specifies the resource group name used where image is saved"
}

variable "env" {
  type        = string
  description = "Specifies the lifecycle notation used in image name"

  validation {
    condition     = can(regex("dev|test|qa|prod|uat|lab", var.env))
    error_message = "The env variable does not match regex."
  }
}

locals {
  location_abbreviations = {
    "westeurope"  = "weeu",
    "northeurope" = "noeu",
    "westus"      = "weus",
    "westus"      = "weus"
  }
}

# source block configures a specific builder plugin, which is then invoked by a build block.
source "azure-arm" "agent-ubuntu-webtier" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  managed_image_resource_group_name = var.resource_group_name
  managed_image_name                = "demo-web-${local.location_abbreviations[var.location]}-${var.env}-001"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts-gen2"

  location = var.location
  vm_size  = "Standard_B1s"
}

source "azure-arm" "agent-ubuntu-business-tier-001" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  managed_image_resource_group_name = var.resource_group_name
  managed_image_name                = "demo-bt-${local.location_abbreviations[var.location]}-${var.env}-001"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts-gen2"

  location = var.location
  vm_size  = "Standard_B1s"
}

source "azure-arm" "agent-ubuntu-business-tier-002" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  managed_image_resource_group_name = var.resource_group_name
  managed_image_name                = "demo-bt-${local.location_abbreviations[var.location]}-${var.env}-002"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts-gen2"

  location = var.location
  vm_size  = "Standard_B1s"
}

# The build block defines what Packer should do with the Docker container after it launches.
build {
  name = "learn-packer"
  sources = [
    "source.azure-arm.agent-ubuntu-webtier",
    "source.azure-arm.agent-ubuntu-business-tier-001",
    "source.azure-arm.agent-ubuntu-business-tier-002",
  ]

    provisioner "file" {
        source = "../files/web_tier/index.html"
        destination = "/tmp/index.html"
        only = [
          "azure-arm.agent-ubuntu-webtier"
        ]
    }
    
    provisioner "file" {
        source = "../files/business_tier_001/index.html"
        destination = "/tmp/index.html"
        only = [
          "azure-arm.agent-ubuntu-business-tier-001"
        ]
    }

    provisioner "file" {
        source = "../files/business_tier_002/index.html"
        destination = "/tmp/index.html"
        only = [
          "azure-arm.agent-ubuntu-business-tier-002"
        ]
    }

    provisioner "shell" {
      execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
      inline_shebang = "/bin/sh -x"
      inline = [
        "apt-get update",
        "apt-get upgrade -y",
        "apt-get -y install nginx",
        "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync",
        "mv -v /tmp/index.html /var/www/html"
      ]
    }
}

