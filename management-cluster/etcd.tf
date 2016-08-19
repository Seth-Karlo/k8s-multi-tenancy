resource "template_file" "etcd-config" {
    count = 3
    
    template = "${file("etcd-cloudconf.tpl")}"
    vars {
      terraform_discovery_url = "${var.discovery_url}"
      node_name = "node${count.index + 1}"
      vault_token = "${var.vault_token}"
    }
}

resource "cloudstack_instance" "etcd" {
  provider = "cloudstack.nl2"
    count            = "${lookup(var.counts, "etcd")}"
    expunge          = true
    name             = "mcpp${var.clustername}-etcd0${count.index+1}"
    service_offering = "${lookup(var.offerings, "etcd")}"
    template         = "${var.cs_template}"
    zone             = "${lookup(var.cs_zones, "etcd" )}"
    network          = "${cloudstack_network.network.0.id}"
    keypair          = "deployment"
    user_data        = "${element(template_file.etcd-config.*.rendered, count.index)}"
}
