variable "stack_id" {}

provider "cloudstack" {
    api_key       =  "${replace("${file("~/.terraform/nl2_cs_api_key")}", "\n", "")}"
    secret_key    =  "${replace("${file("~/.terraform/nl2_cs_secret_key")}", "\n", "")}"
    api_url       =  "https://nl2.mcc.schubergphilis.com/client/api"
    alias         =  "nl2"
}

resource "cloudstack_vpc" "vpc" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  name = "MCP_VPC_P${var.clustername}"
  cidr = "10.100.0.0/16"
  vpc_offering = "${lookup(var.offerings, "vpc${count.index}")}"
  zone = "${lookup(var.cs_zones, "vpc")}"
  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudstack_network" "network" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "network")}"
  name = "MCP_NET_P${var.clustername}"
  display_text = "kubernetes-network-${var.clustername}${count.index+1}"
  cidr = "10.100.0.0/24"
  network_offering = "${lookup(var.offerings, "network")}"
  zone = "${lookup(var.cs_zones, "network")}"
  vpc_id = "${cloudstack_vpc.vpc.0.id}"
  acl_id = "${element(cloudstack_network_acl.acl.*.id, count.index)}"
  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudstack_network_acl" "acl" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  name = "mcpp${var.clustername}-acl-${count.index+1}"
  vpc_id = "${cloudstack_vpc.vpc.0.id}"
}

resource "cloudstack_network_acl_rule" "acl-rule" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  acl_id = "${element(cloudstack_network_acl.acl.*.id, count.index)}"

   rule {
    cidr_list = ["195.66.90.0/24", "31.22.84.145/32"]
    protocol = "all"
    action = "allow"
    traffic_type = "ingress"
  }
}

resource "cloudstack_ipaddress" "master_public_ip" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "master")}"
  vpc = "${cloudstack_vpc.vpc.0.id}"
  lifecycle {
    prevent_destroy = true
  }
}

resource "null_resource" "add_dns_pri_master" {
  provisioner "local-exec" {
    command = <<EOF
curl -s -XPUT "https://discover.services.schubergphilis.com:2379/v2/keys/skydns/com/schubergphilis/services/${var.stack_id}k8s" -d value='{"host":"${element(cloudstack_ipaddress.master_public_ip.*.ip_address, 0)}"}'
EOF
  }
}

resource "null_resource" "add_dns_masters" {
  count = "${lookup(var.counts, "master")}"
  provisioner "local-exec" {
    command = <<EOF
curl -s -XPUT "https://discover.services.schubergphilis.com:2379/v2/keys/skydns/com/schubergphilis/services/${var.stack_id}k8s-master${count.index+1}" -d value='{"host":"${element(cloudstack_ipaddress.master_public_ip.*.ip_address, count.index)}"}'
EOF
  }
}

resource "cloudstack_port_forward" "master" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "master")}"
  ipaddress = "${element(cloudstack_ipaddress.master_public_ip.*.id, count.index)}"

  forward {
    protocol = "tcp"
    private_port = "22"
    public_port = "22"
    virtual_machine_id = "${element(cloudstack_instance.kube-master.*.id, count.index)}"
  }
  forward {
    protocol = "tcp"
    private_port = "8080"
    public_port = "8080"
    virtual_machine_id = "${element(cloudstack_instance.kube-master.*.id, count.index)}"
  }
  forward {
    protocol = "tcp"
    private_port = "6443"
    public_port = "6443"
    virtual_machine_id = "${element(cloudstack_instance.kube-master.*.id, count.index)}"
  }
}

output "addresses" {
  value = "Master IP addresses are ${join(", ", cloudstack_ipaddress.master_public_ip.*.ipaddress)}"
}
