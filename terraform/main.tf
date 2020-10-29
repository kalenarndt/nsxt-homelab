# NSX-T Manager Credentials
provider "nsxt" {
  host                  = var.nsx_manager
  username              = var.username
  password              = var.password
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

# Data Sources we need for reference later
data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = var.overlay_tz
}


data "nsxt_policy_transport_zone" "vlan_tz" {
  display_name = var.vlan_tz
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
  display_name = "edge-cluster-t0"
}

data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

data "nsxt_policy_service" "http" {
  display_name = "HTTP"
}

data "nsxt_policy_service" "https" {
  display_name = "HTTPS"
}

data "nsxt_policy_edge_node" "edge_node_1" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  display_name      = var.edge_node_1
}

data "nsxt_policy_edge_node" "edge_node_2" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  display_name      = var.edge_node_2
}



# Create NSX-T VLAN Segments
resource "nsxt_policy_vlan_segment" "edge_peer_a" {
  display_name          = "seg-fa-bgp-vl100"
  description           = "VLAN Segment created by Terraform"
  transport_zone_path   = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids              = ["100"]
  
  advanced_config {
    uplink_teaming_policy = "uplink-1"
  }

}

resource "nsxt_policy_vlan_segment" "edge_peer_b" {
  display_name          = "seg-fb-bgp-vl101"
  description           = "VLAN Segment created by Terraform"
  transport_zone_path   = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids              = ["101"]

  advanced_config {
    uplink_teaming_policy = "uplink-2"
  }
}

# Create Tier-0 Gateway
resource "nsxt_policy_tier0_gateway" "tier0_gw" {
  display_name         = "t0-ecmp"
  description          = "Tier-0 provisioned by Terraform"
  failover_mode        = "NON_PREEMPTIVE"
  default_rule_logging = false
  enable_firewall      = false
  force_whitelisting   = false
  ha_mode              = "ACTIVE_ACTIVE"
  edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster.path

  bgp_config {
    ecmp            = true
    local_as_num    = var.t0_ecmp_local_as
    inter_sr_ibgp   = true
    multipath_relax = true
  }

  redistribution_config {
    enabled = true
    rule {
      name  = "t0-route-redistribution"
      types = ["TIER1_LB_VIP", "TIER1_CONNECTED", "TIER1_SERVICE_INTERFACE", "TIER1_NAT", "TIER1_LB_SNAT"]
    }
  }  
}

# Create Tier-0 Gateway Uplink Interfaces

# Edge Node 1 - Fabric A - Router Port Configuration
resource "nsxt_policy_tier0_gateway_interface" "rp_en1_fa" {
  display_name   = "rp-en1-fa"
  description    = "Edge Node 1 Router Port - Fabric A"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_1.path
  gateway_path   = nsxt_policy_tier0_gateway.tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.edge_peer_a.path
  subnets        = [var.rp_en1_fa_ip]
  mtu            = var.rp_mtu
}

# Edge Node 1 - Fabric B - Router Port Configuration 
resource "nsxt_policy_tier0_gateway_interface" "rp_en1_fb" {
  display_name   = "rp-en1-fb"
  description    = "Edge Node 1 Router Port - Fabric B"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_1.path
  gateway_path   = nsxt_policy_tier0_gateway.tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.edge_peer_b.path
  subnets        = [var.rp_en1_fb_ip]
  mtu            = var.rp_mtu
}

# Edge Node 2 - Fabric A - Router Port Configuration 
resource "nsxt_policy_tier0_gateway_interface" "rp_en2_fa" {
  display_name   = "rp-en2-fa"
  description    = "Edge Node 2 Router Port - Fabric A"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_2.path
  gateway_path   = nsxt_policy_tier0_gateway.tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.edge_peer_a.path
  subnets        = [var.rp_en2_fa_ip]
  mtu            = var.rp_mtu
}

