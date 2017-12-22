# Host setup and deploy Keystone with Brigade


## Prerequisites

1. Host running Ubuntu
2. Sudo access to ubuntu user
      useradd -m ubuntu -s /bin/bash
      echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

## Install on Host

### Set up Host with Kubernetes, Helm, Armada, Ceph

The Host-setup.sh uses the install scripts from
https://github.com/openstack/openstack-helm/blob/master/doc/source/install/developer/all-in-one.rst
1) Deploy kubernetes
2) Configure Helm
3) Deploy ingress
4) Run armada container with volume mount to charts in ~/openstack-helm
5) Deploy ceph with armada ( ceph chart needs to be copied into ~/armada/examples/ )

Uncomment the following line and update the charts dif in Host-setup.sh to copy the custom yaml(inclduing ceph.yaml, keystone.yaml) before running the script
```bash
#cp -R <mycustomchartsdir>/* ~/armada/examples/
```

Start the install
```bash
$ ./Host-setup.sh
```

ceph.yaml
```
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: helm-toolkit
data:
  chart_name: helm-toolkit
  release: helm-toolkit
  namespace: helm-toolkit
  timeout: 300
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: helm-toolkit
    reference: master
  dependencies: []
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: ceph
data:
  chart_name: ceph
  release: ceph
  namespace: ceph
  timeout: 3600
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
    pre:
      delete:
        - name: ceph-bootstrap
          type: job
          labels:
            - application: ceph
            - component: bootstrap
            - release_group: osh-ceph
        - name: ceph-mds-keyring-generator
          type: job
          labels:
            - application: ceph
            - component: mds-keyring-generator
            - release_group: osh-ceph
        - name: ceph-mon-keyring-generator
          type: job
          labels:
            - application: ceph
            - component: mon-keyring-generator
            - release_group: osh-ceph
        - name: ceph-rgw-keyring-generator
          type: job
          labels:
            - application: ceph
            - component: rgw-keyring-generator
            - release_group: osh-ceph
        - name: ceph-storage-keys-generator
          type: job
          labels:
            - application: ceph
            - component: storage-keys-generator
            - release_group: osh-ceph
        - name: ceph-osd-keyring-generator
          type: job
          labels:
            - application: ceph
            - component: osd-keyring-generator
            - release_group: osh-ceph
  values:
    endpoints:
      identity:
        namespace: openstack
      object_store:
        namespace: ceph
      ceph_mon:
        namespace: ceph
    ceph:
      rgw_keystone_auth: true
    network:
      public: 172.17.0.1/16
      cluster: 172.17.0.1/16
    deployment:
      storage_secrets: true
      ceph: true
      rbd_provisioner: true
      client_secrets: false
      rgw_keystone_user_and_endpoints: false
    bootstrap:
      enabled: true
    conf:
      ceph:
        config:
          global:
            osd_pool_default_size: 1
          osd:
            osd_crush_chooseleaf_type: 0
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: ceph
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: ceph-config
data:
  chart_name: ceph-config
  release: ceph-config
  namespace: openstack
  timeout: 3600
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
    pre:
      delete:
        - name: ceph-namespace-client-key-generator
          type: job
          labels:
            - application: ceph
            - component: namespace-client-key-generator
            - release_group: osh-ceph
  values:
    endpoints:
      identity:
        namespace: openstack
      object_store:
        namespace: ceph
      ceph_mon:
        namespace: ceph
    ceph:
      rgw_keystone_auth: true
    network:
      public: 172.17.0.1/16
      cluster: 172.17.0.1/16
    deployment:
      storage_secrets: false
      ceph: false
      rbd_provisioner: false
      client_secrets: true
      rgw_keystone_user_and_endpoints: false
    conf:
      ceph:
        config:
          global:
            osd_pool_default_size: 1
          osd:
            osd_crush_chooseleaf_type: 0
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: ceph
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/ChartGroup/v1
metadata:
  schema: metadata/Document/v1
  name: ceph-storage
data:
  description: "Ceph Storage"
  sequenced: True
  chart_group:
    - ceph
    - ceph-config
---
schema: armada/Manifest/v1
metadata:
  schema: metadata/Document/v1
  name: armada-manifest
data:
  release_prefix: osh
  chart_groups:
    - ceph-storage
```


