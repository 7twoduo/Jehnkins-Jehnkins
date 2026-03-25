pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(false)
    }

    parameters {
        booleanParam(name: 'RUN_DESTROY', defaultValue: false, description: 'Run terraform destroy')
        booleanParam(name: 'AUTO_APPROVE_DESTROY', defaultValue: false, description: 'Skip manual approval before destroy')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_LOG = 'INFO'
    }

    stages {
        stage('Initialize & Validate') {
            steps {
                checkout scm
                sh 'terraform version'
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh 'terraform init'
                }
                sh 'terraform validate'
            }
        }

        stage('Terraform Destroy Plan') {
            when {
                expression { params.RUN_DESTROY }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        terraform init
                        terraform plan -destroy -out=tfdestroyplan
                        terraform show tfdestroyplan
                    '''
                }
            }
        }

        stage('Manual Approval - Destroy') {
            when {
                allOf {
                    expression { params.RUN_DESTROY }
                    expression { !params.AUTO_APPROVE_DESTROY }
                }
            }
            steps {
                input message: "Destroy infrastructure for ${env.JOB_NAME}?", ok: "Destroy Now"
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.RUN_DESTROY }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        terraform init
                        terraform apply -auto-approve tfdestroyplan
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'tfdestroyplan', allowEmptyArchive: true
            deleteDir()
        }
        failure {
            echo "Destroy failed. Check Terraform state, AWS credentials, and backend access."
        }
    }
}
