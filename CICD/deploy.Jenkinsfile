pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(false)
    }

    parameters {
        booleanParam(name: 'RUN_PLAN', defaultValue: true, description: 'Run terraform plan')
        booleanParam(name: 'RUN_APPLY', defaultValue: false, description: 'Run terraform apply')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval before apply')
        booleanParam(name: 'RUN_CONTAINER_SCAN', defaultValue: false, description: 'Build and scan a container image with Trivy')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
        string(name: 'JIRA_ISSUE', defaultValue: '', description: 'Optional Jira ticket key, for example DEV-123')
        string(name: 'JIRA_SITE', defaultValue: 'YOUR_JIRA_SITE', description: 'Jira site name configured in Jenkins')
        string(name: 'NOTIFY_EMAIL', defaultValue: 'your@gmail.com', description: 'Email address for approval notifications')
        string(name: 'IMAGE_NAME', defaultValue: 'local/app:jenkins', description: 'Container image name for local scan')
       
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_LOG = 'INFO'
        SNYK_TOKEN = credentials('snyk-token')
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
            when {
                anyOf {
                    expression { params.RUN_PLAN }
                    expression { params.RUN_APPLY }
                    triggeredBy 'GitHubPushTrigger'
                    triggeredBy 'GitHubPushCause'
                }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        terraform init
                        terraform plan -out=tfplan
                        terraform show tfplan
                    '''
                }
            }
        }
        

        stage('Manual Approval') {
            when {
                anyOf {
                    expression { params.RUN_APPLY }
                    triggeredBy 'GitHubPushCause'
                    triggeredBy 'GitHubPushTrigger'
                }
            }
            steps {
                script {
                    if (params.JIRA_ISSUE?.trim()) {
                        def jiraComment = [
                            body: """Deployment is waiting for manual approval.

Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Stage: Manual Approval
Build URL: ${env.BUILD_URL}
"""
                        ]

                        jiraAddComment(
                            site: params.JIRA_SITE,
                            idOrKey: params.JIRA_ISSUE,
                            input: jiraComment
                        )
                    }
                }

                emailext(
                    to: params.NOTIFY_EMAIL,
                    subject: "approval needed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """Jenkins is waiting for deployment approval.

Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Stage: Manual Approval
Build URL: ${env.BUILD_URL}

Open Jenkins and click Proceed or Abort.
"""
                )

                input message: "Review the plan for ${env.JOB_NAME}. Deploy to AWS?", ok: "Deploy Now"
            }
        }

        stage('Terraform Apply') {
            when {
                anyOf {
                    expression { params.RUN_APPLY }
                    triggeredBy 'GitHubPushCause'
                    triggeredBy 'GitHubPushTrigger'
                }
            }
            steps {
                withAWS(credentials: 'aws-prod', region: params.AWS_REGION) {
                    sh '''
                        terraform init
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
            deleteDir()
        }
        failure {
            echo "Deployment failed. Check Cloudflare tunnel and AWS credentials."
        }
    }
}
