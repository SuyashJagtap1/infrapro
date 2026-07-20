resource "aws_security_group" "developer_vm" {
  name        = "${var.project_name}-${var.environment}-developer-sg"
  description = "Security group for InfraPro developer VM"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH access from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Application access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow outbound connectivity"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-developer-sg"
  }
}