#!/usr/bin/bash

set -eux

cd ocp/tf-master
terraform init  # in case plugin has changed
terraform destroy --auto-approve
cd ../../
rm -rf ocp/tf-master
