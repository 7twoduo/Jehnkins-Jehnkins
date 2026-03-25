pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(name: 'RUN_PLAN', defaultValue: false, description: 'Run terraform plan')
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

        stage('Verify Tools') {
            steps {
                sh '''
                    set -eux
                    git --version
                    terraform version
                    snyk --version
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                sh '''
                    set -eux
                    terraform init -backend=false
                '''
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

        stage('Snyk Code') {
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

        stage('Snyk IaC') {
            steps {
                sh '''
                    set -eux
                    snyk iac test . --severity-threshold=high
                '''
            }
        }

        stage('Snyk OSS') {
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
            when {
                expression { params.RUN_PLAN }
            }
            steps {
                sh '''
                    set -eux
                    terraform plan
                '''
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
    }
}
