variable "master_url" { }

resource "template_file" "node-config" {
    count = "${lookup(var.counts, "node")}"
    template = "${file("node.yaml.tpl")}"
    vars {
      master_url = "${var.master_url}"
      clustername = "${var.clustername}"
      public_ip = "${element(cloudstack_ipaddress.node_public_ip.*.ip_address, count.index)}"
    }
}

resource "cloudstack_instance" "kube-node" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "node")}"
  zone = "${lookup(var.cs_zones, "node")}"
  service_offering = "${lookup(var.offerings, "node")}"
  template = "${var.cs_template}"
  name = "${var.clustername}-node${count.index+1}"
  network = "${cloudstack_network.network.0.id}"
  expunge = "true"
  user_data = "${element(template_file.node-config.*.rendered, count.index)}"
  keypair = "deployment"
}

resource "cloudstack_disk" "kube-node" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "node")}"
  zone = "${lookup(var.cs_zones, "node")}"
  name = "${var.clustername}-node${count.index+1}disk"
  disk_offering = "MCC_v1.40GB"
  attach = "true"
  virtual_machine = "${element(cloudstack_instance.kube-node.*.id, count.index)}"
  device = "/dev/xvdf"
}

resource "cloudstack_disk" "kube-storage" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "node")}"
  zone = "${lookup(var.cs_zones, "node")}"
  name = "${var.clustername}-storage${count.index+1}disk"
  disk_offering = "MCC_v1.120GB"
  attach = "true"
  virtual_machine = "${element(cloudstack_instance.kube-node.*.id, count.index)}"
  device = "/dev/xvdg"
}
