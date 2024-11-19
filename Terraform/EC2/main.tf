# I need to change the user data, and i've also need to modify the path and variable for private ip address of the backend
#Local variables are only used within the scope of the currentconfiguration file where they are defined.
#They are not passed between modules or configurations.

#- An EC2 in each subnet (EC2s in the public subnets are for the frontend, the EC2s in the private subnets are for the backend) Name the EC2's: "ecommerce_bastion_az1", "ecommerce_app_az1", "ecommerce_bastion_az2", "ecommerce_app_az2"


# Jenkins server is created in Jenkins_Terraform
# create monitoring ec2
# Monitoring server is in subnet in default VPC 
resource "aws_instance" "monitoring" {
  subnet_id  = var.default_subnet_id

  ami               = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type     = var.instance_type               # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]       # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name          = "mykey"                # The key pair name for SSH access to the instance.
  user_data = file("${path.module}/../../Scripts/monitoring_setup.sh")
  tags = {
    "Name" : "monitoring"         
  }
  
}
# Create EC2 for public subnet 0
resource "aws_instance" "ecommerce_bastion_az1" {
  subnet_id  = var.public_subnet_id[0]

  ami               = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type     = var.instance_type               # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]       # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name          = "mykey"                # The key pair name for SSH access to the instance.
  
  user_data = file("${path.module}/../../Scripts/bastionHost_setup.sh")

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_bastion_az1"         
  }

  depends_on = [ aws_instance.ecommerce_app_az1 ]
}

# Create EC2 for public_subnet_1
resource "aws_instance" "ecommerce_bastion_az2" {
  subnet_id  = var.public_subnet_id[1]

  ami               = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type     = var.instance_type               # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]       # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name          = "mykey"                # The key pair name for SSH access to the instance.
# user data
  user_data = file("${path.module}/../../Scripts/bastionHost_setup.sh")

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_bastion_az2"         
  }
    depends_on = [ aws_instance.ecommerce_app_az2 ]

}

# Create EC2 for private_subnet_0
resource "aws_instance" "ecommerce_app_az1" {
  subnet_id  = var.private_subnet_id[0]

  ami               = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type     = var.instance_type               # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.app_sg.id]       # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name          = "mykey"                # The key pair name for SSH access to the instance.
# user data
  user_data = base64encode(templatefile("${path.module}/../deploy.sh", {
    rds_endpoint = var.db_instance.endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("${path.module}/../compose.yml", {
      rds_endpoint = var.db_instance.endpoint
    })
  }))
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_app_az1"         
  }
    depends_on = [
    var.db_instance,
    var.nat_gateway
  ]
}

# Create EC2 for private_subnet_1
resource "aws_instance" "ecommerce_app_az2" {
  subnet_id  = var.private_subnet_id[1]

  ami               = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type     = var.instance_type               # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.app_sg.id]       # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name          = "mykey"                # The key pair name for SSH access to the instance.
# user data
  user_data = base64encode(templatefile("${path.module}/../deploy.sh", {
    rds_endpoint = var.db_instance.endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("${path.module}/../compose.yml", {
      rds_endpoint = var.db_instance.endpoint
    })
  }))
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_app_az2"         
  }
    depends_on = [
    var.db_instance,
    var.nat_gateway
  ]
}


# Create a security group named "frontend_sg" that allows SSH and React traffic.
# This security group will be associated with the frontend EC2 instance created above.
resource "aws_security_group" "bastion_sg" {
  vpc_id     = var.vpc_id
  name        = "bastion_sg"
  description = "open ssh and 80"
  # Ingress rules: Define inbound traffic that is allowed.Allow SSH traffic and HTTP traffic on port 8080 from any IP address (use with caution)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Egress rules: Define outbound traffic that is allowed. The below configuration allows all outbound traffic from the instance.
  egress {
      from_port   = 0   #allow all outbound traffic
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  # Tags for the security group
  tags = {
    "Name"      : "tf_made_bastion_sg"                          # Name tag for the security group
    "Terraform" : "true"                                # Custom tag to indicate this SG was created with Terraform
  }
}


#Monitoring instance open port 22, 3000, 9090
resource "aws_security_group" "monitoring_sg" {
  vpc_id     = var.default_vpc_id
  name        = "backend_sg"
  description = "open port for SSH, Grafana and Prometheus"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Egress rules: Define outbound traffic that is allowed. The below configuration allows all outbound traffic from the instance.
  egress {
      from_port   = 0   #allow all outbound traffic
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  # Tags for the security group
  tags = {
    "Name"      : "tf_made_monitoring_sg"                          # Name tag for the security group
    "Terraform" : "true"                                # Custom tag to indicate this SG was created with Terraform
  }
}
resource "aws_security_group" "app_sg" {
  vpc_id     = var.vpc_id
  name        = "frontend_sg"
  description = "open ssh traffic and port 3000"
  # Ingress rules: Define inbound traffic that is allowed.Allow SSH traffic and HTTP traffic on port 8080 from any IP address (use with caution)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #only open port for load balancer
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [var.lb_sg_id]
  }
  # Egress rules: Define outbound traffic that is allowed. The below configuration allows all outbound traffic from the instance.
  egress {
      from_port   = 0   #allow all outbound traffic
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  # Tags for the security group
  tags = {
    "Name"      : "tf_made_app_sg"                          # Name tag for the security group
    "Terraform" : "true"                                # Custom tag to indicate this SG was created with Terraform
  }
}


output "bastion_host_ips" {
  value = [aws_instance.ecommerce_bastion_az1.public_ip,
          aws_instance.ecommerce_bastion_az2.public_ip]
}



output "app_instance_private_ips" {
  value = [aws_instance.ecommerce_app_az1.private_ip,
          aws_instance.ecommerce_app_az2.private_ip]
}
