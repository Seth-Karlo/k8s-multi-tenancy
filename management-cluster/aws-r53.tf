provider "aws" {
  access_key = "${replace("${file("~/.terraform/aws_sbp_access_key")}", "\n", "")}"
  secret_key = "${replace("${file("~/.terraform/aws_sbp_secret_key")}", "\n", "")}"
  region = "eu-west-1"
  alias = "euwest"
}

resource "aws_route53_record" "pub_master" {
   provider = "aws.euwest"
   count = "${lookup(var.counts, "master")}"
   zone_id = "Z2C2SU2XH6V2S3"
   name = "${count.index+1}.${var.clustername}"
   type = "A"
   ttl = "300"
   records = ["${element(cloudstack_ipaddress.master_public_ip.*.ip_address, count.index)}"]
}
resource "aws_route53_record" "pub_master_all" {
   provider = "aws.euwest"
   zone_id = "Z2C2SU2XH6V2S3"
   name = "${var.clustername}"
   type = "A"
   ttl = "300"
   records = ["${cloudstack_ipaddress.master_public_ip.*.ip_address}"]
}
