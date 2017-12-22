#!/bin/bash

#########################################################
# Setup host with Kubernetes Helm Armada Ceph
#########################################################

sudo apt-get update && sudo apt-get install -y git

# clone openstack-helm and openstack-helm-infra projects
cd ~
git clone https://git.openstack.org/openstack/openstack-helm-infra.git
git clone https://git.openstack.org/openstack/openstack-helm.git

# Deploy kubernetes and setup Helm
cd openstack-helm
./tools/deployment/developer/00-install-packages.sh
./tools/deployment/developer/01-deploy-k8s.sh
./tools/deployment/developer/02-setup-client.sh

# Setup ingress
./tools/deployment/developer/03-ingress.sh

# clone armada and start the container
cd ~
git clone https://github.com/att-comdev/armada.git
cd ~/armada

sudo chown ubuntu:ubuntu -R ~/.kube
sudo chmod 644 ~/.kube/config
sudo adduser ubuntu sudo
sudo adduser ubuntu docker

sudo docker run -d --net host -p 8000:8000 --name armada -v ~/openstack-helm:/opt/openstack-helm/charts:ro -v ~/.kube/config:/armada/.kube/config -v ~/armada/examples/:/examples quay.io/attcomdev/armada:latest


# copy any custom charts into ~/armada/examples to be used with Armada
cp -R ~/host-setup-brigade-keystone-glance-latest/*.yaml ~/armada/examples/

# deploy helm with armada
sudo docker exec armada armada apply /examples/ceph.yaml --debug
