[developer_vm]
${public_ip}

[developer_vm:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=${private_key_path}
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'