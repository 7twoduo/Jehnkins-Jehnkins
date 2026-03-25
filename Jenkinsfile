pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(name: 'RUN_DEPLOY', defaultValue: false, description: 'Run terraform plan/apply and AWS deploy')
        booleanParam(name: 'RUN_SONAR', defaultValue: false, description: 'Run SonarQube if configured')
        booleanParam(name: 'RUN_AQUA', defaultValue: false, description: 'Placeholder until Aqua is configured')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '', description: 'AWS account ID for ECR')
        string(name: 'IMAGE_REPO', defaultValue: 'devsecops-demo', description: 'Docker image repo name')
        string(name: 'ECS_CLUSTER', defaultValue: '', description: 'Target ECS cluster')
        string(name: 'ECS_SERVICE', defaultValue: '', description: 'Target ECS service')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        SNYK_TOKEN = credentials('snyk-token')
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build / Toolchain') {
            steps {
                sh '''
                    set -eux
                    git --version
                    terraform version
                    snyk --version
                    docker --version || true
                '''
            }
        }

        stage('Test / Terraform Validate') {
            steps {
                sh '''
                    set -eux
                    terraform fmt -check
                    terraform init -backend=false
                    terraform validate
                '''
            }
        }

        stage('Security / Snyk Code') {
            steps {
                sh '''
                    set +e
                    snyk code test --severity-threshold=high
                    rc=$?
                    set -e

                    if [ "$rc" -eq 3 ]; then
                      echo "No supported source code detected for Snyk Code; skipping."
                      exit 0
                    fi

                    exit "$rc"
                '''
            }
        }

        stage('Security / Snyk IaC') {
            steps {
                sh '''
                    snyk iac test . --severity-threshold=high
                '''
            }
        }

        stage('Security / Snyk OSS') {
            steps {
                sh '''
                    set +e
                    snyk test --all-projects --severity-threshold=high
                    rc=$?
                    set -e

                    if [ "$rc" -eq 3 ]; then
                      echo "No supported package manifest detected for SCA; skipping."
                      exit 0
                    fi

                    exit "$rc"
                '''
            }
        }

        stage('Build / Container Image') {
            when {
                expression { fileExists('Dockerfile') }
            }
            steps {
                sh """
                    docker build -t ${params.IMAGE_REPO}:${env.IMAGE_TAG} .
                """
            }
        }

        stage('Security / Snyk Container') {
            when {
                expression { fileExists('Dockerfile') }
            }
            steps {
                sh """
                    snyk container test ${params.IMAGE_REPO}:${env.IMAGE_TAG} --severity-threshold=high
                """
            }
        }

        stage('Security / SonarQube') {
            when {
                expression { params.RUN_SONAR && fileExists('sonar-project.properties') }
            }
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'
                    withSonarQubeEnv('sonarqube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Security / Sonar Quality Gate') {
            when {
                expression { params.RUN_SONAR && fileExists('sonar-project.properties') }
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Security / Aqua') {
            when {
                expression { params.RUN_AQUA }
            }
            steps {
                echo 'Add Aqua scanner command here after Aqua endpoint/credentials are configured.'
            }
        }

        stage('Plan') {
            when {
                expression {
                    params.RUN_DEPLOY &&
                    (env.BRANCH_NAME == 'main' || (env.GIT_BRANCH ?: '').endsWith('/main'))
                }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-prod')]) {
                    sh '''
                        set -eux
                        terraform init
                        terraform plan -out=tfplan
                    '''
                }
            }
        }

        stage('Approval') {
            when {
                expression {
                    params.RUN_DEPLOY &&
                    (env.BRANCH_NAME == 'main' || (env.GIT_BRANCH ?: '').endsWith('/main'))
                }
            }
            steps {
                input message: 'Apply terraform and deploy to AWS?', ok: 'Deploy'
            }
        }

        stage('Deploy / Terraform Apply') {
            when {
                expression {
                    params.RUN_DEPLOY &&
                    (env.BRANCH_NAME == 'main' || (env.GIT_BRANCH ?: '').endsWith('/main'))
                }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-prod')]) {
                    sh '''
                        set -eux
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Deploy / Push to ECR + ECS') {
            when {
                expression {
                    params.RUN_DEPLOY &&
                    fileExists('Dockerfile') &&
                    params.AWS_ACCOUNT_ID?.trim() &&
                    params.ECS_CLUSTER?.trim() &&
                    params.ECS_SERVICE?.trim() &&
                    (env.BRANCH_NAME == 'main' || (env.GIT_BRANCH ?: '').endsWith('/main'))
                }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-prod')]) {
                    sh """
                        set -eux

                        aws ecr get-login-password --region ${params.AWS_REGION} | \
                          docker login --username AWS --password-stdin \
                          ${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com

                        docker tag ${params.IMAGE_REPO}:${env.IMAGE_TAG} \
                          ${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.IMAGE_REPO}:${env.IMAGE_TAG}

                        docker push \
                          ${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.IMAGE_REPO}:${env.IMAGE_TAG}

                        aws ecs update-service \
                          --cluster ${params.ECS_CLUSTER} \
                          --service ${params.ECS_SERVICE} \
                          --force-new-deployment \
                          --region ${params.AWS_REGION}
                    """
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline passed: build, test, security gates, and gated deploy flow are healthy.'
        }
        failure {
            echo 'Pipeline failed. Check the first failing stage and fix that before rerunning.'
        }
        always {
            archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
        }
    }
}
