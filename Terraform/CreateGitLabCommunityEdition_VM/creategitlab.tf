#variable "resourcename" {
#  default = "GitLab"
#}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
  name     = "GitLab-CE"
  location = "japaneast"
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "japaneast"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "Subnet1"
  resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
  virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                         = "PublicIP"
  location                     = "japaneast"
  resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
  public_ip_address_allocation = "dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "NetworkSecurityGroup"
  location            = "japaneast"
  resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                      = "NIC"
  location                  = "japaneast"
  resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
  network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

  ip_configuration {
    name                          = "NicConfiguration"
    subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.myterraformgroup.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.myterraformgroup.name}"
  location                 = "japaneast"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
  name                  = "GitLabCEVM"
  location              = "japaneast"
  resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "gitlab"
    offer     = "gitlab-ce"
    sku       = "gitlab-ce"
    version   = "latest"
  }

  plan {
    name      = "gitlab-ce"
    publisher = "gitlab"
    product   = "gitlab-ce"
  }

  os_profile {
    computer_name  = "gitlabce"
    admin_username = "mebisuda"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/mebisuda/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBvXmMEi/0ZAKuUktLaIVf7QBGE+MnbtZ0R3dPPDCA5N8wcbdW19fQKxHk0JzNE01XC3uN7dO1hpFE5I/vCU0OFgNp6iT4AdYbG6dUc0YLXD00Tc0lcUp9JRMkHy354qcSvfxWJ7zP4JMf/AVbMsFvY8e7hmSlGrUKyT3wwMc9tUwTiExDFOzlmpOrReC/xus9DDdY/HQtWHnKD8elJqELWFzHnApaCkUQr5k0B5VHiMqMWSPQa9GOPmh15hDybxk5yBKnJUGy2VMXUQ+WEuLZCpH54Wyb1Ldzv2kcqn5RSSZm6Y3FfPkdf45nlLtDoO35xltKr8JYOdj+2cEeyiQr mebisuda@cc-cc7d-fe680b19-3280611124-hb853"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }
}
