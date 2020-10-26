# Variables

variable "nsx_manager" {
  default = "nsxt-sa.bmrf.io"
}

# Username & Password for NSX-T Manager
variable "username" {
  default = "admin"
}

variable "password" {
  default = "VMware123!VMware123!"
}

# Transport Zones - Required to build Overlay and VLAN based constructs 
variable "vlan_tz" {
  default = "nsx-vlan-transportzone"
}

variable "overlay_tz" {
  default = "nsx-overlay-transportzone"
}

variable "rp_mtu" {
  default = "9000"
}


# Enter Edge Nodes Display Name. Required for external interfaces.
variable "edge_node_1" {
  default = "edge1-sa"
}
variable "edge_node_2" {
  default = "edge2-sa"
}


###################################################################
########################## Tier-0 Config ##########################
###################################################################
variable "rp_en1_fa_ip" {
  default = "10.10.100.2/28"
}

variable "rp_en1_fb_ip" {
  default = "10.10.101.2/28"
}

variable "rp_en2_fa_ip" {
  default = "10.10.100.3/28"
}

variable "rp_en2_fb_ip" {
  default = "10.10.101.3/28"
}

variable "t0_ecmp_local_as" {
  default = "65120"
}

variable "t0_ecmp_remote_as" {
  default = "65110"
}

variable "t0_ecmp_keep_alive" {
  default = "4"
}

variable "t0_ecmp_hold_down" {
  default = "12"
}

variable "t0_ecmp_peer_a" {
  default = "10.10.100.1"
}

variable "t0_ecmp_peer_b" {
  default = "10.10.101.1"
}
###################################################################
########################## Segment Names ##########################
###################################################################
variable "overlay_segments" {
  description = "Create these overlay segments"
  type = list(string)
  default = ["TF-Segment-App", "TF-Segment-Web", "TF-Segment-DB"]
}

variable "overlay_ip" {
  description = "Create these IPs - Needs to match order of segments above"
  type = list(string)
  default = ["172.16.10.1/24", "172.16.20.1/24", "172.16.30.1/24"]
}

# Security Group names.
variable "nsx_group_web" {
  default = "Web Servers"
}

variable "nsx_group_app" {
  default = "App Servers"
}

variable "nsx_group_db" {
  default = "DB Servers"
}

variable "nsx_group_blue" {
  default = "Blue Application"
}