terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  # subscription_id comes from `az login` (or set ARM_SUBSCRIPTION_ID)
}

variable "location" {
  default = "centralindia" # student policies often limit regions; change if deployment is rejected
}

variable "my_ip" {
  description = "Your laptop's public IP, e.g. 49.37.x.x (no /32 needed)"
  type        = string
}

variable "vm_size" {
  default = "Standard_B2s" # if SKU not available in your region, try Standard_B1ms / Standard_D2s_v3
}

variable "admin_username" {
  default = "azureadmin"
}

variable "admin_password" {
  description = "12+ chars, upper/lower/number/symbol"
  type        = string
  sensitive   = true
}

locals {
  vm1_private_ip = "10.0.1.4"
  vm2_private_ip = "10.0.2.4"
}

# ---------- Task 1: Resource group ----------
resource "azurerm_resource_group" "rg" {
  name     = "rg-jumpbox-lab"
  location = var.location
}

# ---------- Task 2: VNet + 2 subnets ----------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-lab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "snet-vm1-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "snet-vm2-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ---------- Task 3: NSGs ----------
resource "azurerm_network_security_group" "nsg1" {
  name                = "nsg-vm1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP-From-MyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg2" {
  name                = "nsg-vm2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH-From-VM1-Only"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${local.vm1_private_ip}/32"
    destination_address_prefix = "*"
  }

  # The default AllowVnetInBound rule (65000) would let anything in the VNet reach VM2.
  # An explicit deny at a lower priority number overrides it.
  security_rule {
    name                       = "Deny-All-Other-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "a1" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_subnet_network_security_group_association" "a2" {
  subnet_id                 = azurerm_subnet.subnet2.id
  network_security_group_id = azurerm_network_security_group.nsg2.id
}

# ---------- Task 4: VM1 (Windows, public IP) ----------
resource "azurerm_public_ip" "vm1" {
  name                = "pip-vm1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic1" {
  name                = "nic-vm1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.vm1_private_ip
    public_ip_address_id          = azurerm_public_ip.vm1.id
  }
}

resource "azurerm_windows_virtual_machine" "vm1" {
  name                  = "vm1-jumpbox" # Windows names max 15 chars
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# ---------- Task 4: VM2 (Linux, NO public IP) ----------
resource "azurerm_network_interface" "nic2" {
  name                = "nic-vm2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.vm2_private_ip
    # no public_ip_address_id on purpose
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                            = "vm2-private"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.nic2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

output "vm1_public_ip" {
  value = azurerm_public_ip.vm1.ip_address
}

output "vm2_private_ip" {
  value = local.vm2_private_ip
}
