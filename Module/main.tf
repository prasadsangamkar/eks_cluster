##### VPC #####

provider "aws" {
 region = "us-east-1"
}

resource "aws_vpc" "main" {
    cidr_block       = var.cidr
    instance_tenancy = var.instance_tenancy
    tags = {
      Name = var.tag_name
    }
}
##### IGW #####

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id
  tags = {
      Name = var.tag_name
    }
}

##### Subnet #####

resource "aws_subnet" "mysubnets" {
  count = length(var.app_subnet)  > 0 ? length(var.app_subnet) : 0
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.app_subnet, count.index)
  availability_zone = element(var.azs, count.index)
  map_public_ip_on_launch = true
  

  tags = {
      Name = var.tag_name
    }
}

##### RT #####

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  tags = {
      Name = var.tag_name
    }
}

##### Route for IGW #####

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.app_subnet)
  subnet_id      = element(aws_subnet.mysubnets.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

##### SG #####

resource "aws_security_group" "eks_cluster" {
  name        = "aws_eks_security_group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = var.tag_name
  }
}

resource "aws_security_group_rule" "cluster_inbound" {
  from_port                = 0
  protocol                 = "tcp"
  to_port                  = 65535
  type                     = "ingress"
  security_group_id        = aws_security_group.eks_cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

########## EKS Cluster ##########
#################################

resource "aws_iam_role" "eks_role" {
  name = "eks_cluster_role"
  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
       "Effect": "Allow",
       "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY

  tags = {
    Name = var.tag_name
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

######### Worker Node Iam Policy ############

resource "aws_iam_role" "node" {
  name = "worker-group-iam-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

########### EKS Cluster ############

resource "aws_eks_cluster" "this" {
  name     = "Test-Eks-Cluster"
  role_arn = aws_iam_role.eks_role.arn
  version  = "1.21"

  vpc_config {
    # security_group_ids      = [aws_security_group.eks_cluster.id, aws_security_group.eks_nodes.id]
    subnet_ids              = flatten([aws_subnet.mysubnets[*].id])
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  tags = {
      Name = var.tag_name
    }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]
}

####### Worker Node ##########

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.tag_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.mysubnets[*].id

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 20
  instance_types = ["t2.medium"]

  tags = {
      Name = var.tag_name
    }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}
