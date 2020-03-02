####################################
######### Initialization ###########
####################################
provider "aws" {
  version = "~> 2.0"
  region  = var.region
}

terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "iglesias-michael"

    workspaces {
      prefix = "vpc1-"
    }
  }
}

############################################
######### Variables/Data sources ###########
############################################
locals {
  environment   = "${lookup(var.workspace_to_environment_map, var.ATLAS_WORKSPACE_NAME, "dev")}"
  instance_size = "${local.environment == "dev" ? lookup(var.workspace_to_size_map, var.ATLAS_WORKSPACE_NAME, "small") : var.environment_to_size_map[local.environment]}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical AWS account
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = "webapp-vpc-${local.environment}"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = local.environment
    Foo         = var.ATLAS_WORKSPACE_NAME
  }
}

resource "random_shuffle" "shuffled_public_subnets" {
  input        = module.vpc.public_subnets
  result_count = 1
}

resource "random_shuffle" "shuffled_private_subnets" {
  input        = module.vpc.private_subnets
  result_count = 1
}

module "gocd-master" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  name = "gocd-master-${local.environment}"

  ami            = data.aws_ami.ubuntu.id
  instance_count = 1
  instance_type  = "t2.${local.instance_size}"
  user_data      = "${base64encode(file("${path.module}/files/startup.sh"))}"

  key_name   = "MacbookAirKeyPair"
  monitoring = true

  subnet_id              = random_shuffle.shuffled_public_subnets.result[0]
  vpc_security_group_ids = [module.gocd-master-sg.this_security_group_id]

  tags = {
    Terraform   = "true"
    Environment = local.environment
  }
}

module "gocd-master-sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.4.0"

  name   = "gocd-master-sg-${local.environment}"
  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8153
      to_port     = 8153
      protocol    = "tcp"
      description = "GOCD UI (HTTP)"
      cidr_blocks = "209.58.147.42/32"
    },
    {
      from_port   = 8154
      to_port     = 8154
      protocol    = "tcp"
      description = "GOCD UI (HTTPS)"
      cidr_blocks = "209.58.147.42/32"
    },
    {
      rule        = "ssh-tcp"
      cidr_blocks = "209.58.147.42/32"
    },
  ]

  egress_rules = ["all-all"]
}

resource "aws_placement_group" "gocd-agents" {
  name     = "gocd-agents-pg-${local.environment}"
  strategy = "cluster"
}

resource "aws_launch_configuration" "gocd-agents-launch-config" {
  name = "gocd-agents-launch-config-${local.environment}"

  image_id      = data.aws_ami.ubuntu.id
  instance_type = local.instance_size
  user_data     = "${base64encode(file("${path.module}/files/agent-startup.sh"))}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "gocd-agents-autoscaling-group" {
  name                      = "gocd-agents-autoscaling-group-${local.environment}"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  placement_group           = "${aws_placement_group.gocd-agents.id}"
  launch_configuration      = "${aws_launch_configuration.gocd-agents-launch-config.name}"
  vpc_zone_identifier       = [random_shuffle.shuffled_private_subnets.result[0], random_shuffle.shuffled_private_subnets.result[1]]

  initial_lifecycle_hook {
    name                 = "foobar"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 2000
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }
  timeouts {
    delete = "15m"
  }
}

