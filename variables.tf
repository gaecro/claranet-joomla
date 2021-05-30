

variable "vpc_name" {
  description = "The name of your new VPC"
  type = string
}

variable "vpc_cidr" {
  description = "The CIDR of your new VPC"
  type = string
}

variable "vpc_private_subs" {
  description = "The private subnets of your new VPC"
  type = list(string)
}

variable "vpc_public_subs" {
  description = "The public subnets of your new VPC"
  type = list(string)
}

variable "image_id" {
  description = "AMI Image ID"
  type = string
}

variable "instance_type" {
  description = "Type of instance to provision"
  type = string
}

variable "email" {
  description = "E-mail address to send SNS notification to"
  type = string
}

variable "db_name" {
  description = "Name of the mySQL DB for Joomla"
  type = string
}

variable "db_user" {
  description = "Username of the mySQL DB for Joomla"
  type = string
}

variable "db_passwd" {
  description = "Password of the mySQL DB for Joomla"
  type = string
}

variable "db_engine" {
  description = "Name of the DB Engine (i.e. mySQL)"
  type = string
}

variable "db_engine_ver" {
  description = "Version of the DB Engine (i.e. mySQL)"
  type = string
}

variable "db_class" {
  description = "Instance class of the DB Engine"
  type = string
}
