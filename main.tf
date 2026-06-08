#Define Private VPC and Subnets
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "logger-priv-vpc"
  cidr = "10.10.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

#Define Private Route Table
resource "aws_route_table" "PRT" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "logger-priv-rt"
  }
}

#Define PRT Subnet Association
resource "aws_route_table_association" "PRT-assoc" {
  route_table_id = aws_route_table.PRT.id
  subnet_id = module.vpc.private_subnets[0]
}

#Define Key Pair
resource "tls_private_key" "logger_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "logger_key_pair" {
  key_name = var.key_name
  public_key = tls_private_key.logger_key.public_key_openssh
}

resource "local_file" "private_key" {
  content = tls_private_key.logger_key.private_key_pem
  filename = "${path.module}/${var.key_name}.pem"
  file_permission = "0600"
}

#Define Private EC2 Security Group
resource "aws_security_group" "logger_sg" {
  name = var.security_group_name
  description = "Security Group for Private EC2 Instance"
  vpc_id = module.vpc.vpc_id
}


resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.logger_sg.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.logger_sg.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.logger_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Define Private EC2 Instance
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "single-instance"

  instance_type = "t3.micro"
  key_name      = aws_key_pair.logger_key_pair.key_name
  monitoring    = true
  subnet_id     = module.vpc.private_subnets[0]
  ami           = var.ami 
  vpc_security_group_ids = [aws_security_group.logger_sg.id]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
