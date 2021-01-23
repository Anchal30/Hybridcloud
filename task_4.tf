provider "aws" {
  region  = "ap-south-1"
  profile = "askuser"
}

resource "tls_private_key" "task-4-pri-key" { 
  algorithm   = "RSA"
  rsa_bits = 2048
}

resource "aws_key_pair" "task-4-key" {
  depends_on = [ tls_private_key.task-4-pri-key, ]
  key_name   = "task-4-key"
  public_key = tls_private_key.task-4-pri-key.public_key_openssh
}

resource "aws_vpc" "task-4-vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true

  tags = {
    Name = "Task-4-vpc"
  }
}

resource "aws_subnet" "public" {
  depends_on = [ aws_vpc.task-4-vpc, ]
  vpc_id     = aws_vpc.task-4-vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "private" {
 depends_on = [ aws_vpc.task-4-vpc, ]
  vpc_id     = aws_vpc.task-4-vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
 
  tags = {
    Name = "Private"
  }
}


resource "aws_internet_gateway" "task-4-gw" {
  depends_on = [ aws_vpc.task-4-vpc, ]  
  vpc_id = aws_vpc.task-4-vpc.id

  tags = {
    Name = "task-4-gw"
  }
}

resource "aws_route_table" "rt" {
 depends_on = [ aws_internet_gateway.task-4-gw, ] 
  vpc_id = aws_vpc.task-4-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task-4-gw.id
  }

  tags = {
    Name = "main"
  }
}
resource "aws_route_table_association" "ig-b" {
  depends_on = [ aws_vpc.task-4-vpc,
                 aws_subnet.public,
                 aws_route_table.rt, ]  
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_eip" "nat" {
  vpc      = true
}
resource "aws_nat_gateway" "task-4-ngw" {
  depends_on = [ aws_eip.nat,
                   aws_internet_gateway.task-4-gw, ] 
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "gw NAT"
  }
}
resource "aws_route_table" "rtt" {
 depends_on = [ aws_vpc.task-4-vpc,
               aws_nat_gateway.task-4-ngw, ]
  vpc_id = aws_vpc.task-4-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.task-4-ngw.id
  }

    tags = {
    Name = "main"
  }
}
resource "aws_route_table_association" "nat-b" {
  depends_on = [ aws_vpc.task-4-vpc,
                 aws_subnet.private,
                 aws_route_table.rtt, ]  
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.rtt.id
}

resource "aws_security_group" "wp" {
 depends_on = [ aws_vpc.task-4-vpc, ]
  name        = "wp"
  description = "Allow SSH AND HTTP inbound traffic"
  vpc_id      = aws_vpc.task-4-vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "Https from VPC"
    from_port   = 443
    to_port     = 443
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
    Name = "allow_http_ssh"
  }
}

resource "aws_security_group" "bastion_sg" {

 depends_on = [ aws_vpc.task-4-vpc, ]
  name        = "bastion_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.task-4-vpc.id

  ingress {
    description = "SSH from VPC"
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
    Name = "bastion"
  }
}

resource "aws_security_group" "mysql" {
 depends_on = [ aws_vpc.task-4-vpc, ]
  name        = "mysql"
  description = "Allow SSH AND MYSQL inbound traffic"
  vpc_id      = aws_vpc.task-4-vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.bastion_sg.id}" ]
  }
ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
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
    Name = "allow_mysql_ssh"
  }
}
resource "aws_instance" "wordpress" {
 depends_on = [ aws_vpc.task-4-vpc,
                  aws_key_pair.task-4-key,
                  aws_subnet.public,
                  aws_security_group.wp, ]
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  key_name = "mycloudkey"
  availability_zone = "ap-south-1a"
  vpc_security_group_ids = [ aws_security_group.wp.id]
  subnet_id = aws_subnet.public.id
 tags = {
    Name = "WordPress"
  }
}


resource "aws_instance" "baston" {
 depends_on = [ aws_vpc.task-4-vpc,
                  aws_key_pair.task-4-key,
                  aws_subnet.public,
                   aws_security_group.bastion_sg, ]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name = "mycloudkey"
  vpc_security_group_ids = [ aws_security_group.bastion_sg.id]
  subnet_id = aws_subnet.public.id
 tags = {
    Name = "Baseton_OS"
  }
}
resource "aws_instance" "mysql" {
depends_on = [ aws_vpc.task-4-vpc,
                  aws_key_pair.task-4-key,
                  aws_subnet.private,
                  aws_security_group.mysql,
                   ]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name = "mycloudkey"
  vpc_security_group_ids = [ aws_security_group.mysql.id ]
  subnet_id = aws_subnet.private.id
 tags = {
    Name = "MYSQL"
  }
}
   
