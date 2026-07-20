pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform operation to execute')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'test'], description: 'Deployment environment')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS deployment region')
        choice(name: 'INSTANCE_TYPE', choices: ['t3.micro', 't3.small'], description: 'EC2 instance type')
        string(name: 'ALLOWED_SSH_CIDR', defaultValue: '', description: 'Public IP in CIDR format, for example 103.25.45.10/32')
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'
        TF_DIR           = 'terraform'
        ANSIBLE_DIR      = 'ansible'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Parameters') {
            steps {
                script {
                    def sshCidr = params.ALLOWED_SSH_CIDR?.trim()

                    if (!sshCidr) {
                        error('ALLOWED_SSH_CIDR must be provided.')
                    }

                    if (!(sshCidr ==~ /^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$/)) {
                        error('ALLOWED_SSH_CIDR must use CIDR format, for example 103.25.45.10/32.')
                    }

                    def cidrParts = sshCidr.split('/')
                    def octets = cidrParts[0].split('\\.').collect { it as Integer }
                    def prefix = cidrParts[1] as Integer

                    if (octets.any { it < 0 || it > 255 } || prefix < 0 || prefix > 32) {
                        error('ALLOWED_SSH_CIDR contains an invalid IPv4 address or prefix.')
                    }
                }
            }
        }

        stage('Verify WSL and Tools') {
            steps {
                bat '''
                    @echo off
                    wsl.exe bash -lc "set -e; git --version; terraform version; ansible --version; aws --version; ssh -V"
                '''
            }
        }

        stage('Prepare SSH Key') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'infrapro-ssh-key',
                        keyFileVariable: 'JENKINS_PRIVATE_KEY',
                        usernameVariable: 'SSH_USERNAME'
                    )
                ]) {
                    bat '''
                        @echo off
                        if not exist "%WORKSPACE%\\.ssh" mkdir "%WORKSPACE%\\.ssh"
                        copy /Y "%JENKINS_PRIVATE_KEY%" "%WORKSPACE%\\.ssh\\infrapro-key" >nul
                        wsl.exe bash -lc "set -e; KEY=$(wslpath -a '%WORKSPACE%\\.ssh\\infrapro-key'); chmod 600 \"$KEY\"; ssh-keygen -y -f \"$KEY\" > \"${KEY}.pub\"; chmod 644 \"${KEY}.pub\""
                    '''
                }
            }
        }

        stage('Verify AWS Credentials') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    bat '''
                        @echo off
                        set "WSLENV=AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY:AWS_REGION"
                        wsl.exe bash -lc "set -e; aws sts get-caller-identity"
                    '''
                }
            }
        }

        stage('Terraform Format') {
            steps {
                bat '''
                    @echo off
                    wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')\"; terraform -chdir=${TF_DIR} fmt -check -recursive"
                '''
            }
        }

        stage('Terraform Initialize') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    bat '''
                        @echo off
                        set "WSLENV=AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY:AWS_REGION:TF_IN_AUTOMATION:TF_INPUT"
                        wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')\"; terraform -chdir=${TF_DIR} init -input=false"
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                bat '''
                    @echo off
                    wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')\"; terraform -chdir=${TF_DIR} validate"
                '''
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    bat '''
                        @echo off
                        set "WSLENV=AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY:AWS_REGION:TF_IN_AUTOMATION:TF_INPUT"
                        wsl.exe bash -lc "set -e; ROOT=$(wslpath -a '%WORKSPACE%'); cd \"$ROOT\"; terraform -chdir=${TF_DIR} plan -input=false -var=\"aws_region=%AWS_REGION%\" -var=\"environment=%ENVIRONMENT%\" -var=\"instance_type=%INSTANCE_TYPE%\" -var=\"allowed_ssh_cidr=%ALLOWED_SSH_CIDR%\" -var=\"public_key_path=$ROOT/.ssh/infrapro-key.pub\" -var=\"private_key_path=$ROOT/.ssh/infrapro-key\" -out=tfplan"
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    bat '''
                        @echo off
                        set "WSLENV=AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY:AWS_REGION:TF_IN_AUTOMATION:TF_INPUT"
                        wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')\"; terraform -chdir=${TF_DIR} apply -input=false -auto-approve tfplan"
                    '''
                }
            }
        }

        stage('Wait for EC2') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                bat '''
                    @echo off
                    wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')\"; echo 'Waiting for EC2 SSH service...'; for attempt in $(seq 1 30); do if ansible all -i ansible/inventory.ini -m ping; then echo 'EC2 is reachable.'; exit 0; fi; echo \"Attempt ${attempt}/30 failed. Retrying...\"; sleep 10; done; echo 'EC2 did not become reachable.'; exit 1"
                '''
            }
        }

        stage('Run Ansible') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                bat '''
                    @echo off
                    wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')/${ANSIBLE_DIR}\"; ansible-playbook --syntax-check playbook.yml; ansible-playbook playbook.yml"
                '''
            }
        }

        stage('Validate Developer VM') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                bat '''
                    @echo off
                    wsl.exe bash -lc "set -e; cd \"$(wslpath -a '%WORKSPACE%')\"; ansible developer_vm -i ansible/inventory.ini -b -m shell -a 'java --version && mvn --version && git --version && cat /opt/royal-hotel/developer-workspace/README.txt'"
                '''
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                input(message: 'Destroy all InfraPro AWS resources?', ok: 'Destroy')

                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    bat '''
                        @echo off
                        set "WSLENV=AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY:AWS_REGION:TF_IN_AUTOMATION:TF_INPUT"
                        wsl.exe bash -lc "set -e; ROOT=$(wslpath -a '%WORKSPACE%'); cd \"$ROOT\"; terraform -chdir=${TF_DIR} destroy -input=false -var=\"aws_region=%AWS_REGION%\" -var=\"environment=%ENVIRONMENT%\" -var=\"instance_type=%INSTANCE_TYPE%\" -var=\"allowed_ssh_cidr=%ALLOWED_SSH_CIDR%\" -var=\"public_key_path=$ROOT/.ssh/infrapro-key.pub\" -var=\"private_key_path=$ROOT/.ssh/infrapro-key\" -auto-approve"
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts(artifacts: 'terraform/tfplan', allowEmptyArchive: true)
            bat '''
                @echo off
                if exist "%WORKSPACE%\\.ssh" rmdir /S /Q "%WORKSPACE%\\.ssh"
            '''
        }
        success {
            echo 'InfraPro pipeline completed successfully.'
        }
        failure {
            echo 'InfraPro pipeline failed. Check the failed stage and console output.'
        }
    }
}
