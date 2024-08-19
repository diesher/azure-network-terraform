
####################################################
# spoke1
####################################################

# vnet peering
#----------------------------

# spoke1-to-hub1

resource "azurerm_virtual_network_peering" "spoke1_to_hub1_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-spoke1-to-hub1-peering"
  virtual_network_name         = module.spoke1.vnet.name
  remote_virtual_network_id    = module.hub1.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  depends_on = [
    module.spoke1,
    module.hub1,
  ]
}

# hub1-to-spoke1

resource "azurerm_virtual_network_peering" "hub1_to_spoke1_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-hub1-to-spoke1-peering"
  virtual_network_name         = module.hub1.vnet.name
  remote_virtual_network_id    = module.spoke1.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  depends_on = [
    module.spoke1,
    module.hub1,
  ]
}

# udr
#----------------------------

# main

module "spoke1_udr_main" {
  source         = "../../modules/route-table"
  resource_group = azurerm_resource_group.rg.name
  prefix         = "${local.spoke1_prefix}main"
  location       = local.spoke1_location
  subnet_ids     = [module.spoke1.subnets["MainSubnet"].id, ]
  routes = [for r in local.spoke1_udr_main_routes : {
    name                   = r.name
    address_prefix         = r.address_prefix
    next_hop_type          = length(try(r.next_hop_ip, "")) > 0 ? "VirtualAppliance" : "Internet"
    next_hop_in_ip_address = length(try(r.next_hop_ip, "")) > 0 ? r.next_hop_ip : null
  }]

  bgp_route_propagation_enabled = false

  depends_on = [
    time_sleep.hub1,
  ]
}

####################################################
# hub1
####################################################

# udr
#----------------------------

# gateway

module "hub1_gateway_udr" {
  source         = "../../modules/route-table"
  resource_group = azurerm_resource_group.rg.name
  prefix         = "${local.hub1_prefix}gateway"
  location       = local.hub1_location
  subnet_ids     = [module.hub1.subnets["GatewaySubnet"].id, ]
  routes = [for r in local.hub1_gateway_udr_destinations : {
    name                   = r.name
    address_prefix         = r.address_prefix
    next_hop_type          = length(try(r.next_hop_ip, "")) > 0 ? "VirtualAppliance" : "Internet"
    next_hop_in_ip_address = length(try(r.next_hop_ip, "")) > 0 ? r.next_hop_ip : null
  }]

  depends_on = [
    time_sleep.hub1,
  ]
}

# main

module "hub1_udr_main" {
  source         = "../../modules/route-table"
  resource_group = azurerm_resource_group.rg.name
  prefix         = "${local.hub1_prefix}main"
  location       = local.hub1_location
  subnet_ids     = [module.hub1.subnets["MainSubnet"].id, ]
  routes = [for r in local.hub1_udr_main_routes : {
    name                   = r.name
    address_prefix         = r.address_prefix
    next_hop_type          = length(try(r.next_hop_ip, "")) > 0 ? "VirtualAppliance" : "Internet"
    next_hop_in_ip_address = length(try(r.next_hop_ip, "")) > 0 ? r.next_hop_ip : null
  }]

  bgp_route_propagation_enabled = false

  depends_on = [
    time_sleep.hub1,
  ]
}

####################################################
# vpn-site connection
####################################################

# lng
#----------------------------

# branch1

resource "azurerm_local_network_gateway" "hub1_branch1_lng" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.hub1_prefix}branch1-lng"
  location            = local.hub1_location
  gateway_address     = azurerm_public_ip.branch1_nva_pip.ip_address
  address_space       = ["${local.branch1_nva_loopback0}/32", ]
  bgp_settings {
    asn                 = local.branch1_nva_asn
    bgp_peering_address = local.branch1_nva_loopback0
  }
}

# lng connection
#----------------------------

# branch1

resource "azurerm_virtual_network_gateway_connection" "hub1_branch1_lng" {
  resource_group_name            = azurerm_resource_group.rg.name
  name                           = "${local.hub1_prefix}branch1-lng-conn"
  location                       = local.hub1_location
  type                           = "IPsec"
  enable_bgp                     = true
  virtual_network_gateway_id     = module.hub1.s2s_vpngw.id
  local_network_gateway_id       = azurerm_local_network_gateway.hub1_branch1_lng.id
  local_azure_ip_address_enabled = false
  shared_key                     = local.psk
  egress_nat_rule_ids            = []
  ingress_nat_rule_ids           = []
}

# resource "azurerm_virtual_network_gateway_connection" "hub1_branch1_lng" {
#   resource_group_name                = azurerm_resource_group.rg.name
#   name                               = "${local.hub1_prefix}branch1-lng-conn"
#   location                           = local.hub1_location
#   type                               = "IPsec"
#   enable_bgp                         = true
#   virtual_network_gateway_id         = module.hub1.s2s_vpngw.id
#   local_network_gateway_id           = azurerm_local_network_gateway.hub1_branch1_lng.id
#   local_azure_ip_address_enabled     = false
#   shared_key                         = local.psk
#   egress_nat_rule_ids                = []
#   ingress_nat_rule_ids               = []
#   use_policy_based_traffic_selectors = true
#   ipsec_policy {
#     # sa_life_time     = 3600
#     # sa_data_size     = 102400000
#     ipsec_encryption = "AES256"
#     ipsec_integrity  = "SHA1"
#     ike_encryption   = "AES256"
#     ike_integrity    = "SHA1"
#     dh_group         = "DHGroup2"
#     pfs_group        = "PFS2"
#   }
#   traffic_selector_policy {
#     local_address_cidrs = [
#       local.hub1_subnets["MainSubnet"].address_prefixes[0],
#       local.spoke1_subnets["MainSubnet"].address_prefixes[0],
#     ]
#     remote_address_cidrs = [
#       local.branch1_subnets["MainSubnet"].address_prefixes[0],
#       local.branch3_subnets["MainSubnet"].address_prefixes[0],
#     ]
#   }
# }

####################################################
# output files
####################################################

locals {
  hub1_files = {}
}

resource "local_file" "hub1_files" {
  for_each = local.hub1_files
  filename = each.key
  content  = each.value
}

