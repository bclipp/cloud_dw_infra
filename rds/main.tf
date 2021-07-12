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
   cidr_blocks = ["10.99.0.0/18"]
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




data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "aws_lambda_role" {
  name = "iam_for_lambda"

  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}

module "lambda_function_from_container_image" {
  source = "../../"

  function_name = "etl_lambda"
  description   = "used for ETL"

  create_package = false

  image_uri    = "112437402463.dkr.ecr.us-east-2.amazonaws.com/my_tests/lambda-mlops-model:latest"
  docker_image_uri = "112437402463.dkr.ecr.us-east-2.amazonaws.com/my_tests/lambda-mlops-model:latest"
  package_type = "Image"
  lambda_role_arn = aws_iam_role.aws_lambda_role.arn
}

# ECR

resource "aws_ecr_repository" "foo" {
  name                 = "bar"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
