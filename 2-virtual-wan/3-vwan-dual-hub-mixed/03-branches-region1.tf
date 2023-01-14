
####################################################
# branch1
####################################################

# env
#----------------------------

module "branch1" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.branch1_prefix, "-")
  location        = local.branch1_location
  storage_account = azurerm_storage_account.region1

  nsg_subnets = {
    "main" = azurerm_network_security_group.nsg_region1_main.id
    "int"  = azurerm_network_security_group.nsg_region1_main.id
    "ext"  = azurerm_network_security_group.nsg_region1_nva.id
  }

  vnet_config = [
    {
      address_space = local.branch1_address_space
      subnets       = local.branch1_subnets
      dns_servers   = [local.branch1_dns_addr, ]
      enable_vpngw  = false
      enable_ergw   = false
    }
  ]

  vm_config = [
    {
      name        = "vm1"
      custom_data = base64encode(local.vm_startup)
      private_ip  = local.branch1_vm_addr
    },
  ]

  dns_config = [
    {
      name             = "dns"
      private_ip       = local.branch1_dns_addr
      custom_data      = base64encode(local.branch_unbound_config)
      use_vm_extension = true
    }
  ]
}

# addresses
#----------------------------

# nva

resource "azurerm_public_ip" "branch1_nva_pip" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.branch1_prefix}nva-pip"
  location            = local.region1
  sku                 = "Standard"
  allocation_method   = "Static"
}

/*####################################################
# branch2
####################################################

# env
#----------------------------

module "branch2" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.branch2_prefix, "-")
  location        = local.branch2_location
  storage_account = azurerm_storage_account.region1

  nsg_subnets = {
    "main" = azurerm_network_security_group.nsg_region1_main.id
    "int"  = azurerm_network_security_group.nsg_region1_main.id
    "ext"  = azurerm_network_security_group.nsg_region1_nva.id
  }

  vnet_config = [
    {
      address_space = local.branch2_address_space
      subnets       = local.branch2_subnets
      dns_servers   = [local.branch2_dns_addr, ]
      enable_vpngw  = false
      enable_ergw   = true
    }
  ]

  vm_config = [
    { name = "vm1", custom_data = base64encode(local.vm_startup), private_ip = local.branch2_vm_addr },
  ]

  dns_config = [
    {
      name             = "dns"
      private_ip       = local.branch2_dns_addr
      custom_data      = base64encode(local.branch_unbound_config)
      use_vm_extension = true
    }
  ]
}*/
