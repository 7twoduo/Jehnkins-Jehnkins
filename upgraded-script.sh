#!/usr/bin/env bash
set -euo pipefail

# --- config ---
APP_DIR="jenkins-admin"
IMAGE_NAME="my-jenkins-admin"
CONTAINER_NAME="jenkins-admin"
VOLUME_NAME="jenkins_home_admin"
JENKINS_ADMIN_ID="${JENKINS_ADMIN_ID:-admin}"
JENKINS_ADMIN_PASSWORD="${JENKINS_ADMIN_PASSWORD:-MakerTaker223!}"

mkdir -p "$APP_DIR/init.groovy.d"

# --- Dockerfile ---
cat > "$APP_DIR/Dockerfile" <<'EOF'
FROM jenkins/jenkins:lts-jdk21

USER root

# Base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    unzip \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform CLI
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.14.7/terraform_1.14.7_linux_amd64.zip -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/terraform \
    && rm -f /tmp/terraform.zip

# Install AWS CLI v2
RUN curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Docker CLI from Docker's Debian repo
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Snyk CLI (stable channel)
RUN curl -fsSL https://downloads.snyk.io/cli/stable/snyk-linux -o /usr/local/bin/snyk \
    && chmod +x /usr/local/bin/snyk

USER jenkins

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
EOF

# --- Groovy init script ---
cat > "$APP_DIR/init.groovy.d/01-create-admin.groovy" <<'EOF'
import jenkins.model.*
import hudson.security.*
import hudson.security.csrf.DefaultCrumbIssuer

def jenkins = Jenkins.get()

def username = System.getenv("JENKINS_ADMIN_ID") ?: "admin"
def password = System.getenv("JENKINS_ADMIN_PASSWORD") ?: "Admin123456!"

def realm = new HudsonPrivateSecurityRealm(false)

if (realm.getAllUsers().find { it.id == username } == null) {
    realm.createAccount(username, password)
}

jenkins.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(strategy)

jenkins.setCrumbIssuer(new DefaultCrumbIssuer(true))
jenkins.save()

println(">>> Jenkins admin bootstrap complete for user: ${username}")
EOF

cat > "$APP_DIR/plugins.txt" <<'EOF'
workflow-aggregator
git
credentials
credentials-binding
configuration-as-code

aws-credentials
pipeline-aws
ec2
amazon-ecs
codedeploy
aws-lambda
aws-codebuild
aws-bucket-credentials
aws-secrets-manager-secret-source
configuration-as-code-secret-ssm
aws-codepipeline
jenkins-cloudformation-plugin
aws-sam
pipeline-graph-view
terraform

kubernetes
google-storage-plugin
google-kubernetes-engine
gcp-java-sdk-auth
pipeline-gcp


snyk-security-scanner
sonar
aqua-security-scanner
aqua-microscanner
aqua-serverless

github
github-oauth
github-branch-source
pipeline-github
pipeline-githubnotify-step

maven-plugin
pipeline-maven
timestamper
publish-over-ssh
docker-workflow
dark-theme

email-ext
jira-steps
pipeline-input-notification
EOF

# --- build image ---
docker build -t "$IMAGE_NAME" "$APP_DIR"

# --- create volume if missing ---
docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1 || docker volume create "$VOLUME_NAME" >/dev/null

# --- remove old container if it exists ---
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# --- run container ---
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -e JENKINS_ADMIN_ID="$JENKINS_ADMIN_ID" \
  -e JENKINS_ADMIN_PASSWORD="$JENKINS_ADMIN_PASSWORD" \
  -v "$VOLUME_NAME:/var/jenkins_home" \
  "$IMAGE_NAME"

echo
echo "Jenkins is starting..."
echo "URL: http://localhost:8080"
echo "Username: $JENKINS_ADMIN_ID"
echo "Password: $JENKINS_ADMIN_PASSWORD"
echo
echo "Check logs with: docker logs -f $CONTAINER_NAME"
