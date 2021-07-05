provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "datawarhouse"
  cidr                 = "10.99.0.0/18"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets      = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets     = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "datawarehouse" {
  name       = "datawarehouse"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "datawarehouse"
  }
}

resource "aws_security_group" "rds" {
  name   = "datawarehouse_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
   from_port   = 1433
   to_port     = 1433
   protocol    = "tcp"
   description = "SqlServer access from within VPC"
   cidr_blocks = module.vpc.vpc_cidr_block
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "datawarehouse_rds"
  }
}


resource "aws_db_instance" "datawarehouse" {
  identifier             = "datawarehouse"
  instance_class         = "db.t3.small"
  allocated_storage      = 20
  engine                 = "sqlserver-ex"
  engine_version         = "15.00.4073.23.v1"
  username               = "dw_admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.datawarehouse.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
}
