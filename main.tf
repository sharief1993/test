provider "aws" {
region = "us-east-1"
}

## vpc
resource "aws_vpc" "vpc"{
cidr_block = "10.0.0.0/16"
tags = {Name = "vpc"}
}

locals{
subnets = {
pbsub1 = {
cidr = "10.0.0.0/24"
zone = "us-east-1a"
pbip = true
tag = "publcsub1" 
}
pbsub2 = {
cidr = "10.0.1.0/24"
zone = "us-east-1b"
pbip = true
tag = "publcsub2"
}
pvsub1 = {
cidr = "10.0.2.0/24"
zone = "us-east-1a"
pbip = false
tag = "privatesub1"
}
pvsub2 = {
cidr = "10.0.3.0/24"
zone = "us-east-1b"
pbip = false
tag = "privatesub2"
}
}
}

##Subnet
resource "aws_subnet" "subs"{
for_each = local.subnets
cidr_block = each.value.cidr
availability_zone = each.value.zone 
map_public_ip_on_launch = each.value.pbip
tags = {Name = each.value.tag}
vpc_id = aws_vpc.vpc.id
}

##Internet gateway
resource "aws_internet_gateway" "igw"{
vpc_id = aws_vpc.vpc.id
tags = {Name = "IGW"}
}

###elastic_ip
resource "aws_eip" "eip"{
vpc = true
tags = {Name = "elasticip"}
}

##Natgateway
resource "aws_nat_gateway" "ngw"{
allocation_id = aws_eip.eip.id
subnet_id = aws_subnet.subs["pbsub1"].id
tags = {Name = "NGW"}
}

##route_table
resource "aws_route_table" "rbig"{
vpc_id = aws_vpc.vpc.id

route{
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.igw.id
}
tags = {Name = "pubrtbl"}
}

resource "aws_route_table" "rbng"{
vpc_id = aws_vpc.vpc.id

route{
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.ngw.id
}
tags = {Name = "pvtrtbl"}
}

##subnet associations
resource "aws_route_table_association" "rtpbs"{
subnet_id = aws_subnet.subs["pbsub1"].id
route_table_id = aws_route_table.rbig.id
}

resource "aws_route_table_association" "rtpbs2"{
subnet_id = aws_subnet.subs["pbsub2"].id
route_table_id = aws_route_table.rbig.id
}

resource "aws_route_table_association" "rtpvs"{
subnet_id = aws_subnet.subs["pvsub1"].id
route_table_id = aws_route_table.rbng.id
}

resource "aws_route_table_association" "rtpvs2"{
subnet_id = aws_subnet.subs["pvsub2"].id
route_table_id = aws_route_table.rbng.id
}

locals{
port = [22,80,443]
}
resource "aws_security_group" "sgrp"{
vpc_id = aws_vpc.vpc.id
dynamic ingress{
for_each = local.port
content{
from_port = ingress.value
to_port = ingress.value
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"] 
}
}
egress{
from_port = 0
to_port = 0
protocol = -1
cidr_blocks = ["0.0.0.0/0"]
}
tags = {Name = "SGRP"}
}

##keypair
resource "aws_key_pair" "key" {
key_name = "khasim"
public_key = file("/root/.ssh/id_rsa.pub")
}

data "aws_ami" "img"{
most_recent = true
owners = ["amazon"]
filter{
name = "name"
values = ["RHEL-9*HVM-*"]
}
}

##instance
resource "aws_instance" "inst"{
ami = data.aws_ami.img.image_id
for_each = aws_subnet.subs
key_name = aws_key_pair.key.key_name
subnet_id = each.value.id
instance_type = "t2.micro"
security_groups = [aws_security_group.sgrp.id]
connection{
user = "ec2-user"
type = "ssh"
private_key = file("/root/.ssh/id_rsa")
host = self.public_ip
}
tags = {Name = "prod"}
}
