locals {
  web_tier_count = 2
  web_tier_admin_username = "demouser"
  web_tier_subnet = "10.100.0.0/24"
  business_tier_subnet="10.200.0.0/24"
  business_tier_admin_username = "demouser"
  business_tier_images = [
    var.business_tier_001_source_image_id,
    var.business_tier_002_source_image_id
  ]
  business_tier_probes = [
    "lb-probe-port-80-001",
    "lb-probe-port-80-002",
  ]
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

resource "azurerm_private_dns_zone" "demo" {
  name                = "molnbolagetdemo.com"
  resource_group_name = data.azurerm_resource_group.guld.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "demo" {
  name                  = "molnbolagetdemo"
  resource_group_name   = data.azurerm_resource_group.guld.name
  private_dns_zone_name = azurerm_private_dns_zone.demo.name
  virtual_network_id    = azurerm_virtual_network.demo_vnet.id
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

  tags = var.tags

  admin_ssh_key {
    username   = local.web_tier_admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_id = var.web_tier_source_image_id

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
  name                = lower("lb-probe-port-22-${azurerm_linux_virtual_machine_scale_set.web_tier.name}")
  loadbalancer_id     = azurerm_lb.external.id
  port                = 22
  protocol            = "Tcp"
  number_of_probes    = 1
}

resource "azurerm_lb_rule" "ext_lbrule" {
  name                           = format("%s-%02d-rule", azurerm_linux_virtual_machine_scale_set.web_tier.name, 1)
  loadbalancer_id                = azurerm_lb.external.id
  probe_id                       = azurerm_lb_probe.web_tier_lbp.id
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.external.frontend_ip_configuration.0.name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_tier.id]
}

# --- Business tier
resource "azurerm_lb" "internal" {
  name                = "demo-intlb-${var.env}-${local.location_abbreviation[var.location]}-001"
  location            = data.azurerm_resource_group.guld.location
  resource_group_name = data.azurerm_resource_group.guld.name

  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PrivateIPAddress"
    subnet_id            = azurerm_subnet.business_tier.id
    private_ip_address_version = "IPv4"
    private_ip_address_allocation = "Dynamic"
    
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "business_tier" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "business_tier-001"
}

resource "azurerm_linux_virtual_machine_scale_set" "business_tier" {
  count               = length(local.business_tier_images)
  name                = "demo-bt-${var.env}-${local.location_abbreviation[var.location]}-${count.index}"
  resource_group_name = data.azurerm_resource_group.guld.name
  location            = data.azurerm_resource_group.guld.location
  sku                 = "Standard_B1s"
  instances           = 1
  admin_username      = local.web_tier_admin_username

  tags = var.tags

  zones = [1]

  admin_ssh_key {
    username   = local.web_tier_admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_id = local.business_tier_images[count.index]

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
      subnet_id = azurerm_subnet.business_tier.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.business_tier.id]
    }
  } 
}

resource "azurerm_private_dns_a_record" "business_tier" {
  name                = "business-tier"
  zone_name           = azurerm_private_dns_zone.demo.name
  resource_group_name = data.azurerm_resource_group.guld.name
  # time to live in seconds
  ttl                 = 5
  records             = [azurerm_lb.internal.frontend_ip_configuration.0.private_ip_address]
}

resource "azurerm_lb_probe" "business_tier_lbp" {
  name                = "business-tier-lbp-001"
  loadbalancer_id     = azurerm_lb.internal.id
  port                = 80
  protocol            = "Tcp"
  number_of_probes    = 1
}

resource "azurerm_lb_rule" "int_lbrule" {
  name                           = format("%s-%02d-rule", "business-tier", 1)
  loadbalancer_id                = azurerm_lb.internal.id
  probe_id                       = azurerm_lb_probe.business_tier_lbp.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.internal.frontend_ip_configuration.0.name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.business_tier.id]
}