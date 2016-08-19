variable "cs_cidrs" {
  default = {
    vpc = "10.100.0.0/16"
    network = "10.100.0.0/24"
  }
}

variable "cs_zones" {
  default = {
    network = "NL2"
    master = "NL2"
    worker = "NL2"
    vpc = "NL2"
    etcd = "NL2"
    storage = "NL2"
  }
}

variable "offerings" {
  default = {
    master = "MCC_v2.1vCPU.4GB.SBP1"
    worker = "MCC_v2.2vCPU.8GB.SBP1"
    storage = "MCC_v2.2vCPU.8GB.SBP1"
    etcd = "MCC_v2.1vCPU.4GB.SBP1"
    network = "MCC-VPC-LB"
    vpc0 = "MCC-KVM-VPC-Red"
  }
}

variable "counts" {
  default = {
    vpc = "1"
    network = "1"
    master = "3"
    worker = "3"
    etcd = "3"
    storage = "1"
  }
}

variable "cs_template" {
  default = "Coreos-beta-x86_64-Community-KVM-latest"
}

variable "discovery_url" {  }
variable "vault_token" {  }
variable "clustername" {  }
