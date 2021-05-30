# Terraform version

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
    mysql = {
      source  = "terraform-providers/mysql"
    }
  }

  required_version = ">= 0.14.9"
}

# Using AWS as the provider and define region.

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

# Use all availability zones for redundancy

data "aws_availability_zones" "all" {}

#
# VPC creation
#

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"
  name    = var.vpc_name
  cidr    = var.vpc_cidr

  azs                = data.aws_availability_zones.all.names
  private_subnets    = var.vpc_private_subs
  public_subnets     = var.vpc_public_subs
  enable_nat_gateway = true
  enable_vpn_gateway = false
  tags = {
    project     = "claranet"
    environment = "dev"
    desc        = "vpc_claranet"
  }
}

resource "aws_launch_configuration" "mywebservers" {
  name_prefix     = "terraform-lc"
  image_id        = var.image_id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  user_data = file("user_data.txt")
  key_name  = "aws_ssh_key"
}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_ssh_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCcuNyuPS+v2syZqMyUmiqPee4ceVXPn9Arz1cVBrL2e7LqHUGJqn3jcFVab2E9LehDb9MWxOUaZ7ZMc0bRVY3+dbpAYhu5HbWLcA2UBYECjp+xlo+azAMEcw+68uP8OGwfSmm1UhY8sTlZ9q5kyc9IbdU8y9W5Z1UTbQ8OSVxFgZgy97Uk1bsnKrpgFnnmmhy4l6gzrm+H0nRijpR9Lc/ZCZCW866ViPEaSP63rjuKArEOt6j9x+yQ0EbbaUZCEElukqyESGHnceBC9lekswCAXrEmdD2Axj7KG+wsscWoB2mMtEjXeuDWyRggZIhYahq6Bm+SnzEPCv4xpzcOyEfv claranet-sshkey"
}

data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.selected.id
}

resource "aws_autoscaling_group" "mywebservers" {
  name                 = "terraform-asg"
  launch_configuration = aws_launch_configuration.mywebservers.name
  min_size             = 1
  max_size             = 3
  health_check_type    = "ELB"
  target_group_arns    = [aws_lb_target_group.test.arn, aws_lb_target_group.test443.arn]
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "terraform-asg-mywebservers"
    propagate_at_launch = true
  }
  vpc_zone_identifier   = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]
}

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
  depends_on       = [module.vpc]
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "test" {
  name     = "test-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id
  health_check {
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

resource "aws_lb_target_group" "test443" {
  name     = "test-lb-tg443"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.selected.id
  health_check {
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#resource "aws_lb_listener" "test443" {
#  load_balancer_arn = aws_lb.test.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = "${data.aws_acm_certificate.issued.arn}"
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.test443.arn
#  }
#}

#
# Grab myIpv4 to use as CIDR to SSH into EC2 - ["${chomp(data.http.myip.body)}/32"]
#

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

# Create security group for ALB and EC2 

resource "aws_security_group" "elb" {
  name = "terraform-mywebservers-elb"
  vpc_id = data.aws_vpc.selected.id
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from anywhere"
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
}

resource "aws_security_group" "instance" {
  name = "terraform-mywebservers-instance"
  vpc_id = data.aws_vpc.selected.id
  ingress {
    description     = "HTTP from LB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.elb.id}"]
  }
  ingress {
    description     = "HTTPS from LB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = ["${aws_security_group.elb.id}"]
  }
  ingress {
    description = "SSH from myIp"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# You can use curl to then test this
#output "clb_dns_name" {
#  value       = aws_lb.test.dns_name
#  description = "The domain name of the load balancer"
#}



resource "aws_cloudwatch_metric_alarm" "http" {
  alarm_name                = "http-4xx-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_ELB_4XX_Count"
  namespace                 = "HTTP 4xx count"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "10"
  alarm_description         = "This metric monitors http 4xx responses if >= 10"
  alarm_actions             = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    LoadBalancer = "${aws_lb.test.id}"
  }
}

resource "aws_sns_topic" "alarm" {
  name = "alarms-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.email}"
  }
}

#resource "aws_route53_zone" "primary" {
#  name = "example.com"
#}

#data "aws_acm_certificate" "issued" {
#  domain   = "example.com"
#  statuses = ["ISSUED"]
#}

#resource "aws_acm_certificate" "default" {
#  domain_name       = "example.com"
#  validation_method = "DNS"
#  
#}

#resource "aws_route53_record" "validation" {
#  for_each = {
#    for dvo in aws_acm_certificate.default.domain_validation_options: dvo.domain_name => {
#      name    = dvo.resource_record_name
#      type    = dvo.resource_record_type
#      record  = dvo.resource_record_value
#    }
#  }
#  allow_overwrite = true
#  name            = each.value.name
#  records         = [each.value.record]
#  type            = each.value.type
#  zone_id         = aws_route53_zone.primary.zone_id
#  ttl             = 60
#}

#resource "aws_acm_certificate_validation" "default" {
#  certificate_arn = aws_acm_certificate.default.arn
#  validation_record_fqdns = [for record in aws_route53_record.validation: record.fqdn]
#}


#
# Create a database server mySQL with RDS
#

resource "aws_db_instance" "default" {
  allocated_storage     = 10
  max_allocated_storage = 30
  engine                = var.db_engine
  engine_version        = var.db_engine_ver
  instance_class        = var.db_class
  name                  = var.db_name
  username              = var.db_user
  password              = var.db_passwd
  multi_az              = true
  db_subnet_group_name  = aws_db_subnet_group.default.id
  skip_final_snapshot   = true
}

# Configure the MySQL provider based on the outcome of
# creating the aws_db_instance.

provider "mysql" {
  endpoint = "${aws_db_instance.default.endpoint}"
  username = "${aws_db_instance.default.username}"
  password = "${aws_db_instance.default.password}"
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = data.aws_subnet_ids.subnets.ids
}