keystone.yaml
```
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: helm-toolkit
data:
  chart_name: helm-toolkit
  release: helm-toolkit
  namespace: helm-toolkit
  timeout: 300
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: helm-toolkit
    reference: master
  dependencies: []
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: mariadb
data:
  chart_name: mariadb
  release: mariadb
  namespace: openstack
  timeout: 3600
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: mariadb
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: memcached
data:
  chart_name: memcached
  release: memcached
  namespace: openstack
  timeout: 300
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: memcached
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: keystone
data:
  chart_name: keystone
  release: keystone
  namespace: openstack
  timeout: 300
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
    pre:
      delete:
        - name: keystone-bootstrap
          type: job
          labels:
            - application: keystone
            - component: bootstrap
            - release_group: osh-keystone
        - name: keystone-credential-setup
          type: job
          labels:
            - application: keystone
            - component: credential-setup
            - release_group: osh-keystone
        - name: keystone-db-init
          type: job
          labels:
            - application: keystone
            - component: db-init
            - release_group: osh-keystone
        - name: keystone-db-sync
          type: job
          labels:
            - application: keystone
            - component: db-sync
            - release_group: osh-keystone
        - name: keystone-fernet-setup
          type: job
          labels:
            - application: keystone
            - component: fernet-setup
            - release_group: osh-keystone
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: keystone
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/ChartGroup/v1
metadata:
  schema: metadata/Document/v1
  name: keystone-infra-services
data:
  description: "Keystone Infra Services"
  sequenced: True
  chart_group:
    - mariadb
    - memcached
---
schema: armada/ChartGroup/v1
metadata:
  schema: metadata/Document/v1
  name: openstack-keystone
data:
  description: "Deploying OpenStack Keystone"
  sequenced: True
  test_charts: False
  chart_group:
    - keystone
---
schema: armada/Manifest/v1
metadata:
  schema: metadata/Document/v1
  name: armada-manifest
data:
  release_prefix: armada
  chart_groups:
    - keystone-infra-services
    - openstack-keystone
```


glance.yaml
```
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: helm-toolkit
data:
  chart_name: helm-toolkit
  release: helm-toolkit
  namespace: helm-toolkit
  timeout: 300
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: helm-toolkit
    reference: master
  dependencies: []
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: etcd
data:
  chart_name: etcd
  release: etcd
  namespace: openstack
  timeout: 3600
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: etcd
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: rabbitmq
data:
  chart_name: rabbitmq
  release: rabbitmq
  namespace: openstack
  timeout: 300
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: rabbitmq
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/Chart/v1
metadata:
  schema: metadata/Document/v1
  name: glance
data:
  chart_name: glance
  release: glance
  namespace: openstack
  timeout: 300
  install:
    no_hooks: false
  upgrade:
    no_hooks: false
    pre:
      delete:
        - name: glance-bootstrap
          type: job
          labels:
            - application: glance
            - component: bootstrap
            - release_group: osh-glance
        - name: glance-db-init
          type: job
          labels:
            - application: glance
            - component: db-init
            - release_group: osh-glance
        - name: glance-db-sync
          type: job
          labels:
            - application: glance
            - component: db-sync
            - release_group: osh-glance
        - name: glance-ks-service
          type: job
          labels:
            - application: glance
            - component: ks-service
            - release_group: osh-glance
        - name: glance-ks-endpoints
          type: job
          labels:
            - application: glance
            - component: ks-endpoints
            - release_group: osh-glance
        - name: glance-ks-user
          type: job
          labels:
            - application: glance
            - component: ks-user
            - release_group: osh-glance
  values: {}
  source:
    type: local
    location: /opt/openstack-helm/charts
    subpath: glance
    reference: master
  dependencies:
    - helm-toolkit
---
schema: armada/ChartGroup/v1
metadata:
  schema: metadata/Document/v1
  name: glance-components
data:
  description: "OpenStack Glance Components"
  sequenced: False
  chart_group:
    - glance
---
schema: armada/ChartGroup/v1
metadata:
  schema: metadata/Document/v1
  name: glance-infra-services
data:
  description: "Glance Infra Services"
  sequenced: False
  chart_group:
    - etcd
    - rabbitmq
---
schema: armada/Manifest/v1
metadata:
  schema: metadata/Document/v1
  name: armada-manifest
data:
  release_prefix: armada
  chart_groups:
    - glance-infra-services
    - glance-components
```



## Install Brigade

### Build Brigade binaries and install brigade and brigade projects

