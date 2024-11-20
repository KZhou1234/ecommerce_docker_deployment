pipeline {
  agent any

  environment {
    DOCKER_CREDS = credentials('docker-hub-credentials')
  }

  stages {
    stage ('Build') {
      agent any
      steps {
        sh '''#!/bin/bash

        python3.9 --version
        python3.9 -m venv venv
        source venv/bin/activate
        cd ./backend
        pip install -r requirements.txt
        '''
      }
    }

    stage ('Test') {
      agent any
      steps {
        sh '''#!/bin/bash
        source venv/bin/activate
        pip install pytest-django
        #python backend/manage.py makemigrations
        #python backend/manage.py migrate
        pytest backend/account/tests.py --verbose --junit-xml test-reports/results.xml
        ''' 
      }
    }

    stage('Cleanup') {
      agent { label 'build-node' }
      steps {
        sh '''
          # Only clean Docker system
          docker system prune -f
          
          # Safer git clean that preserves terraform state
          git clean -ffdx -e "*.tfstate*" -e ".terraform/*"
        '''
      }
    }

    stage('Build & Push Images') {
      agent { label 'build-node' }
      steps {
        sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
        
        // Build and push backend
        sh '''
          docker build -t kezhou932/backend-image:latest -f Dockerfile.backend .
          docker push kezhou932/backend-image:latest
        '''
        
        // Build and push frontend
        sh '''
          docker build -t kezhou932/frontend-image:latest -f Dockerfile.frontend .
          docker push kezhou932/frontend-image:latest
        '''
      }
    }

    stage('Infrastructure') {
      agent { label 'build-node' }
      steps {
        withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                        string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')
                        ]) {
                            dir('Terraform') {
                              sh '''
                              terraform init
                              terraform plan -out plan.tfplan\
                               -var="default_subnet_id=subnet-04b4d6310c2cab924"\
                               -var="aws_access_key=${aws_access_key}"\
                               -var="aws_secret_key=${aws_secret_key}" \
                               -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                               -var="dockerhub_password=${DOCKER_CREDS_PSW}"
                              terraform apply -auto-approve \
                               -var="default_subnet_id=subnet-04b4d6310c2cab924"\
                               -var="aws_access_key=${aws_access_key}"\
                               -var="aws_secret_key=${aws_secret_key}" \
                               -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                               -var="dockerhub_password=${DOCKER_CREDS_PSW}"
                              '''
                            }
                      }
      }
    }
  }

  post {
    always {
      node('build-node')
      //agent { label 'build-node' }
      steps {
        sh '''
          docker logout
          docker system prune -f
        '''
      }
    }
  }
}
