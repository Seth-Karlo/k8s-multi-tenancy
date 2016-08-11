## This is very much a WIP

###Pre Requisites
1. A kubernetes cluster already running (the management cluster). This will run the masters of the sub clusters
2. A CloudStack or AWS cloud available
3. Terraform installed

###Create secrets in host cluster

- Edit tokens.csv and change to a token you'd like to use for your customer cluster, then create a secret

`kubectl create secret generic tokens --from-file=tokens.csv`

- Edit and push authorisation info:

`kubectl create secret generic auth --from-file=auth-policy.json`

- From https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-certificate-authority.md, download cfssl and generate your certificates:

```
cfssl_darwin-amd64 gencert -initca ca-csr.json| cfssljson_darwin-amd64 -bare ca
cfssl_darwin-amd64  gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson_darwin-amd64 -bare kubernetes
```

(As a side note, you can edit kubernetes-csr.json and add in your public IP if you wish)

- Add them as secrets:

```
kubectl create secret generic ca.pem --from-file=ca.pem
kubectl create secret generic kubernetes.pem --from-file=kubernetes.pem
kubectl create secret generic kubernetes-key.pem --from-file=kubernetes-key.pem
```
- Create and push service account key:

```
openssl genrsa -out kube-serviceaccount.key 2048
kubectl create secret generic kube-serviceaccount.key --from-file=kube-serviceaccount.key
```

- If using cloudstack, generate a file in this format:
```
[global]
api-url    = https://my.awesome.cloud/client/api
api-key    = XXX
secret-key = YYY
```

- And add

`kubectl create secret generic cloud-config --from-file=nl2-config`

###Creating etcd and masters:

- Start by setting up etcd:

`kubectl create -f etcd.yml`

- Then, for your tenant:

`kubectl create -f cloudstack-customer-svc.yml`

- Get the external IP:

```
kubectl get svc
NAME          CLUSTER-IP       EXTERNAL-IP      PORT(S)             AGE
customer1     10.100.83.170    85.222.238.106   6443/TCP            40s
```

- Edit cloudstack-customer.yml and change --advertise-address of the kube-apiserver to be your external IP

- Create deployment:

`kubectl create -f cloudstack-customer.yml`

```
kubectl get pods
NAME                         READY     STATUS    RESTARTS   AGE
customer1-3837246556-9irhk   3/3       Running   0          37s
customer1-3837246556-n082b   3/3       Running   0          37s
customer1-3837246556-wlsq7   3/3       Running   0          37s
etcd0                        1/1       Running   0          1d
etcd1                        1/1       Running   0          1d
etcd2                        1/1       Running   0          1d
```

Get source NAT of your mgmt clusters VPC (here it is 85.222.238.59) and create nodes for the new customer:

```
cd cloudstack-nodes/
terraform apply

var.clustername
  Enter a value: customer1

var.master_url
  Enter a value: https://85.222.238.106:6443

var.source_cidr
  Enter a value: 85.222.238.59/32
```

Wait a minute or so, and then:

```
kubectl -s https://85.222.238.106:6443 get nodes
NAME          STATUS    AGE
10.100.0.46   Ready     32s
```

TO DO:
- Automate a bit better
- Clean up secrets so we don't have so many
