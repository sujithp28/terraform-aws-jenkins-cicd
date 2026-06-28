#!/bin/bash
set -euxo pipefail

yum update -y

# Java 17
yum install -y java-17-amazon-corretto-headless

# Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# Docker
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins

# AWS CLI v2
curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip
unzip -q /tmp/awscli.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscli.zip /tmp/aws

# kubectl
curl -sSLO https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure kubectl for EKS
%{ if eks_cluster_name != "" }
aws eks update-kubeconfig --name ${eks_cluster_name} --region ${aws_region}
mkdir -p /var/lib/jenkins/.kube
cp /root/.kube/config /var/lib/jenkins/.kube/config
chown -R jenkins:jenkins /var/lib/jenkins/.kube
%{ endif }

echo 'Jenkins setup complete' | tee /var/log/jenkins-setup.log
