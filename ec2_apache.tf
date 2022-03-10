provider "aws" {
  region  = var.aws_region
  profile = "default"
}

# create VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id
}

# create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zone
  tags = {
    Name = "prod-subnet"
  }
}

# create subnet with Route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id 
}

# create a security group to allow port 22,80 and 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow WEB inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

# create a network interface
resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# create an Elastic IP (Public) to the network interface created above
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value               = aws_eip.one.public_ip
  
}

# create Ubuntu server and install/enable apache2
resource "aws_instance" "web_server" {
  ami                 = var.ami
  instance_type       = var.instance_type
  availability_zone   = var.availability_zone
  key_name            = "ec2-key"

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.web-server.id
}

#instalando apache2
  user_data = <<-EOF
	            #!/bin/bash
              sudo apt update -y 
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo My first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "ubuntu-web-server"
  }
} 

#variables
variable "instance_type" {
  description = "Type of the machine free teer"
}
variable "aws_region" {
  description = "Region of the machine"
}
variable "ami" {
  description = "Images"
}
variable "availability_zone" {
  description = "Zone"
}