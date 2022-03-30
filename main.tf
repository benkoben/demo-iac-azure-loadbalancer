locals {
  web_tier_count = 2
  web_tier_admin_username = "demouser"
  web_tier_subnet = "10.100.0.0/24"
  business_tier_subnet="10.200.0.0/24"
  location_abbreviation = {
    westeurope  = "weeu"
    northeurope = "noeu"
  }
}

data "azurerm_resource_group" "guld" {
  name = "General_Ben"
}

# --- Networking
resource "azurerm_virtual_network" "demo_vnet" {
  name                = "demo-vnet-${var.env}-${local.location_abbreviation[var.location]}-001"
  resource_group_name = data.azurerm_resource_group.guld.name
  location            = data.azurerm_resource_group.guld.location
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "web_tier" {
  name                 = "web-tier"
  resource_group_name  = data.azurerm_resource_group.guld.name
  virtual_network_name = azurerm_virtual_network.demo_vnet.name
  address_prefixes     = [local.web_tier_subnet]
}

resource "azurerm_subnet" "business_tier" {
  name                 = "business-tier"
  resource_group_name  = data.azurerm_resource_group.guld.name
  virtual_network_name = azurerm_virtual_network.demo_vnet.name
  address_prefixes     = [local.business_tier_subnet]
}

# --- Public Load Balancer
resource "azurerm_public_ip" "external_lb" {
  name                = "demo-extlbpip-${var.env}-${local.location_abbreviation[var.location]}-001"
  location            = data.azurerm_resource_group.guld.location
  resource_group_name = data.azurerm_resource_group.guld.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "external" {
  name                = "demo-extlb-${var.env}-${local.location_abbreviation[var.location]}-001"
  location            = data.azurerm_resource_group.guld.location
  resource_group_name = data.azurerm_resource_group.guld.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.external_lb.id
  }
}

# --- Web tier
resource "azurerm_linux_virtual_machine_scale_set" "web_tier" {
  name                = "demo-webtier-${var.env}-${local.location_abbreviation[var.location]}-001"
  resource_group_name = data.azurerm_resource_group.guld.name
  location            = data.azurerm_resource_group.guld.location
  sku                 = "Standard_B1s"
  instances           = local.web_tier_count
  admin_username      = local.web_tier_admin_username

  admin_ssh_key {
    username   = local.web_tier_admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "internal"
    primary = true

    ip_configuration {
      name      = "ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.web_tier.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_tier.id]
    }
  }
}

resource "azurerm_lb_backend_address_pool" "web_tier" {
  loadbalancer_id = azurerm_lb.external.id
  name            = "WebTierBackendPool"
}

resource "azurerm_lb_probe" "web_tier_lbp" {
  name                = lower("lb-probe-port-80-${azurerm_linux_virtual_machine_scale_set.web_tier.name}")
  loadbalancer_id     = azurerm_lb.external.id
  port                = 80
  protocol            = "Tcp"
  number_of_probes    = 1
}

resource "azurerm_lb_rule" "lbrule" {
  name                           = format("%s-%02d-rule", azurerm_linux_virtual_machine_scale_set.web_tier.name, 1)
  loadbalancer_id                = azurerm_lb.external.id
  probe_id                       = azurerm_lb_probe.web_tier_lbp.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.external.frontend_ip_configuration.0.name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_tier.id]
}

// # Internal Load balancer
// resource "azurerm_lb" "internal" {
//   name                = "demo-intlb-${var.env}-${local.location_abbreviation[var.env]}-001"
//   location            = azurerm_resource_group.guld.location
//   resource_group_name = azurerm_resource_group.guld.name

//   frontend_ip_configuration {
//     name                 = "PublicIPAddress"
//     public_ip_address_id = azurerm_public_ip.external_lb.id
//   }
// }
