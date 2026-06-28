data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name"; values = ["al2023-ami-*-x86_64"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
}

resource "aws_security_group" "jenkins" {
  name        = "${var.name}-sg"
  description = "Security group for Jenkins EC2 instance"
  vpc_id      = var.vpc_id

  ingress { description = "Jenkins UI"; from_port = 8080; to_port = 8080; protocol = "tcp"; cidr_blocks = var.allowed_cidr_blocks }
  ingress { description = "Jenkins JNLP"; from_port = 50000; to_port = 50000; protocol = "tcp"; cidr_blocks = var.allowed_cidr_blocks }
  egress  { description = "All outbound"; from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17"; Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"; Principal = { Service = "ec2.amazonaws.com" } }] })
  tags               = var.tags
}

resource "aws_iam_role_policy" "jenkins_ecr" {
  name = "${var.name}-ecr-policy"
  role = aws_iam_role.jenkins.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "ECRAccess"; Effect = "Allow"; Action = ["ecr:GetAuthorizationToken","ecr:BatchCheckLayerAvailability","ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:PutImage","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload","ecr:CreateRepository","ecr:DescribeRepositories"]; Resource = "*" },
      { Sid = "EKSAccess"; Effect = "Allow"; Action = ["eks:DescribeCluster","eks:ListClusters"]; Resource = "*" },
      { Sid = "S3Access"; Effect = "Allow"; Action = ["s3:GetObject","s3:PutObject","s3:ListBucket"]; Resource = "*" },
      { Sid = "SecretsAccess"; Effect = "Allow"; Action = ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"]; Resource = "*" },
      { Sid = "CloudWatchLogs"; Effect = "Allow"; Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]; Resource = "*" }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.jenkins.name
  tags = var.tags
}

resource "aws_instance" "jenkins" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  key_name               = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    aws_region       = var.aws_region
    eks_cluster_name = var.eks_cluster_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags      = merge(var.tags, { Name = "${var.name}-server" })
  lifecycle { ignore_changes = [ami] }
}

resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/aws/ec2/${var.name}"
  retention_in_days = 30
  tags              = var.tags
}
