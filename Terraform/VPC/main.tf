# default vpc
data "aws_vpc" "default" {
  default = true
}
data "aws_subnet" "default_subnet" {
  id = var.default_subnet_id
}

#default security group
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "group-name"
    values = ["Jenkins"]
  }
}

#main route table for default VPC
data "aws_route_table" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "association.main"
    values = ["true"]
  }
}
# create a vpc
resource "aws_vpc" "wl6vpc" {
  cidr_block = "10.0.0.0/16" 

  tags = {
    "Name" : "wl6vpc"         
  }
}

#- 2x Availability zones in us-east-1a and us-east-1b
# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

#- A private and public subnet in EACH AZ
# create public subnets under two azs
resource "aws_subnet" "public_subnet" {
    #count: number of azs
  count = 2
  vpc_id     = aws_vpc.wl6vpc.id
  #for each subnet the cidr block is based on the numebr of az
  # the public subnets: 10.0.1.0, 10.0.2.0
  
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_${count.index + 1}"
  }
}
# create a private subnet
resource "aws_subnet" "private_subnet" {
  count = 2
  vpc_id = aws_vpc.wl6vpc.id
  # the public subnets: 10.0.11.0, 10.10.12.0
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index+10)
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  # map_public_ip_on_launch = true

  tags = {
    Name = "private_subnet_${count.index + 1}"
  }
}

# Using a application load balancer to direct traffic to either public subnets

resource "aws_lb" "load_balancer" {
  name               = "lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  #define a variable is "subnet", and iterate each of the created public_subnet in aws_subnet resource, then refer its id
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]

# not enable the deletion protection
  enable_deletion_protection = false

# logging the activity in load balancer to a s3 bucket

#   access_logs {
#     bucket  = aws_s3_bucket.lb_logs.id
#     prefix  = "application_lb"
#     enabled = true
#   }

  tags = {
    Environment = "production"
  }
}


# security group for load balancer, port 80 for HTTP traffic
resource "aws_security_group" "lb_sg" {
  vpc_id     = aws_vpc.wl6vpc.id
  name        = "lb_sg"
  description = "open HTTP/HTTPs"
  # Ingress rules: Define inbound traffic that is allowed.Allow SSH traffic and HTTP traffic on port 8080 from any IP address (use with caution)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  # Egress rules: Define outbound traffic that is allowed. The below configuration allows all outbound traffic from the instance.
  egress {
      from_port   = 0   #allow all outbound traffic
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  # Tags for the security group
  tags = {
    "Name"      : "tf_made_lb_sg"                          # Name tag for the security group
    "Terraform" : "true"                                # Custom tag to indicate this SG was created with Terraform
  }
}

#target group for the load balancer
resource "aws_lb_target_group" "app_tg" {
  name     = "application-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.wl6vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    #check here for update
    matcher = "200"
  }

  tags = {
    Name = "application-tg"
  }
}

# load balancer listener
#
#
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# register ec2 instances with target group
#
#
resource "aws_lb_target_group_attachment" "app_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = var.app_instance_id[count.index]
  port             = 3000
}


# one internet gateway required for one VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.wl6vpc.id

  tags = {
    Name = "internet_gateway"
  }
}

# eip: create two eips for each nat
resource "aws_eip" "eip_az" {
  count    = 2
  domain   = "vpc"
}
#create two nats in two public subnets and associate eip for each of them 
resource "aws_nat_gateway" "nat_gateway" {
  count = 2
  allocation_id = aws_eip.eip_az[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id

  tags = {
    Name = "gw NAT ${count.index + 1}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

# public route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.wl6vpc.id

  route {
    #cidr_block = "10.0.1.0/24"
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "route_table"
  }
}

# private route table
resource "aws_route_table" "private_route_table_az1" {
  vpc_id = aws_vpc.wl6vpc.id

  route {
    #cidr_block = "10.0.1.0/24"
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[0].id
  }


  tags = {
    Name = "private_route_table_az1"
  }
}
resource "aws_route_table" "private_route_table_az2" {
  vpc_id = aws_vpc.wl6vpc.id

  route {
    #cidr_block = "10.0.1.0/24"
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[1].id
  }


  tags = {
    Name = "private_route_table_az2"
  }
}


# associate a public route table to a public subnet 
resource "aws_route_table_association" "public_route_table_association" {
  count = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.route_table.id
}

# associate a private route table to a private subnet 
resource "aws_route_table_association" "private_route_table_association1" {
  subnet_id      = aws_subnet.private_subnet[0].id
  route_table_id = aws_route_table.private_route_table_az1.id
}

# associate a private route table to a private subnet 
resource "aws_route_table_association" "private_route_table_association2" {
  subnet_id      = aws_subnet.private_subnet[1].id
  route_table_id = aws_route_table.private_route_table_az2.id
}

#VPC peering & accepter
resource "aws_vpc_peering_connection" "peer-connection" {
  peer_vpc_id   = data.aws_vpc.default.id
  vpc_id        = aws_vpc.wl6vpc.id
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = aws_vpc_peering_connection.peer-connection.id
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}

#VPC peering route tables
#from default to custom
resource "aws_route" "default_to_wl6" {
  route_table_id            = data.aws_route_table.default.id
  destination_cidr_block    = aws_vpc.wl6vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer-connection.id
}

# Private Route table az1 entry for WL6 VPC to Default VPC
resource "aws_route" "wl6_to_default" {
  route_table_id            = aws_route_table.private_route_table_az1.id 
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer-connection.id
}
# Private Route table az1 entry for WL6 VPC to Default VPC
resource "aws_route" "wl6_to_default" {
  route_table_id            = aws_route_table.private_route_table_az2.id 
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer-connection.id
}

# Public Route table entry for WL6 VPC to Default VPC
resource "aws_route" "wl6_to_default" {
  route_table_id            = aws_route_table.route_table.id 
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer-connection.id
}

# allow traffic from custom to default
resource "aws_security_group_rule" "allow_default_to_custom" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "-1"
  cidr_blocks = [data.aws_vpc.default.cidr_block]
  security_group_id = data.aws_security_group.default.id
}
