pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(name: 'RUN_APPLY', defaultValue: false, description: 'Actually deploy infrastructure')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval before apply')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        SNYK_TOKEN = credentials('snyk-token')
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Build - Verify Tools') {
            steps {
                sh '''
                    set -eux
                    git --version
                    terraform version
                    snyk --version
                    aws --version
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        set -eux
                        terraform init -input=false
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                sh '''
                    set -eux
                    terraform validate
                '''
            }
        }

        stage('Security - Snyk Code') {
            steps {
                sh '''
                    set +e
                    snyk code test --severity-threshold=high
                    rc=$?
                    set -e

                    if [ "$rc" -eq 3 ]; then
                      echo "No supported code files for Snyk Code; skipping."
                      exit 0
                    fi

                    exit "$rc"
                '''
            }
        }

        stage('Security - Snyk IaC') {
            steps {
                sh '''
                    set -eux
                    snyk iac test . --severity-threshold=high
                '''
            }
        }

        stage('Security - Snyk OSS') {
            steps {
                sh '''
                    set +e
                    snyk test --all-projects --severity-threshold=high
                    rc=$?
                    set -e

                    if [ "$rc" -eq 3 ]; then
                      echo "No supported package manifest for Snyk OSS scan; skipping."
                      exit 0
                    fi

                    exit "$rc"
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        set -eux
                        aws sts get-caller-identity
                        terraform plan -input=false -out=tfplan
                    '''
                }
            }
        }

        stage('Approval') {
            when {
                allOf {
                    expression { params.RUN_APPLY }
                    expression { !params.AUTO_APPROVE }
                }
            }
            steps {
                input message: 'Apply Terraform changes?', ok: 'Deploy'
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.RUN_APPLY }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        set -eux
                        terraform apply -input=false -auto-approve tfplan
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline passed.'
        }
        failure {
            echo 'Pipeline failed.'
        }
        always {
            archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
            echo 'Pipeline execution finished.'
        }
    }
}
