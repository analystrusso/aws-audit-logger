#Define Private VPC and Subnets
module "priv_vpc" {
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
resource "aws_route_table" "priv-rt" {
  vpc_id = module.priv_vpc.vpc_id

  tags = {
    Name = "logger-priv-rt"
  }
}

#Define priv-rt Subnet Association
resource "aws_route_table_association" "priv-rt-assoc" {
  route_table_id = aws_route_table.priv-rt.id
  subnet_id = module.priv_vpc.private_subnets[0]
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
resource "aws_security_group" "logger_priv_sg" {
  name = var.priv_security_group_name
  description = "Security Group for Private EC2 Instance"
  vpc_id = module.priv_vpc.vpc_id
}


resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.logger_priv_sg.id
  cidr_ipv4         = module.priv_vpc.vpc_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.logger_priv_sg.id
  cidr_ipv4         = module.priv_vpc.vpc_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.logger_priv_sg.id
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
  subnet_id     = module.priv_vpc.private_subnets[0]
  ami           = var.ami 
  vpc_security_group_ids = [aws_security_group.logger_priv_sg.id]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


#Define Public VPC and Subnets
module "pub_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "logger-pub-vpc"
  cidr = "10.20.0.0/16"

  azs             = ["us-east-1d", "us-east-1e", "us-east-1f"]
  public_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  map_public_ip_on_launch = true
  
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

#Define Public Internet Gateway
resource "aws_internet_gateway" "logger-igw" {
  vpc_id = module.pub_vpc.vpc_id

  tags = {
    Name = "logger-pub-rt"
  }
}

#Define Public Route Table
resource "aws_route_table" "pub-rt" {
  vpc_id = module.pub_vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.logger-igw.id
  }

  tags = {
    Name = "logger-pub-rt"
  }
}

#Define pub-rt Subnet Association
resource "aws_route_table_association" "pub-rt-assoc" {
  route_table_id = aws_route_table.pub-rt.id
  subnet_id = module.pub_vpc.private_subnets[0]
}

#Define Public EC2 Security Group
resource "aws_security_group" "logger_pub_sg" {
  name = var.pub_security_group_name
  description = "Security Group for Public EC2 Instance"
  vpc_id = module.pub_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.logger_pub_sg.id
  cidr_ipv4         = module.pub_vpc.vpc_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.logger_pub_sg.id
  cidr_ipv4         = module.pub_vpc.vpc_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.logger_pub_sg.id
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
  subnet_id     = module.pub_vpc.public_subnets[0]
  ami           = var.ami 
  vpc_security_group_ids = [aws_security_group.logger_pub_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ubuntu/boot
    apt-get update -y
    apt-get install -y unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    echo "* * * * * ubuntu aws s3 cp /home/ubuntu/boot/boots.log s3://datacenter-s3-logs-18009/datacenter-priv-vpc/boot/boots.log" \
      >> /etc/cron.d/push-logs
  EOF

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name = "logger-pub-ec2"
  }
}

