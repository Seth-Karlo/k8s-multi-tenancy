#!/bin/bash 
set -e

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ssl_dir="$1"

mkdir -p $ssl_dir
# Generate Root CA
openssl genrsa -out $ssl_dir/ca-key.pem 2048
openssl req -x509 -new -nodes -key $ssl_dir/ca-key.pem -days 10000 -out $ssl_dir/ca.pem -subj "/CN=kube-ca"

# Generate API Servers Keys - needs openssl.cnf
openssl genrsa -out $ssl_dir/apiserver-key.pem 2048 
openssl req -new -key $ssl_dir/apiserver-key.pem -out $ssl_dir/apiserver.csr -subj "/CN=kube-apiserver" -config $SCRIPTDIR/openssl.cnf
openssl x509 -req -in $ssl_dir/apiserver.csr -CA $ssl_dir/ca.pem -CAkey $ssl_dir/ca-key.pem -CAcreateserial -out $ssl_dir/apiserver.pem -days 365 -extensions v3_req -extfile $SCRIPTDIR/openssl.cnf
openssl genrsa -out $ssl_dir/kube-serviceaccount.key 2048
