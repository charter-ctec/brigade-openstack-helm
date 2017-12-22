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
