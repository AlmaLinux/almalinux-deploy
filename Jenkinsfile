RETRY = '3'
TIMEOUT = '20' // Adapt it based on the hardware resources and internet connection speed of your Jenkins agent.

pipeline {
    agent {
        label 'x86_64 && bm'
    }
    options {
        timestamps()
        parallelsAlwaysFailFast()
    }
    environment {
        VAGRANT_NO_COLOR = '1'
    }
    stages {
        stage('EL9') {
            matrix {
                axes {
                    axis {
                        name 'EL9'
                        values 'oracle9', 'rhel9', 'rocky9'
                    }
                }
                stages {
                    stage('EL9 to AlmaLinux OS 9') {
                        steps {
                            retry(RETRY) {
                                timeout(time: TIMEOUT, unit: 'MINUTES') {
                                    sh script: 'vagrant up $EL9',
                                        label: 'Create EL9 Machine'
                                    sh script: 'vagrant ssh $EL9 -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh\"',
                                        label: 'Start AlmaLinux Deploy'
                                    sh script: 'vagrant destroy $EL9 -f',
                                        label: 'Destroy the machine'
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('EL8') {
            matrix {
                axes {
                    axis {
                        name 'EL8'
                        values 'oracle8', 'rhel8', 'rocky8'
                    }
                }
                stages {
                    stage('EL8 to AlmaLinux 8') {
                        steps {
                            retry(RETRY) {
                                timeout(time: TIMEOUT, unit: 'MINUTES') {
                                    sh script: 'vagrant up $EL8',
                                        label: 'Create EL8 machine'
                                    sh script: 'vagrant ssh $EL8 -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh\"',
                                        label: 'Start AlmaLinux Deploy'
                                    sh script: 'vagrant destroy $EL8 -f',
                                        label: 'Destroy the machine'
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('CentOS Stream') {
            matrix {
                axes {
                    axis {
                        name 'CS'
                        values 'centos8stream', 'centos9stream'
                    }
                }
                stages {
                    stage('CS to AlmaLinux') {
                        steps {
                            retry(RETRY) {
                                timeout(time: TIMEOUT, unit: 'MINUTES') {
                                    sh script: 'vagrant up $CS',
                                        label: 'Create CentOS Stream machine'
                                    sh script: 'vagrant ssh $CS -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh -d\"',
                                        label: 'Start AlmaLinux Deploy'
                                    sh script: 'vagrant destroy $CS -f',
                                        label: 'Destroy the machine'
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('EL8.5') {
            matrix {
                axes {
                    axis {
                        name 'EL85'
                        values 'centos8-5', 'oracle8-5', 'rhel8-5', 'rocky8-5'
                    }
                }
                stages {
                    stage('EL8.5 to AlmaLinux 8') {
                        steps {
                            retry(RETRY) {
                                timeout(time: TIMEOUT, unit: 'MINUTES') {
                                    sh script: 'vagrant up $EL85',
                                        label: 'Create EL8.5 machine'
                                    sh script: 'vagrant ssh $EL85 -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh\"',
                                        label: 'Start AlmaLinux Deploy'
                                    sh script: 'vagrant destroy $EL85 -f',
                                        label: 'Destroy the machine'
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('EL8.4') {
            matrix {
                axes {
                    axis {
                        name 'EL84'
                        values 'centos8-4', 'oracle8-4', 'rhel8-4', 'rocky8-4'
                    }
                }
                stages {
                    stage('EL8.4 to AlmaLinux 8') {
                        steps {
                            retry(RETRY) {
                                timeout(time: TIMEOUT, unit: 'MINUTES') {
                                    sh script: 'vagrant up $EL84',
                                        label: 'Create EL8.4 machine'
                                    sh script: 'vagrant ssh $EL84 -c \"sudo /home/vagrant/almalinux-deploy/almalinux-deploy.sh\"',
                                        label: 'Start AlmaLinux Deploy'
                                    sh script: 'vagrant destroy $EL84 -f',
                                        label: 'Destroy the machine'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            sh script: 'vagrant destroy -f',
                label: 'Destroy All Machines'
            cleanWs()
        }
    }
}
