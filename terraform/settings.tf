terraform {
  required_version = ">=0.13"
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = " >=3.0"
    }
  }
}