def erecipients = "devel@euro-linux.com"
def ebody = """
${currentBuild.fullDisplayName} / ${currentBuild.number}
Check url: ${currentBuild.absoluteUrl}.
"""

def supported_8_machine_names = ["centos8", "generic-rhel8", "oracle8", "rockylinux8"]
def legacy_8_machine_names = ["centos8-4", "rockylinux8-4"]

pipeline {
    agent {
        node {
          label 'libvirt'
        }
    }
    environment {
    }
    stages {
	stage("Migrate supported systems to AlmaLinux 8"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sleep(5 * Math.random())
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh -f -v -w && sudo poweroff\" || true")
                                  sleep(5 * Math.random())
                                  sh("vagrant up $vagrant_machine")
                                  sleep(120)
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
	stage("Migrate legacy systems to AlmaLinux 8"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel legacy_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sleep(5 * Math.random())
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh -f -v -w && sudo poweroff\" || true")
                                  sleep(5 * Math.random())
                                  sh("vagrant up $vagrant_machine")
                                  sleep(120)
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
    }
    post {
        success {
            echo 'Pipeline finished'
        }
        failure {
            echo 'Pipeline failed'
                mail to: erecipients,
                     subject: "Pipeline failed: ${currentBuild.fullDisplayName}",
                     body: ebody
        }
        always {
            echo 'Running "vagrant destroy -f"'
            sh("vagrant destroy -f")
            cleanWs()
        }
    }
}

