pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds() // Prevents "Dependency Lock" from multiple builds hitting the same state file
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(false) // Changed to false to ensure we have the code
    }

    parameters {
        booleanParam(name: 'RUN_PLAN', defaultValue: true, description: 'Run terraform plan')
        booleanParam(name: 'RUN_APPLY', defaultValue: false, description: 'Run terraform apply')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval before apply')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_LOG = 'INFO'
        SNYK_TOKEN = credentials('snyk-token')
    }

    stages {
        stage('Initialize & Scan') {
            steps {
                checkout scm
                sh 'terraform version'
                // Init with backend=false for a quick validation/scan check
                sh 'terraform init -backend=false -input=false'
                sh 'terraform validate'
            }
        }

        stage('Security - Snyk Scans') {
            parallel {
                stage('Snyk Code') {
                    steps {
                        sh 'snyk code test --severity-threshold=high || true'
                    }
                }
                stage('Snyk IaC') {
                    steps {
                        sh 'snyk iac test . --severity-threshold=high'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            // This will run on Webhook or if RUN_PLAN is true
            when {
                anyOf {
                    expression { params.RUN_PLAN }
                    expression { params.RUN_APPLY }
                    triggeredBy 'GitHubPushTrigger' 
                }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        terraform init -input=false
                        terraform plan -out=tfplan -input=false
                    '''
                }
            }
        }

        stage('Manual Approval') {
            // Only stop if we intend to APPLY and AUTO_APPROVE is off
            when {
                allOf {
                    expression { params.RUN_APPLY || triggeredBy('GitHubPushTrigger') }
                    expression { !params.AUTO_APPROVE }
                }
            }
            steps {
                input message: "Review the plan for ${env.JOB_NAME}. Deploy to AWS?", ok: "Deploy Now"
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
            // Clean up the plan file and results
            archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
            deleteDir() 
        }
        failure {
            echo "Deployment failed. Check Cloudflare tunnel and AWS credentials."
        }
    }
}
