variable "initial_admin_token" {}

resource "template_file" "master-config" {
    count = "${lookup(var.counts, "master")}"
    template = "${file("master.yaml.tpl")}"
    vars {
      terraform_hostname = "kube-master-1"
      vault_token = "${var.vault_token}"

      node1IP = "${cloudstack_instance.etcd.0.ip_address}"
      node2IP = "${cloudstack_instance.etcd.1.ip_address}"
      node3IP = "${cloudstack_instance.etcd.2.ip_address}"

      initial_admin_token = "${var.initial_admin_token}"
      clustername = "${var.clustername}"
    }
}

resource "cloudstack_instance" "kube-master" {
  count = "${lookup(var.counts, "master")}"
  provider = "cloudstack.nl2"
  zone = "${lookup(var.cs_zones, "master")}"
  service_offering = "${lookup(var.offerings, "master")}"
  template = "${var.cs_template}"
  name = "${var.clustername}k8s-master${count.index+1}"
  network = "${cloudstack_network.network.0.id}"
  expunge = "true"
  user_data = "${element(template_file.master-config.*.rendered, count.index)}"
  keypair = "deployment"
}