# Edge Node 2 - Fabric B - Router Port Configuration 
resource "nsxt_policy_tier0_gateway_interface" "rp_en2_fb" {
  display_name   = "rp-en2-fb"
  description    = "Edge Node 2 Router Port - Fabric B"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_2.path
  gateway_path   = nsxt_policy_tier0_gateway.tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.edge_peer_b.path
  subnets        = [var.rp_en2_fb_ip]
  mtu            = var.rp_mtu
}

# Local definitions 
locals {
  # Concatinate 2 lists for ToR-A
  peer_a_source_addresses = concat(
    nsxt_policy_tier0_gateway_interface.rp_en1_fa.ip_addresses,
    nsxt_policy_tier0_gateway_interface.rp_en2_fa.ip_addresses
  )
  # Concatinate 2 lists for ToR-B
  peer_b_source_addresses = concat(
    nsxt_policy_tier0_gateway_interface.rp_en1_fb.ip_addresses,
    nsxt_policy_tier0_gateway_interface.rp_en2_fb.ip_addresses
  )  
}

###################################################################
########################## Prefix Lists ###########################
###################################################################
## Allows for filtering networks learned and networks advertised ##
###################################################################
resource "nsxt_policy_gateway_prefix_list" "ecmp_t0_prefix_in" {
  display_name = "ecmp_t0_prefix_in"
  gateway_path = nsxt_policy_tier0_gateway.tier0_gw.path

  prefix {
    action  = "PERMIT"
    network = "0.0.0.0/0"
  }
  prefix {
    action = "DENY"
  }
}

resource "nsxt_policy_gateway_prefix_list" "ecmp_t0_prefix_out" {
  display_name = "ecmp_t0_prefix_out"
  gateway_path = nsxt_policy_tier0_gateway.tier0_gw.path

  prefix {
    action  = "PERMIT"
    network = "172.16.0.0/16"
  }
  prefix {
    action = "DENY"
  }
}

# BGP Neighbor Configuration - ToR-A 
resource "nsxt_policy_bgp_neighbor" "router_a" {
  display_name     = "ToR-A"
  description      = "Terraform provisioned BGP Neighbor Configuration"
  bgp_path         = nsxt_policy_tier0_gateway.tier0_gw.bgp_config.0.path
  neighbor_address = var.t0_ecmp_peer_a
  remote_as_num    = var.t0_ecmp_remote_as
  hold_down_time   = var.t0_ecmp_hold_down
  keep_alive_time  = var.t0_ecmp_keep_alive
  source_addresses = local.peer_a_source_addresses

  bfd_config {
    enabled  = true
    interval = 500
    multiple = 3
  }

  route_filtering {
  address_family   = "IPV4"
  maximum_routes   = 20
  in_route_filter  = nsxt_policy_gateway_prefix_list.ecmp_t0_prefix_in.path
  out_route_filter = nsxt_policy_gateway_prefix_list.ecmp_t0_prefix_out.path
  }
}

# BGP Neighbor Configuration - ToR-B
resource "nsxt_policy_bgp_neighbor" "router_b" {
  display_name     = "ToR-B"
  description      = "Terraform provisioned BGP Neighbor Configuration"
  bgp_path         = nsxt_policy_tier0_gateway.tier0_gw.bgp_config.0.path
  neighbor_address = var.t0_ecmp_peer_b
  remote_as_num    = var.t0_ecmp_remote_as
  hold_down_time   = var.t0_ecmp_hold_down
  keep_alive_time  = var.t0_ecmp_keep_alive
  source_addresses = local.peer_b_source_addresses


  bfd_config {
    enabled  = true
    interval = 500
    multiple = 3
  }

  route_filtering {
  address_family   = "IPV4"
  maximum_routes   = 20
  in_route_filter  = nsxt_policy_gateway_prefix_list.ecmp_t0_prefix_in.path
  out_route_filter = nsxt_policy_gateway_prefix_list.ecmp_t0_prefix_out.path
  }
}

