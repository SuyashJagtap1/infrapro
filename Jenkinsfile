pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform operation'
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
            description: 'Administrator public IP in CIDR format'
        )
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'
        TF_DIR           = 'terraform'
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
                sh '''
                    terraform -chdir=${TF_DIR} init
                '''
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
                sh """
                    terraform -chdir=${TF_DIR} plan \
                      -var="aws_region=${params.AWS_REGION}" \
                      -var="environment=${params.ENVIRONMENT}" \
                      -var="instance_type=${params.INSTANCE_TYPE}" \
                      -var="allowed_ssh_cidr=${params.ALLOWED_SSH_CIDR}" \
                      -out=tfplan
                """
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    params.ACTION == 'apply'
                }
            }

            steps {
                sh '''
                    terraform -chdir=${TF_DIR} apply \
                      -auto-approve \
                      tfplan
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
                    sleep 30
                    cd ansible
                    ansible all -m ping
                    ansible-playbook playbook.yml
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
                sh """
                    terraform -chdir=${TF_DIR} destroy \
                      -var="aws_region=${params.AWS_REGION}" \
                      -var="environment=${params.ENVIRONMENT}" \
                      -var="instance_type=${params.INSTANCE_TYPE}" \
                      -var="allowed_ssh_cidr=${params.ALLOWED_SSH_CIDR}" \
                      -auto-approve
                """
            }
        }
    }

    post {
        always {
            archiveArtifacts(
                artifacts: 'terraform/*.tfplan',
                allowEmptyArchive: true
            )
        }

        success {
            echo 'InfraPro pipeline completed successfully.'
        }

        failure {
            echo 'InfraPro pipeline failed. Review the console output.'
        }
    }
}