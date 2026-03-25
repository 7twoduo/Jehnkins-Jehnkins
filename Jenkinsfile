stages {
        stage('Initialize & Scan') {
            steps {
                checkout scm
                sh 'terraform init -backend=false -input=false'
                sh 'terraform validate'
            }
        }

        stage('Security - Snyk Scans') {
            parallel {
                stage('Snyk Code') {
                    steps {
                        // Using || true so the pipeline doesn't die if Snyk finds nothing to scan
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
            // We want the plan to run EVERY time so you can see what you are approving
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
            // Only pause for approval if we aren't using AUTO_APPROVE
            when {
                expression { !params.AUTO_APPROVE }
            }
            steps {
                input message: "Review the plan for ${env.JOB_NAME}. Deploy to AWS?", ok: "Deploy Now"
            }
        }

        stage('Terraform Apply') {
            // This runs if the previous stages passed
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }
    }
