const HELM_VERSION = "v2.5.1"
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
  var docker_job = new Job("docker-job", "docker:dind") // run docker

  helm_job.storage.enabled = false
  docker_job.storage.enabled = false

  //helm_job.timeout = 3600000
  docker_job.timeout = 3600000
  
  // allow docker socket
  helm_job.docker.enabled = true
  docker_job.docker.enabled = true

  //set up tasks
  helm_job.tasks = [] //init empty tasks
  docker_job.tasks = []

  helm_job.tasks.push("ls /src") // add first task
  helm_job.tasks.push("helm ls") 
  //helm_job.tasks.push("helm repo list") // doesn't work, wrong user scope and host filesystem
  //helm_job.tasks.push("helm delete --purge glance") // works
  //helm_job.tasks.push("helm test glance --cleanup")

  docker_job.tasks.push("docker images")
  docker_job.tasks.push("docker ps -a")
  docker_job.tasks.push("docker exec armada armada tiller --status")
  docker_job.tasks.push("docker exec armada armada tiller --releases")
  docker_job.tasks.push("docker exec armada armada apply /examples/openstack-master-aio.yaml")
  docker_job.tasks.push("docker exec armada armada tiller --releases")
  //docker_job.tasks.push("docker exec armada armada apply /examples/keystone-manifest.yaml")
  //docker_job.tasks.push("docker exec armada armada tiller --releases")
  //docker_job.tasks.push("docker exec armada armada test --release=keystone")

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
    console.log("==> Running Push Job")
    console.log("==> Running docker_job Job")

    docker_job.run().then( resultDocker => {
      //debug only
      console.log("==> Docker Job Results")
      console.log(resultDocker.toString())
      console.log("==> Docker Job Done")
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
