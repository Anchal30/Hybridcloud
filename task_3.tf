provider "aws" {
  region  = "ap-south-1"
  profile="user_anchal"
}
# create vpc

resource "aws_vpc" "task_vpc" {
  cidr_block = "192.168.0.0/16"
   instance_tenancy = "default"
enable_dns_hostnames =true

tags = {
    Name = "task_3-vpc"
  }
}

# create subnet
resource "aws_subnet" "task_public" {
  depends_on=[ aws_vpc.task_vpc,]
  vpc_id     =aws_vpc.task_vpc.id
  cidr_block = "192.168.0.0/24"
 availability_zone ="ap-south-1a"
map_public_ip_on_launch =true

  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "task_private" {
depends_on=[ aws_vpc.task_vpc,]
  vpc_id     =aws_vpc.task_vpc.id
  cidr_block = "192.168.1.0/24"
 availability_zone ="ap-south-1b"
 tags = {
    Name = "private"
  }
}

# create IG
resource "aws_internet_gateway" "task_IG" {
depends_on=[ aws_vpc.task_vpc,aws_subnet.task_public,]
  vpc_id = aws_vpc.task_vpc.id

  tags = {
    Name = "t_IG"
  }
}
# create RT
resource "aws_route_table" "task_RT" {
depends_on=[ aws_vpc.task_vpc,aws_subnet.task_public,aws_internet_gateway.task_IG,]
  vpc_id =  aws_vpc.task_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task_IG.id
  }
tags = {
    Name = "rt_task-3"
  }

}
# association
resource "aws_route_table_association" "public_association" {
depends_on=[ aws_vpc.task_vpc,aws_subnet.task_public,aws_internet_gateway.task_IG,
aws_route_table.task_RT,]
  subnet_id      = aws_subnet.task_public.id
  route_table_id = aws_route_table.task_RT.id
}
# create sg for wp
resource "aws_security_group" "sg_wp_tf" {
depends_on=[ aws_vpc.task_vpc,]
  name        = "sg_wp_tf"
  description = "Allow rules for public wp"
 vpc_id =  aws_vpc.task_vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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
    Name = "wp_sg"
  }
}

resource "aws_security_group" "sg_mysql_tf" {
depends_on=[ aws_vpc.task_vpc,]
  name        = "sg_mysql_tf"
  description = "Allow  inbound only from wp"
 vpc_id =  aws_vpc.task_vpc.id

  ingress {
    description = "wp inbound"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
     security_groups = [aws_security_group.sg_wp_tf.id]
  }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg"
  }
}
resource "aws_security_group" "sg_bastion_SSH" {
depends_on=[ aws_vpc.task_vpc,]

  name        = "sg_bastion_SSH"
  description = "Allow SSH-bastion inbound traffic"
  vpc_id      = aws_vpc.task_vpc.id
 

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
    Name = "sg_bastion"
  
 }
}
resource "aws_security_group" "sg_allow_SSH" {
 depends_on=[ aws_vpc.task_vpc,]
  name        = "sg_allow_SSH"
  description = "Allow SSH-bastion inbound traffic for mysql"
  vpc_id      = aws_vpc.task_vpc.id
 

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
       security_groups = [aws_security_group.sg_bastion_SSH.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "sg_allow_ssh"
  
 }
}

# wp-ec2
resource "aws_instance" "wp-task" {
depends_on=[ aws_vpc.task_vpc,aws_subnet.task_public,]
 
  ami           = "ami-01b9cb595fc660622"
  instance_type = "t2.micro"
  key_name= "key_2"
  vpc_security_group_ids = [ aws_security_group.sg_wp_tf.id]
  subnet_id = aws_subnet.task_public.id
 tags = {
    Name = "WordPress_for_task"
  }
}
resource "aws_instance" "mysql_task" {
 depends_on=[ aws_vpc.task_vpc,aws_subnet.task_private,]
 
  ami           = "ami-0025b3a1ef8df0c3b"
  instance_type = "t2.micro"
  key_name= "key_2"
  vpc_security_group_ids = [ aws_security_group.sg_mysql_tf.id, aws_security_group.sg_allow_SSH.id]
  subnet_id = aws_subnet.task_private.id
 tags = {
    Name = "mysql_for_task"
  }
}
resource "aws_instance" "bastion_task" {
depends_on=[ aws_vpc.task_vpc,aws_subnet.task_public,]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name =  "key_2"
  vpc_security_group_ids = [ aws_security_group.sg_bastion_SSH.id]
  subnet_id = aws_subnet.task_public.id
 tags = {
  Name = "Bastion_host"
  }
}
resource "null_resource" "nulllocal2"  {
depends_on = [
    aws_instance.wp-task, aws_instance.mysql_task,
  ]
                 provisioner "local-exec" {
	    command = " start chrome  ${aws_instance.wp-task.public_ip}"
  	}
}
