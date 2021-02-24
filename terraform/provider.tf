terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "3.1.1"
    }
  }
}

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
s