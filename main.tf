#Define Private VPC and Subnets
module "priv_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "logger-priv-vpc"
  cidr = "10.10.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.10.1.0/24"]

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

  route {
    cidr_block = module.pub_vpc.vpc_cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }

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

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_priv" {
  security_group_id = aws_security_group.logger_priv_sg.id
  cidr_ipv4         = module.priv_vpc.vpc_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_priv" {
  security_group_id = aws_security_group.logger_priv_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Define Private EC2 Instance
module "priv_ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "priv-logger-ec2"

  instance_type = "t3.micro"
  key_name      = var.key_name
  monitoring    = true
  subnet_id     = module.priv_vpc.private_subnets[0]
  ami           = var.ami 
  vpc_security_group_ids = [aws_security_group.logger_priv_sg.id]

  user_data = templatefile("${path.module}/priv_userdata.sh", {
  private_key    = tls_private_key.logger_key.private_key_pem
  pub_private_ip = module.pub_ec2_instance.private_ip
})
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

  azs             = ["us-east-1d"]
  public_subnets = ["10.20.1.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  create_igw = false
  
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

  route {
    cidr_block = module.priv_vpc.vpc_cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }

  tags = {
    Name = "logger-pub-route"
  }
}

#Define pub-rt Subnet Association
resource "aws_route_table_association" "pub-rt-assoc" {
  route_table_id = aws_route_table.pub-rt.id
  subnet_id = module.pub_vpc.public_subnets[0]
}

#Define Public EC2 Security Group
resource "aws_security_group" "logger_pub_sg" {
  name = var.pub_security_group_name
  description = "Security Group for Public EC2 Instance"
  vpc_id = module.pub_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_pub" {
  security_group_id = aws_security_group.logger_pub_sg.id
  cidr_ipv4         = module.priv_vpc.vpc_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_pub" {
  security_group_id = aws_security_group.logger_pub_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Define Public EC2 Instance
module "pub_ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "pub-logger-ec2"

  instance_type = "t3.micro"
  key_name      = var.key_name
  monitoring    = true
  subnet_id     = module.pub_vpc.public_subnets[0]
  ami           = var.ami 
  vpc_security_group_ids = [aws_security_group.logger_pub_sg.id]
  iam_instance_profile = aws_iam_instance_profile.logger_profile.name

  user_data = templatefile("${path.module}/pub_userdata.sh", {
    pub_key = tls_private_key.logger_key.public_key_openssh
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name = "logger-pub-ec2"
  }
}

resource "aws_s3_bucket" "logger_bucket" {
  bucket = "logger-bucket-314159"
  

  tags = {
    Name        = "Logger bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "logger_bucket" {
  bucket                  = aws_s3_bucket.logger_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logger_bucket" {
  bucket = aws_s3_bucket.logger_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "logger_bucket_role" {
  name = "logger_bucket_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "logger_bucket_policy" {
  name = "bucket_policy"
  role = aws_iam_role.logger_bucket_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::logger-bucket-314159/*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "logger_profile" {
  name = "logger-instance-profile"
  role = aws_iam_role.logger_bucket_role.name
}

#Define VPC Peering
resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id   = module.pub_vpc.vpc_id
  vpc_id        = module.priv_vpc.vpc_id
  auto_accept   = true 

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}
