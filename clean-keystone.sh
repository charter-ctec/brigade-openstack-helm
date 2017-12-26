#!/bin/bash
# Copyright 2017 Charter DNA Team (CTEC).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
### Declare colors to use during the running of this script:
set -x
declare -r GREEN="\033[0;32m"
declare -r RED="\033[0;31m"
declare -r YELLOW="\033[0;33m"

function echo_green {
  echo -e "${GREEN}$1"; tput sgr0
}
function echo_red {
  echo -e "${RED}$1"; tput sgr0
}
function echo_yellow {
  echo -e "${YELLOW}$1"; tput sgr0
}


helm delete --purge armada-memcached
helm delete --purge armada-mariadb



echo_yellow "\nDELETING OPENSTACK COMPONENTS:"
helm delete --purge armada-keystone &
sleep 5
kubectl delete jobs/`(kubectl get jobs -n openstack | grep keystone-db-drop | cut -d " " -f1)` -n openstack
kubectl delete jobs/`(kubectl get jobs -n openstack | grep keystone-clean | cut -d " " -f1)` -n openstack

echo_yellow "\nDELETING ANY REMAINING CRONJOBS:"
kubectl delete cronjob/`(kubectl get cronjob -n openstack | grep keystone-credential | cut -d " " -f1)` -n openstack
kubectl delete cronjob/`(kubectl get cronjob -n openstack | grep keystone-fernet | cut -d " " -f1)` -n openstack


echo_yellow "\nDELETING DATABASE COMPONENTS:"
kubectl delete pvc mysql-data-mariadb-0 -n openstack
kubectl delete pvc mysql-data-mariadb-1 -n openstack
kubectl delete pvc mysql-data-mariadb-2 -n openstack
kubectl delete po/mariadb-0 --grace-period=0 --force -n openstack
kubectl delete po/mariadb-1 --grace-period=0 --force -n openstack
kubectl delete po/mariadb-2 --grace-period=0 --force -n openstack
helm delete --purge mariadb


echo_yellow "\nDELETING PODS IN ERROR STATE:"
# deleting pods in error state of older brigade runs(if any)
# failing to do so will cause armada apply command to hang
kubectl get pods -w  | grep Error  > kubectl_error_pods.txt &
sleep 10
ps aux | grep "kubectl get pods -w" | grep -v grep | awk {'print $2'} | xargs -r kill -9
sleep 5
kubectl delete pods $(cat kubectl_error_pods.txt | awk '{print $1}')

echo_yellow "\nDELETING SECRETS AND PVC OF BRIGADE WORKERS:"
#export secret_array=`(kubectl get secrets | grep 'brigade-worker.*master' | cut -d " " -f1)`
#for secret in $secret_array;do
# kubectl delete secrets $secret
#done

#export secret_array=`(kubectl get secrets | grep 'docker-deploy-job.*master' | cut -d " " -f1)`
#for secret in $secret_array;do
# kubectl delete secrets $secret
#done

export pvc_array=`(kubectl get pvc | grep 'brigade-worker.*master' | cut -d " " -f1)`
for pvc in $pvc_array;do
 kubectl delete pvc $pvc
done

echo_yellow "\nCHECK FOR ANY MISSED RESOURCE CLEANUP"
kubectl get jobs --all-namespaces
kubectl get cronjob --all-namespaces
kubectl get pvc --all-namespaces

echo_green "\nDONE!"
