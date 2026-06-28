output "instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "private_ip" {
  description = "Private IP of the Jenkins instance"
  value       = aws_instance.jenkins.private_ip
}

output "security_group_id" {
  description = "Security Group ID for Jenkins"
  value       = aws_security_group.jenkins.id
}

output "iam_role_arn" {
  description = "IAM Role ARN attached to the Jenkins instance"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_url" {
  description = "Jenkins UI URL (private IP)"
  value       = "http://${aws_instance.jenkins.private_ip}:8080"
}
