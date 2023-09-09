# provider

provider "aws" {
  region = "us-east-1"
  profile = "default"
}
# IAM role for EKS

resource "aws_iam_role" "eksrole" {
  name = "eks_role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole",
          Effect = "Allow",
          Principal = {
            Service = "eks.amazonaws.com"
          }
        }]
    }
  )
}

# VPC creation

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "eks_vpc"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks_igw"
  }
}

resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }
}

resource "aws_subnet" "eks_sn1" {
  availability_zone = "us-east-1a"
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks_sn1"
  }
}

resource "aws_subnet" "eks_sn2" {
  availability_zone = "us-east-1b"
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks_sn2"
  }
}

resource "aws_subnet" "eks_sn3" {
  availability_zone = "us-east-1c"
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks_sn3"
  }
}

resource "aws_route_table_association" "eks_rt_associate1" {
  route_table_id = aws_route_table.eks_rt.id
  subnet_id = aws_subnet.eks_sn1.id
}

resource "aws_route_table_association" "eks_rt_associate2" {
  route_table_id = aws_route_table.eks_rt.id
  subnet_id = aws_subnet.eks_sn2.id
}

resource "aws_route_table_association" "eks_rt_associate3" {
  route_table_id = aws_route_table.eks_rt.id
  subnet_id = aws_subnet.eks_sn3.id
}

# EKS cluster creation

resource "aws_eks_cluster" "kriscluster" {
  name     = "Sep-practice"
  role_arn = aws_iam_role.eksrole.arn

  vpc_config {
    subnet_ids = [aws_subnet.eks_sn1.id, aws_subnet.eks_sn2.id, aws_subnet.eks_sn3.id]
  }
}

resource "aws_iam_role_policy_attachment" "eks_policy_attachment1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eksrole.name
}
resource "aws_iam_role_policy_attachment" "eks_policy_attachment2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role = aws_iam_role.eksrole.name
}

# IAM role for nodegroup

resource "aws_iam_role" "iam_ng" {
  name = "iam_ng"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement =[{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }
    ]
  }
  )
}

resource "aws_iam_role_policy_attachment" "ngpol1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.iam_ng.name
}
resource "aws_iam_role_policy_attachment" "ngpol2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.iam_ng.name
}
resource "aws_iam_role_policy_attachment" "ngpol3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.iam_ng.name
}

# Nodegroup

resource "aws_eks_node_group" "eks_ng" {
  cluster_name  = aws_eks_cluster.kriscluster.name
  node_group_name = "krisng"
  node_role_arn = aws_iam_role.iam_ng.arn
  subnet_ids = [aws_subnet.eks_sn1.id, aws_subnet.eks_sn2.id, aws_subnet.eks_sn3.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }
}
