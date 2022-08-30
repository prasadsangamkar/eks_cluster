module "vpc" {
  
  source = "/home/prasad/eks/Module"
  cidr = "10.0.0.0/16"
  instance_tenancy = "default"
  tag_name = "dev"
  app_subnet = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

}