# Create Tier-1 Gateway
resource "nsxt_policy_tier1_gateway" "tier1_gw" {
  description               = "Tier-1 provisioned by Terraform"
  display_name              = "t1-general"
  nsx_id                    = "predefined_id"
  failover_mode             = "NON_PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "true"
  enable_standby_relocation = "false"
  force_whitelisting        = "true"
  tier0_path                = nsxt_policy_tier0_gateway.tier0_gw.path
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]


  route_advertisement_rule {
    name                      = "Tier 1 Networks"
    action                    = "PERMIT"
    subnets                   = ["172.16.10.0/24", "172.16.20.0/24", "172.16.30.0/24"]
    prefix_operator           = "GE"
    route_advertisement_types = ["TIER1_CONNECTED"]
  }
}

# Create NSX-T Overlay Segments
resource "nsxt_policy_segment" "tf_segments" {
  count               = length(var.overlay_segments)
  display_name        = var.overlay_segments[count.index]
  description         = "Segment created by Terraform"
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
  connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path

  subnet {
    cidr = var.overlay_ip[count.index]
  }
}


# Create Security Groups
resource "nsxt_policy_group" "web_servers" {
  display_name = var.nsx_group_web
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "Web"
    }
  }
}

resource "nsxt_policy_group" "app_servers" {
  display_name = var.nsx_group_app
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "App"
    }
  }
}

resource "nsxt_policy_group" "db_servers" {
  display_name = var.nsx_group_db
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "DB"
    }
  }
}

resource "nsxt_policy_group" "blue_servers" {
  display_name = var.nsx_group_blue
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "Blue"
    }
  }
}

# Create Custom Services
resource "nsxt_policy_service" "service_tcp8443" {
  description  = "HTTPS service provisioned by Terraform"
  display_name = "TCP 8443"

  l4_port_set_entry {
    display_name      = "TCP8443"
    description       = "TCP port 8443 entry"
    protocol          = "TCP"
    destination_ports = ["8443"]
  }

  tag {
    scope = "color"
    tag   = "blue"
  }
}

# Create Security Policies
resource "nsxt_policy_security_policy" "allow_blue" {
  display_name = "Allow Blue Application"
  description  = "Terraform provisioned Security Policy"
  category     = "Application"
  locked       = false
  stateful     = true
  tcp_strict   = false
  scope        = [nsxt_policy_group.web_servers.path]

  rule {
    display_name       = "Allow SSH to Blue Servers"
    destination_groups = [nsxt_policy_group.blue_servers.path]
    action             = "ALLOW"
    services           = [data.nsxt_policy_service.ssh.path]
    logged             = true
    scope              = [nsxt_policy_group.blue_servers.path]
  }

  rule {
    display_name       = "Allow HTTPS to Web Servers"
    destination_groups = [nsxt_policy_group.web_servers.path]
    action             = "ALLOW"
    services           = [data.nsxt_policy_service.https.path]
    logged             = true
    scope              = [nsxt_policy_group.web_servers.path]
  }

  rule {
    display_name       = "Allow TCP 8443 to App Servers"
    source_groups      = [nsxt_policy_group.web_servers.path]
    destination_groups = [nsxt_policy_group.app_servers.path]
    action             = "ALLOW"
    services           = [nsxt_policy_service.service_tcp8443.path]
    logged             = true
    scope              = [nsxt_policy_group.web_servers.path, nsxt_policy_group.app_servers.path]
  }

  rule {
    display_name       = "Allow HTTP to DB Servers"
    source_groups      = [nsxt_policy_group.app_servers.path]
    destination_groups = [nsxt_policy_group.db_servers.path]
    action             = "ALLOW"
    services           = [data.nsxt_policy_service.http.path]
    logged             = true
    scope              = [nsxt_policy_group.app_servers.path, nsxt_policy_group.db_servers.path]
  }

  rule {
    display_name = "Any Deny"
    action       = "REJECT"
    logged       = false
    scope        = [nsxt_policy_group.blue_servers.path]
  }
}