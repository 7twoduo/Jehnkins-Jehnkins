pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        booleanParam(name: 'RUN_PLAN', defaultValue: true, description: 'Run terraform plan')
        booleanParam(name: 'RUN_APPLY', defaultValue: false, description: 'Run terraform apply')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval before apply')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        SNYK_TOKEN = credentials('snyk-token')
    }

    stages {
        stage('Initialize') {
            steps {
                checkout scm
                sh 'terraform init -backend=false -input=false'
                sh 'terraform validate'
            }
        }

        stage('Security Scans') {
            parallel {
                stage('Snyk Code') {
                    steps {
                        sh 'snyk code test --severity-threshold=high || true'
                    }
                }
                stage('Snyk IaC') {
                    steps {
                        sh 'snyk iac test . --severity-threshold=high || true'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh 'terraform init -input=false'
                    sh 'terraform plan -out=tfplan -input=false'
                }
            }
        }

        stage('Approval') {
            when {
                expression { params.RUN_APPLY || currentBuild.getBuildCauses().toString().contains('GitHubPushCause') }
                expression { !params.AUTO_APPROVE }
            }
            steps {
                input message: "Deploy ${env.JOB_NAME} to AWS?", ok: "Apply"
            }
        }

        stage('Terraform Apply') {
            when {
                anyOf {
                    expression { params.RUN_APPLY }
                    triggeredBy 'GitHubPushTrigger'
                }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
        }
    }
}
