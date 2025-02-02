provider "aws" {
  region = "us-east-1" # Define the AWS region
}

# Create a Virtual Private Cloud (VPC)
resource "aws_vpc" "core_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a subnet within the VPC
resource "aws_subnet" "core_subnet" {
  vpc_id                  = aws_vpc.core_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create an internet gateway to allow internet access
resource "aws_internet_gateway" "core_igw" {
  vpc_id = aws_vpc.core_vpc.id
}

# Create a route table for the VPC
resource "aws_route_table" "core_rt" {
  vpc_id = aws_vpc.core_vpc.id
}

# Define a route to allow internet access through the gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.core_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.core_igw.id
}

# Define a security group to allow HTTP and HTTPS traffic
resource "aws_security_group" "core_sg" {
  vpc_id = aws_vpc.core_vpc.id

  ingress {
    from_port   = 80  # Allow HTTP traffic
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443  # Allow HTTPS traffic
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0  # Allow all outbound traffic
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create 25 EC2 instances for the core banking application
resource "aws_instance" "core_vms" {
  count         = 25
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.core_subnet.id
  security_groups = [aws_security_group.core_sg.name]
}

# Create a Load Balancer to distribute traffic
resource "aws_elb" "core_lb" {
  name               = "core-lb"
  security_groups    = [aws_security_group.core_sg.id]
  subnets           = [aws_subnet.core_subnet.id]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }
}

# Create an RDS (Relational Database) instance for data storage
resource "aws_db_instance" "core_db" {
  allocated_storage    = 20  # 20GB storage
  engine              = "mysql"
  instance_class      = "db.t3.micro"
  username           = "admin"
  password           = "password1234"  # Use secrets management in production
  skip_final_snapshot = true
}

# Create an ElastiCache Redis cluster for caching
resource "aws_elasticache_cluster" "core_cache" {
  cluster_id           = "core-cache"
  engine              = "redis"
  node_type           = "cache.t3.micro"
  num_cache_nodes     = 1
}

# Set up Route 53 domain for corebank.com
resource "aws_route53_zone" "core_dns" {
  name = "corebank.com"
}

# Create a DNS record to point corebank.com to the Load Balancer
resource "aws_route53_record" "core_dns_record" {
  zone_id = aws_route53_zone.core_dns.zone_id
  name    = "corebank.com"
  type    = "A"
  alias {
    name                   = aws_elb.core_lb.dns_name
    zone_id                = aws_elb.core_lb.zone_id
    evaluate_target_health = true
  }
}

# Allocate 25 EBS (Elastic Block Store) volumes for storage
resource "aws_ebs_volume" "core_storage" {
  count = 25
  availability_zone = "us-east-1a"
  size             = 10  # 10GB per volume
}
