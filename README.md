Start by setting up etcd:
kubectl create -f etcd.yml

Then, for your customer:

kubectl create -f master2-svc.yml

get the external IP:

arepton@sbplt5236g3qr:/Users/arepton/Documents/Projects/kubernetes/multi-tenancy/nodes  $ kubectl get svc master2
NAME      CLUSTER-IP       EXTERNAL-IP      PORT(S)             AGE
master2   10.100.195.110   85.222.238.107   6443/TCP,8080/TCP   3m

edit master2.yml to set the advertise-address to be the external IP

Create deployment:

kubectl create -f master2.yml

get source NAT of your master's VPC (here it is 85.222.238.59)

cd nodes/
terraform apply

arepton@sbplt5236g3qr:/Users/arepton/Documents/Projects/kubernetes/multi-tenancy/nodes  $ terraform apply
var.clustername
  Enter a value: master2

var.master_url
  Enter a value: https://85.222.238.107:6443

var.source_cidr
  Enter a value: 85.222.238.59/32

Wait a minute or so, and then:

arepton@sbplt5236g3qr:/Users/arepton/Documents/Projects/kubernetes/multi-tenancy  $ kubectl -s https://85.222.238.107:6443 get nodes
NAME          STATUS    AGE
10.100.0.46   Ready     32s


TO DO:
- Get working with Certs/auth as it's over public ips
- Automate a bit better