The following are installed
```
brigade
  Brigade server
empty-testbed
  Test project to test our connection
kollabrigade
  https://github.com/lukepatrick/KollaBrigade
helmbrigade
  https://github.com/lukepatrick/HelmBrigade
kashti
  UI for brigade
  https://github.com/Azure/kashti

To build the brigade binaries first time and install brigade
```bash
$ ./brigade-setup-recur.sh build
```

To only install brigade and skip building the brigade binaries
```bash
$ ./brigade-setup-recur.sh
```

## Accessing Brigade UI(kashti)

### Setup access of kashti url using NodePort

Kashti url is setup to use NodePort on executing brigade-setup-recur.sh

Following is the brief description of setting manually

Install Brigade with api service type as LoadBalancer
```bash
$ helm install brigade/brigade --name brigade --set api.service.type=LoadBalancer
```

Install kashti with the NodePort assigned for brigade api
```bash
$ helm install -n kashti ./charts/kashti --set service.type=LoadBalancer --set brigade.apiServer=http://<HostIP>:<BrigadeNodePort>
# <HostIP> is the IP of the host running Brigade
# <BrigadeNodePort> is the host port assigned to brigade api service from the following command
$ kubectl get svc | grep brigade-brigade-api | awk -F ":|/" {'print $2'}
```

The kashti UI can be accessed as
```
http://<HostIP>:<KashtNodePort>
# <HostIP> is the IP of the host running Brigade
# <KashtNodePort> is the host port assigned to kashti service from the following command
$ kubectl get svc | grep kashti-kashti | awk -F ":|/" {'print $2'}
```

## Deploy and test keystone

### Run brigade job

Keystone service is dependent on mariadb and memcached
Deploy keystone(including dependencies) and test deployment
Helm test are run to test the deployment

brigade-keystone.js
```bash
const HELM_VERSION = "v2.7.2"
  /*
    v2.7.2, latest
    v2.6.1,
    v2.5.1,
    v2.4.2,
    v2.3.1,
    v2.2.3,
    v2.1.3,
    v2.0.2
  */

const CONTAINER = "lachlanevenson/k8s-helm:" + HELM_VERSION

const { events, Job } = require("brigadier")
const util = require('util')

events.on("exec", (e, p) => {

  // env info
  console.log("==> Project " + p.name + " clones the repo at " + p.repo.cloneURL)
  console.log("==> Event " + e.type + " caused by " + e.provider)

  // create job with name and container image to use
  var helm_job = new Job("helm-job", CONTAINER) // runs helm_job
  var docker_deploy_job = new Job("docker-deploy-job", "docker:dind") // run docker
  var helm_test_job = new Job("helm-test-job", CONTAINER) // run helm

  helm_job.storage.enabled = false
  docker_deploy_job.storage.enabled = false
  helm_test_job.storage.enabled = false

  //helm_job.timeout = 3600000
  docker_deploy_job.timeout = 3600000

  // allow docker socket
  helm_job.docker.enabled = true
  docker_deploy_job.docker.enabled = true
  helm_test_job.docker.enabled = true

  //set up tasks
  helm_job.tasks = [] //init empty tasks
  docker_deploy_job.tasks = []
  helm_test_job.tasks = []

  helm_job.tasks.push("ls /src") // add first task
  helm_job.tasks.push("helm ls")
  //helm_job.tasks.push("helm repo list") // doesn't work, wrong user scope and host filesystem
  //helm_job.tasks.push("helm delete --purge glance") // works
  //helm_job.tasks.push("helm test glance --cleanup") / works

  docker_deploy_job.tasks.push("docker images")
  docker_deploy_job.tasks.push("docker ps -a")
  docker_deploy_job.tasks.push("docker exec armada armada tiller --status")
  //docker_deploy_job.tasks.push("docker exec armada armada apply /examples/openstack-master-aio.yaml")
  docker_deploy_job.tasks.push("docker exec armada armada tiller --releases")
  docker_deploy_job.tasks.push("docker exec armada armada apply /examples/keystone.yaml --debug")
  docker_deploy_job.tasks.push("docker exec armada armada tiller --releases")
  //docker_deploy_job.tasks.push("sleep 30")
  //docker_deploy_job.tasks.push("docker exec armada armada test --release=armada-keystone") // running this after deployment gives a index error while parsing results

  helm_test_job.tasks.push("ls /src") // add first task
  helm_test_job.tasks.push("helm test armada-keystone --cleanup")

  //set up ENV
  // helm_job.env = helm_job.env = {
  //   "HELM_HOST": ""
  // }


  console.log("==> Set up tasks, env, Job ")
  //debug only
  //console.log(helm_job)

  console.log("==> Running helm_job Job")

  // run Start Job, get Promise and print results
  helm_job.run().then( resultStart => {
    //debug only
    console.log("==> Start Job Results")
    console.log(resultStart.toString())
    console.log("==> Start Job Done")
    console.log("==> Running docker_deploy_job Job")

    docker_deploy_job.run().then( resultDockerDeploy => {
      //debug only
      console.log("==> Docker Deploy Job Results")
      console.log(resultDockerDeploy.toString())
      console.log("==> Docker Deploy Job Done")
      helm_test_job.run().then( resultHelmTest => {
        //debug only
        console.log("==> Helm Test Job Results")
        console.log(resultHelmTest.toString())
        console.log("==> Helm Test Job Done")
        })
      })
    })

})


