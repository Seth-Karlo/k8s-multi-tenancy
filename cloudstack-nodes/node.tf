variable "master_url" { }

resource "template_file" "node-config" {
    count = "1"
    template = "${file("node.yaml.tpl")}"
    vars {
      master_url = "${var.master_url}"
      clustername = "${var.clustername}"
    }
}

resource "cloudstack_instance" "kube-worker" {
  provider = "cloudstack.nl2"
  count = "1"
  zone = "${lookup(var.cs_zones, "worker")}"
  service_offering = "${lookup(var.offerings, "worker")}"
  template = "${var.cs_template}"
  name = "${var.clustername}k8s-worker${count.index+1}"
  network = "${cloudstack_network.network.0.id}"
  expunge = "true"
  user_data = "${element(template_file.node-config.*.rendered, count.index)}"
  keypair = "deployment"
}
