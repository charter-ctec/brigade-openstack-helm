#!/bin/bash

#########################################################
# Reinstall brigade projects on host
# assumes home dir is /home/ubuntu
#
# ./brigade-setup-recur.sh build
#    - build brig binaries and install brigade projects
#
# ./brigade-setup-recur.sh
#     - install brigade projects
#########################################################

if [ "$1" == "build" ]; then
  echo "coming into build"
  # install dependent pacakges
  sudo apt-get update && sudo apt-get install -y wget \
     git \
     npm

  cd ~
  # install go
  wget https://storage.googleapis.com/golang/go1.9.2.linux-amd64.tar.gz
  sudo tar -xvf go1.9.2.linux-amd64.tar.gz
  sudo mv go /usr/local

  export GOROOT=/usr/local/go
  export PATH=$PATH:/usr/local/go/bin
  export GOPATH=/home/ubuntu/go
  export PATH=$PATH:$GOPATH/bin

  # get brigade source
  mkdir -p $(go env GOPATH)/src/github.com/Azure
  git clone https://github.com/Azure/brigade $(go env GOPATH)/src/github.com/Azure/brigade
  cd $(go env GOPATH)/src/github.com/Azure/brigade

  # build brig binaries as root
  sudo -s <<EOF

export GOROOT=/usr/local/go
export GOPATH=/home/ubuntu/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:/usr/local/go/bin

make bootstrap build
make bootstrap brig
make docker-build

ln -s  /home/ubuntu/go/src/github.com/Azure/brigade/bin/brig /usr/local/bin/brig  
EOF
fi

####################################################
# install brigade and brigade projects
####################################################

cd ~
# add repo
helm repo add brigade https://azure.github.io/brigade

# delete old brigade
helm ls --all brigade
helm del --purge brigade

# install brigade
cd ~/go/src/github.com/Azure/brigade/
#helm install -n brigade ./charts/brigade
#helm install -n brigade brigade/brigade
# start brigade with api service type as LoadBalancer for accessing kashti using hostport or external IP
helm install brigade/brigade --name brigade --set api.service.type=LoadBalancer

helm status brigade
helm ls --all brigade

# test project
helm del --purge empty-testbed
helm install -n empty-testbed charts/brigade-project
brig run -f brigade.js deis/empty-testbed

cat > brigade-testgit.js << EOF
const { events, Job } = require("brigadier")

events.on("exec", () => {
  var job = new Job("do-nothing", "alpine:3.4")
  job.tasks = [
    "echo Hello",
    "echo World"
  ]

  job.run()
})
EOF

brig run -f brigade-testgit.js deis/empty-testbed


# install KollaBrigade project

cd ~
if [ ! -d "KollaBrigade" ]; then
  git clone https://github.com/lukepatrick/KollaBrigade
fi
cd ~/KollaBrigade

helm ls --all kollabrigade
helm del kollabrigade --purge

helm install --name kollabrigade brigade/brigade-project \
    -f kollabrigade.yaml \
    --set secrets.docker_user=username \
    --set secrets.docker_pass=password

#brig run lukepatrick/KollaBrigade -f brigade.js

# install HelmBrigade project

cd ~
if [ ! -d "HelmBrigade" ]; then
  git clone https://github.com/lukepatrick/HelmBrigade
fi
cd ~/HelmBrigade

helm ls --all helmbrigade
helm del helmbrigade --purge

helm install --name helmbrigade brigade/brigade-project -f helmbrigade.yaml

# install Kashti

cd ~
if [ ! -d "kashti" ]; then
  git clone https://github.com/Azure/kashti.git
fi
cd ~/kashti

helm ls --all kashti
helm del kashti --purge

## Configure Kashti with local port-forwarding

#helm del --purge brigade
#helm install brigade/brigade --name brigade
#helm install -n kashti ./charts/kashti --set brigade.apiServer=http://localhost:7745

# setup port-forwarding
#kubectl port-forward `(kubectl get po | grep brigade-brigade-api | awk '{ print $1 }')` 7745 &
#kubectl port-forward `(kubectl get po | grep kashti | awk '{ print $1 }')`  8080:80 &

# check connection as "curl http://localhost:8080"


## Configure Kashti with NodePort

hostip=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f8)
brigade_hostport=$(kubectl get svc | grep brigade-brigade-api | awk -F ":|/" {'print $2'})
helm install -n kashti ./charts/kashti --set service.type=LoadBalancer --set brigade.apiServer=http://$hostip:$brigade_hostport

kashti_hostport=$(kubectl get svc | grep kashti-kashti | awk -F ":|/" {'print $2'})

echo "Access kashti url at http://$hostip:$kashti_hostport"