events.on("error", (e) => {
    console.log("Error event " + util.inspect(e, false, null) )
    console.log("==> Event " + e.type + " caused by " + e.provider + " cause class" + e.cause + e.cause.reason)
})

events.on("after", (e) => {
    console.log("After event fired " + util.inspect(e, false, null) )
})
```

Execute the brigade script
```bash
$ brig run lukepatrick/HelmBrigade -f brigade-keystone.js
```

## Cleanup

Execute the cleanup script to remove Keystone(and dependencies)
The script also deletes footprint of any failed brigade jobs
```bash
$ ./cleanup-keystone.sh
```


## Deploy and test Glance

### Prerequisite

Keystone service should be running. Refer "Deploy and test keystone" to deploy Keystone service

### Run brigade job

Glance service is dependent on etcd and rabbitmq
Glance also requires Keystone service to be running for authentication.

Glance service is deployed and tested with the folowing brigade script

brigade-glance.js
```
const HELM_VERSION = "v2.7.2"
  /*
    v2.7.2, latest
    v2.6.1,
    v2.5.1,
    v2.4.2,
    v2.3.1,
    v2.2.3,
    v2.1.3,
    v2.0.2
  */

const CONTAINER = "lachlanevenson/k8s-helm:" + HELM_VERSION

const { events, Job } = require("brigadier")
const util = require('util')

events.on("exec", (e, p) => {

  // env info
  console.log("==> Project " + p.name + " clones the repo at " + p.repo.cloneURL)
  console.log("==> Event " + e.type + " caused by " + e.provider)

  // create job with name and container image to use
  var docker_deploy_job = new Job("docker-deploy-job", "docker:dind") // run docker
  var helm_test_job = new Job("helm-test-job", CONTAINER) // run helm

  docker_deploy_job.storage.enabled = false
  helm_test_job.storage.enabled = false

  // allow docker socket
  docker_deploy_job.docker.enabled = true
  helm_test_job.docker.enabled = true

  //set up tasks
  docker_deploy_job.tasks = []
  helm_test_job.tasks = []

  docker_deploy_job.tasks.push("docker version")
  docker_deploy_job.tasks.push("docker exec armada armada tiller --status")
  // Keystone service should be running before deploying glance
  docker_deploy_job.tasks.push("docker exec armada armada apply /examples/glance.yaml --debug")
  docker_deploy_job.tasks.push("docker exec armada armada tiller --releases")

  helm_test_job.tasks.push("echo In helm test job")
  helm_test_job.tasks.push("helm test armada-glance --cleanup")

  //set up ENV
  // helm_job.env = helm_job.env = {
  //   "HELM_HOST": ""
  // }


  // run Deploy Job, get Promise and print results
  docker_deploy_job.run().then( resultDockerDeploy => {
    //debug only
    console.log("==> Docker Deploy Job Results")
    console.log(resultDockerDeploy.toString())
    console.log("==> Docker Deploy Job Done")
    helm_test_job.run().then( resultHelmTest => {
      //debug only
      console.log("==> Helm Test Job Results")
      console.log(resultHelmTest.toString())
      console.log("==> Helm Test Job Done")
      })
    })

})


events.on("error", (e) => {
    console.log("Error event " + util.inspect(e, false, null) )
    console.log("==> Event " + e.type + " caused by " + e.provider + " cause class" + e.cause + e.cause.reason)
})

events.on("after", (e) => {
    console.log("After event fired " + util.inspect(e, false, null) )
})
```

Execute the brigade script
```bash
$ brig run lukepatrick/HelmBrigade -f brigade-glance.js
```

## Cleanup

Execute the cleanup script to remove Glance(and dependencies)
The script also deletes footprint of any failed brigade jobs
```bash
$ ./cleanup-glance.sh
```

