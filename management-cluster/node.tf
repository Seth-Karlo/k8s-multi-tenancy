resource "template_file" "node-config" {
    count = "${lookup(var.counts, "worker")}"
    template = "${file("node.yaml.tpl")}"
    vars {
      terraform_master_ip = "${cloudstack_instance.kube-master.0.ip_address}"
      etcd1IP = "${cloudstack_instance.etcd.0.ip_address}"
      etcd2IP = "${cloudstack_instance.etcd.1.ip_address}"
      etcd3IP = "${cloudstack_instance.etcd.2.ip_address}"
      master1IP = "${cloudstack_instance.kube-master.0.ip_address}"
      master2IP = "${cloudstack_instance.kube-master.1.ip_address}"
      master3IP = "${cloudstack_instance.kube-master.2.ip_address}"
      clustername = "${var.clustername}"
    }
}

resource "cloudstack_instance" "kube-worker" {
  depends_on = ["cloudstack_instance.kube-master"]
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "worker")}"
  zone = "${lookup(var.cs_zones, "worker")}"
  service_offering = "${lookup(var.offerings, "worker")}"
  template = "${var.cs_template}"
  name = "mcpp${var.clustername}-node${count.index+1}"
  network = "${cloudstack_network.network.0.id}"
  expunge = "true"
  user_data = "${element(template_file.node-config.*.rendered, count.index)}"
  keypair = "deployment"
}

resource "cloudstack_disk" "kube-worker" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "worker")}"
  zone = "${lookup(var.cs_zones, "worker")}"
  name = "mccp${var.clustername}-node${count.index+1}disk"
  disk_offering = "MCC_v1.40GB"
  attach = "true"
  virtual_machine = "${element(cloudstack_instance.kube-worker.*.id, count.index)}"
  device = "/dev/xvdf"
}

resource "cloudstack_disk" "kube-storage" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "worker")}"
  zone = "${lookup(var.cs_zones, "worker")}"
  name = "mccp${var.clustername}-storage${count.index+1}disk"
  disk_offering = "MCC_v1.120GB"
  attach = "true"
  virtual_machine = "${element(cloudstack_instance.kube-worker.*.id, count.index)}"
  device = "/dev/xvdg"
}
