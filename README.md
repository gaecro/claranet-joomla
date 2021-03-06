# claranet-joomla
Terraform code to provision AWS infra and deploy Joomla app. 

The infra resources as per below:\
  VPC and related network and security (i.e. SG, subnets, net CIDR etc)  
  Autoscaling group  
  Application Load Balancer (HTTP/80 listener only)  
  CloudWatch metrics alarm (HTTP status 4xx count)  
  SNS for notification about the previous alarm  
  RDS/mySQL DB service  
  
  ## How to use it  
  
 ### Change the values of the terraform.tfvars file, according to your needs. Below the default values:  

vpc_name         = "vpc_claranet"  
vpc_region       = "eu-west-1"  
vpc_cidr         = "10.0.0.0/16"  
vpc_private_subs = ["10.0.101.0/24", "10.0.102.0/24"]  
vpc_public_subs  = ["10.0.1.0/24", "10.0.2.0/24"]  
image_id         = "ami-0943382e114f188e8"  
instance_type    = "t2.micro"  
asg_min_size     = 1  
asg_max_size     = 3  
email            = "your.email@domain.com"  
db_name          = "joomla_db"  
db_user          = "joomla"  
db_passwd        = "Joomla_123"  
db_engine        = "mysql"  
db_engine_ver    = "8.0.23"  
db_class         = "db.m6g.large"  

### What's in the user_data.txt  
Here you'll find a bash script which will install LAMP (without mysql as a separate RDS service will be provisioned), will install Joomla (you will also find the "ver" variable should you need to install other versions) and logrotate conf for the Apache2 logs.

### Once the specific values above are set, please run:  
terraform init  
terraform plan  
terraform apply

### Start configuring Joomla through their UI

To open the Joomla UI and start configuring it, please use the DNS name of the ELB appending the page addrress "/index.php"  
i.e. http://test-lb-tf-1563006515.eu-west-1.elb.amazonaws.com/index.php
