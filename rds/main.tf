provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "education"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "data_warhouse" {
  name       = "data_warhouse"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "data_warhouse"
  }
}

resource "aws_security_group" "rds" {
  name   = "data_warhouse_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "data_warhouse_rds"
  }
}

resource "aws_db_parameter_group" "data_warhouse" {
  name   = "data_warhouse"
  family = "postgres13"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "data_warhouse" {
  identifier             = "data_warhouse"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "sqlserver-ex"
  engine_version         = "15.00.4073.23.v1"
  username               = "dw_admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.data_warhouse.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.data_warhouse.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}
