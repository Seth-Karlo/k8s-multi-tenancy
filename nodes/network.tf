resource "cloudstack_vpc" "vpc" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  name = "SBP_VPC_K8S${var.clustername}${count.index+1}"
  cidr = "10.100.${count.index}.0/24"
  vpc_offering = "${lookup(var.offerings, "vpc${count.index}")}"
  zone = "${lookup(var.cs_zones, "vpc")}"
}

resource "cloudstack_network" "network" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "network")}"
  name = "SBP_NET_${var.clustername}${count.index+1}"
  display_text = "k8s_${var.clustername}${count.index+1}"
  cidr = "10.100.${count.index}.0/26"
  network_offering = "${lookup(var.offerings, "network")}"
  zone = "${lookup(var.cs_zones, "network")}"
  vpc_id = "${element(cloudstack_vpc.vpc.*.id, count.index)}"
  acl_id = "${element(cloudstack_network_acl.acl.*.id, count.index)}"
}

resource "cloudstack_network_acl" "acl" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  name = "k8s_${var.clustername}-acl-${count.index+1}"
  vpc_id = "${element(cloudstack_vpc.vpc.*.id, count.index)}"
}

resource "cloudstack_network_acl_rule" "acl-rule" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  acl_id = "${element(cloudstack_network_acl.acl.*.id, count.index)}"

   rule {
    source_cidr = "${var.source_cidr}"
    protocol = "all"
    action = "allow"
    traffic_type = "ingress"
  }
}

