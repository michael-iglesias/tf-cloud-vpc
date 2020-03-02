output "vpc-name" {
  value = module.vpc.name
}


output "vpc-id" {
  value = module.vpc.vpc_id
}

output "vpc-cidr" {
  value = module.vpc.vpc_cidr_block
}

output "vpc-subnets-private" {
  value = module.vpc.private_subnets
}

output "vpc-subnets-public" {
  value = module.vpc.public_subnets
}

