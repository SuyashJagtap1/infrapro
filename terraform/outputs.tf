output "vpc_id" {
  description = "ID of the InfraPro VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the developer VM security group"
  value       = aws_security_group.developer_vm.id
}

output "instance_id" {
  description = "Developer EC2 instance ID"
  value       = aws_instance.developer_vm.id
}

output "instance_public_ip" {
  description = "Public IP address of the developer VM"
  value       = aws_instance.developer_vm.public_ip
}

output "ssh_command" {
  description = "Command to connect to the developer VM"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.developer_vm.public_ip}"
  sensitive   = true
}