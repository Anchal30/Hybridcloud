provider "aws" {
  region  = "ap-south-1"
  profile="user_anchal"
}
# input for key name
variable "enter_your_key_name" {
                 type = string
              }

# create key pair
resource "tls_private_key" "this" {
  algorithm = "RSA"
}
resource "aws_key_pair"   "deployer" {
  key_name   = var.enter_your_key_name
  public_key = tls_private_key.this.public_key_openssh
}
// print key
output "keyout" {
   value=aws_key_pair.deployer. key_name
}
# create security group
resource "aws_security_group" "sg_tf" {
  name        = "sg_tf"
  description = "Allow TLS inbound traffic"

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
    Name = "allow_tls"
  }
}
//print SecurityGroup
output "sg" {
   value=aws_security_group.sg_tf.name
}
// create ec2
resource "aws_instance" "os1_tf" {
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
 key_name   = var.enter_your_key_name
 security_groups= ["sg_tf"]
      tags = {
    Name = "teraos1"
  }
}

# create volume
resource "aws_ebs_volume" "ebs_for_os1_tf" {
  availability_zone = aws_instance.os1_tf.availability_zone
  size              = 1

  tags = {
    Name = "teraebs"
  }
}
# attach volume
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_for_os1_tf.id
  instance_id = aws_instance.os1_tf.id
 force_detach = true
}
# print public ip
output "myos_ip" {
  value = aws_instance.os1_tf.public_ip
}

# save public ip in a file
resource "null_resource" "nulllocal1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.os1_tf.public_ip} > publicip.txt"
  	}
}
resource "null_resource" "nulllocal32"  {

 provisioner "local-exec" {
    command = "git clone https://github.com/Anchal30/automationweb.git   C:/Users/dipan/Desktop/task_1/repo/"
    when    = destroy
  }
}
# create s3 bucket
resource "aws_s3_bucket" "buc_tf" {
depends_on = [
    null_resource.nulllocal32,    
  ]   
  bucket = "buc-for-tf-user-anchal"  # should be unique
  acl    = "public-read"
force_destroy=true
 policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::buc-for-tf-user-anchal/*"
    }
  ]
}
POLICY
 }
# upload object to s3 bucket
resource "aws_s3_bucket_object"  "buc_obj1" {
depends_on=[aws_s3_bucket.buc_tf]
    bucket =  "buc-for-tf-user-anchal"
  key    = "one"
  source="C:/Users/dipan/Desktop/task_1/repo/images.jpg "
  etag="C:/Users/dipan/Desktop/task_1/repo/images.jpg"
 acl= "public-read"
  content_type = "image/jpg"
 }
locals {
  s3_origin_id = "aws_s3_bucket.buc_tf.id"
}
resource "aws_cloudfront_origin_access_identity" "o" {
     comment = "this is oai"
 }

# create cloudfront
resource "aws_cloudfront_distribution"  "cf1_tf" {
depends_on=[aws_s3_bucket_object.buc_obj1]
  origin {
     domain_name=aws_s3_bucket.buc_tf.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
s3_origin_config {
           origin_access_identity = aws_cloudfront_origin_access_identity.o.cloudfront_access_identity_path 
     }
  }
 enabled             = true
is_ipv6_enabled     = true
comment             = "Some comment"
  default_root_object="images.jpg"

  logging_config {
    include_cookies = false
    bucket          =  aws_s3_bucket.buc_tf.bucket_domain_name
    
  }


default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id =   local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    } 
viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id =  local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["CA", "GB"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
output "out3" {
        value = aws_cloudfront_distribution.cf1_tf.domain_name
}

 
# remote connection
resource "null_resource" "nullremote1"  {

depends_on = [
    aws_volume_attachment.ebs_att,aws_cloudfront_distribution.cf1_tf,
  ]
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.this.private_key_pem
    host     = aws_instance.os1_tf.public_ip
  }
# copy github code into html folder
 provisioner "remote-exec" {
      inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd", 
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount   /dev/xvdh   /var/www/html",
      "sudo rm  -rf   /var/www/html/*",
      "sudo git clone   https://github.com/Anchal30/automationweb.git    /var/www/html/",
      "sudo su << EOF",
      "echo \"<img src='https://${aws_cloudfront_distribution.cf1_tf.domain_name}/${aws_s3_bucket_object.buc_obj1.key }'>\" >> /var/www/html/index.html",
       "EOF",
     
    ]
  }
}
# run code
resource "null_resource" "nulllocal2"  {
depends_on = [
    null_resource.nullremote1,
  ]
                 provisioner "local-exec" {
	    command = " start chrome  ${aws_instance.os1_tf.public_ip}/index.html"
  	}
}

  
