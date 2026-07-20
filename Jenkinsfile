pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform operation to execute'
        )

        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'test'],
            description: 'Deployment environment'
        )

        string(
            name: 'AWS_REGION',
            defaultValue: 'ap-south-1',
            description: 'AWS deployment region'
        )

        choice(
            name: 'INSTANCE_TYPE',
            choices: ['t3.micro', 't3.small'],
            description: 'EC2 instance type'
        )

        string(
            name: 'ALLOWED_SSH_CIDR',
            defaultValue: '',
            description: 'Public IP in CIDR format, for example 103.25.45.10/32'
        )
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
                    if (!params.ALLOWED_SSH_CIDR?.trim()) {
                        error('ALLOWED_SSH_CIDR must be provided.')
                    }

                    if (!(params.ALLOWED_SSH_CIDR ==
                         ~ /^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$/)) {
                        error('ALLOWED_SSH_CIDR must use CIDR format, for example 103.25.45.10/32.')
                    }
                }
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                    set -e

                    git --version
                    terraform version
                    ansible --version
                    aws --version
                    ssh -V
                '''
            }
        }

        stage('Prepare SSH Key') {
            steps {
                sshagent(credentials: ['infrapro-ssh-key']) {
                    sh '''
                        set -e

                        mkdir -p "${WORKSPACE}/.ssh"

                        SSH_PRIVATE_KEY_PATH="$(find "${SSH_AUTH_SOCK%/*}" /tmp -type f 2>/dev/null \
                          | head -1 || true)"

                        ssh-add -L > "${WORKSPACE}/.ssh/infrapro-key.pub"

                        if [ ! -s "${WORKSPACE}/.ssh/infrapro-key.pub" ]; then
                            echo "Unable to create SSH public key."
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('Prepare Private Key') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'infrapro-ssh-key',
                        keyFileVariable: 'JENKINS_PRIVATE_KEY',
                        usernameVariable: 'SSH_USERNAME'
                    )
                ]) {
                    sh '''
                        set -e

                        mkdir -p "${WORKSPACE}/.ssh"
                        cp "${JENKINS_PRIVATE_KEY}" "${WORKSPACE}/.ssh/infrapro-key"
                        chmod 600 "${WORKSPACE}/.ssh/infrapro-key"

                        ssh-keygen -y \
                          -f "${WORKSPACE}/.ssh/infrapro-key" \
                          > "${WORKSPACE}/.ssh/infrapro-key.pub"

                        chmod 644 "${WORKSPACE}/.ssh/infrapro-key.pub"
                    '''
                }
            }
        }

        stage('Verify AWS Credentials') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh '''
                        set -e
                        aws sts get-caller-identity
                    '''
                }
            }
        }

        stage('Terraform Format') {
            steps {
                sh '''
                    terraform -chdir=${TF_DIR} fmt -check -recursive
                '''
            }
        }

        stage('Terraform Initialize') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh '''
                        terraform -chdir=${TF_DIR} init -input=false
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                sh '''
                    terraform -chdir=${TF_DIR} validate
                '''
            }
        }

        stage('Terraform Plan') {
            when {
                expression {
                    params.ACTION == 'plan' || params.ACTION == 'apply'
                }
            }

            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh """
                        terraform -chdir=${TF_DIR} plan \
                          -input=false \
                          -var="aws_region=${params.AWS_REGION}" \
                          -var="environment=${params.ENVIRONMENT}" \
                          -var="instance_type=${params.INSTANCE_TYPE}" \
                          -var="allowed_ssh_cidr=${params.ALLOWED_SSH_CIDR}" \
                          -var="public_key_path=${WORKSPACE}/.ssh/infrapro-key.pub" \
                          -var="private_key_path=${WORKSPACE}/.ssh/infrapro-key" \
                          -out=tfplan
                    """
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    params.ACTION == 'apply'
                }
            }

            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh '''
                        terraform -chdir=${TF_DIR} apply \
                          -input=false \
                          -auto-approve \
                          tfplan
                    '''
                }
            }
        }

        stage('Wait for EC2') {
            when {
                expression {
                    params.ACTION == 'apply'
                }
            }

            steps {
                sh '''
                    echo "Waiting for EC2 SSH service..."

                    for attempt in $(seq 1 30); do
                        if ansible all \
                          -i ansible/inventory.ini \
                          -m ping; then
                            echo "EC2 is reachable."
                            exit 0
                        fi

                        echo "Attempt ${attempt}/30 failed. Retrying..."
                        sleep 10
                    done

                    echo "EC2 did not become reachable."
                    exit 1
                '''
            }
        }

        stage('Run Ansible') {
            when {
                expression {
                    params.ACTION == 'apply'
                }
            }

            steps {
                sh '''
                    set -e

                    cd "${ANSIBLE_DIR}"

                    ansible-playbook \
                      --syntax-check \
                      playbook.yml

                    ansible-playbook \
                      playbook.yml
                '''
            }
        }

        stage('Validate Developer VM') {
            when {
                expression {
                    params.ACTION == 'apply'
                }
            }

            steps {
                sh '''
                    ansible developer_vm \
                      -i ansible/inventory.ini \
                      -b \
                      -m shell \
                      -a '
                        java --version &&
                        mvn --version &&
                        git --version &&
                        cat /opt/royal-hotel/developer-workspace/README.txt
                      '
                '''
            }
        }

        stage('Terraform Destroy') {
            when {
                expression {
                    params.ACTION == 'destroy'
                }
            }

            steps {
                input(
                    message: 'Destroy all InfraPro AWS resources?',
                    ok: 'Destroy'
                )

                withCredentials([
                    string(
                        credentialsId: 'aws-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh """
                        terraform -chdir=${TF_DIR} destroy \
                          -input=false \
                          -var="aws_region=${params.AWS_REGION}" \
                          -var="environment=${params.ENVIRONMENT}" \
                          -var="instance_type=${params.INSTANCE_TYPE}" \
                          -var="allowed_ssh_cidr=${params.ALLOWED_SSH_CIDR}" \
                          -var="public_key_path=${WORKSPACE}/.ssh/infrapro-key.pub" \
                          -var="private_key_path=${WORKSPACE}/.ssh/infrapro-key" \
                          -auto-approve
                    """
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts(
                artifacts: 'terraform/tfplan',
                allowEmptyArchive: true
            )

            sh '''
                rm -rf "${WORKSPACE}/.ssh"
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