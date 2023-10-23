provider "aws" {
  region     = "eu-west-2"
  access_key = var.access_key
  secret_key = var.secret_key
}

# 1 Create VPC
resource "aws_vpc" "PubWebVpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "PubWebVpc"
  }
}

# 2 Create Internet Gateway
resource "aws_internet_gateway" "PubWebGw" {
  vpc_id = aws_vpc.PubWebVpc.id

  tags = {
    Name = "PubWebGw"
  }
}
# 3 Create Custom Route Table
resource "aws_route_table" "PubWebRt" {
  vpc_id = aws_vpc.PubWebVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.PubWebGw.id
  }

  tags = {
    Name = "PubWebRt"
  }
}

# 4 Create a Subnet
resource "aws_subnet" "PubWebSn" {
  vpc_id     = aws_vpc.PubWebVpc.id
  cidr_block = "10.0.1.0/24"
  # Add this availiabilty zone 
  availability_zone = "eu-west-2a"
  tags = {
    Name = "PubWebSn"
  }
}

# 5 Associate subnet with Route Table
resource "aws_route_table_association" "PubWebRta" {
  subnet_id      = aws_subnet.PubWebSn.id
  route_table_id = aws_route_table.PubWebRt.id
}

# 6 Create Security Group to allow ports 22, 80, 443
resource "aws_security_group" "PubWeb_allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.PubWebVpc.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PubWeb_allow_web_traffic"
  }
}

# 7 Create a newtork interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "PubWebNi" {
  subnet_id       = aws_subnet.PubWebSn.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.PubWeb_allow_web_traffic.id]
}

# 8 Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "PubWebEip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.PubWebNi.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.PubWebGw]
}

# 9 Create Ubuntu server and install/enable apache2
resource "aws_instance" "PubWebInst" {
  # Username = "ubuntu"
  ami               = "ami-0eb260c4d5475b901"
  instance_type     = "t2.micro"
  availability_zone = "eu-west-2a"
  key_name          = "PubWebKey"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.PubWebNi.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo This is a test > /var/www/html/index.html'
                EOF

  tags = {
    Name = "PubWebInst"
  }
}

output "GetPubIP" {
  value = aws_instance.PubWebInst.public_ip
}