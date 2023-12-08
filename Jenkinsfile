pipeline {

    agent {
        label 'podman'
    }

    environment {
        IMAGE_TAG = "${env.BRANCH_NAME == "master" ? "latest" : "${env.BRANCH_NAME}_${env.BUILD_ID}" }"
        ORG_NAME = "nixime"
        PKG_NAME = "nixdvr"
    }


    stages {
        stage('Prepare') {
            steps {
                deleteDir()
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo "Building Branch..."
                sh "podman build --rm -t ${PKG_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Test') {
            steps {
                echo "No Testing..."
            }
        }

        stage("SonarQube") {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner';
                    withSonarQubeEnv('sonarqube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'cred_jenkins-nexus3_uid-pass', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                        echo "Deploying Build..."

                        def IMAGE_ID = sh (
                            returnStdout: true,
                            script: "podman images ${PKG_NAME}:${env.IMAGE_TAG} --format \"{{.ID}}\""
                        ).trim()
                        echo "IMAGE ID: ${IMAGE_ID}"

                        sh "echo ${PASSWORD} | podman login -u ${USERNAME} --password-stdin ${env.ARTIFACTORY_URL}"
                        sh "podman push ${PKG_NAME}:${IMAGE_TAG} ${env.ARTIFACTORY_URL}/${ORG_NAME}/${PKG_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }

    }

}