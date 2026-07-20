data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "infrapro" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = file(var.public_key_path)

  tags = {
    Name = "${var.project_name}-${var.environment}-key"
  }
}

resource "aws_instance" "developer_vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.developer_vm.id]
  key_name                    = aws_key_pair.infrapro.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 15
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-developer-vm"
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = templatefile(
    "${path.module}/templates/inventory.tpl",
    {
      public_ip        = aws_instance.developer_vm.public_ip
      private_key_path = var.private_key_path
    }
  )
}

resource "terraform_data" "run_ansible" {
  depends_on = [
    aws_instance.developer_vm,
    local_file.ansible_inventory
  ]

  triggers_replace = [
    aws_instance.developer_vm.id,
    sha256(file("${path.module}/../ansible/playbook.yml"))
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for EC2 SSH service..."
      sleep 30

      cd ${path.module}/../ansible

      echo "Testing Ansible connectivity..."
      ansible all -m ping

      echo "Running Ansible playbook..."
      ansible-playbook playbook.yml
    EOT
  }
}