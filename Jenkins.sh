#!/bin/bash

sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt install python3.9 python3.9-venv -y

sudo apt update && sudo apt install fontconfig openjdk-17-jre software-properties-common -y

sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins -y
sudo systemctl start jenkins
sudo systemctl status jenkins
echo /var/lib/jenkins/secrets/initialAdminPassword

