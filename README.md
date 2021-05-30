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
  
  First thing, change the values of the terraform.tfvars file, according to your needs. Below the default values:  

vpc_name         = "vpc_claranet"
vpc_cidr         = "10.0.0.0/16"
vpc_private_subs = ["10.0.101.0/24", "10.0.102.0/24"]
vpc_public_subs  = ["10.0.1.0/24", "10.0.2.0/24"]
image_id         = "ami-0943382e114f188e8"
instance_type    = "t2.micro"
email            = "your.email@domain.com"
db_name          = "joomla_db"
db_user          = "joomla"
db_passwd        = "Joomla_123"
db_engine        = "mysql"
db_engine_ver    = "8.0.23"
db_class         = "db.m6g.large"

Once the specific values above are set, please run:  
terraform init  
terraform plan  
terraform apply
