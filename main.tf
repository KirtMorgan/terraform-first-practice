provider "aws"{
  region = "eu-west-1"
}
resource "aws_vpc" "kirts_vpc" {
  cidr_block = "10.11.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}
resource "aws_subnet" "public-subnet" {
  vpc_id = "${var.vpc_id}"
  cidr_block = "10.120.122.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "${var.name}-public-subnet"
  }
}
resource "aws_subnet" "private-subnet" {
  vpc_id = "${var.vpc_id}"
  cidr_block = "10.120.123.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "${var.name}-private-subnet"
  }
}
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${var.vpc_id}"
  tags = {
    Name = "${var.name}-internet-gateway"
  }
}
resource "aws_route_table" "web-public-rt" {
  vpc_id = "${var.vpc_id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
  tags = {
    Name = "${var.name}-public-route-table"
  }
}
resource "aws_route_table_association" "web-public-rt" {
  subnet_id = "${aws_subnet.public-subnet.id}"
  route_table_id = "${aws_route_table.web-public-rt.id}"
}
resource "aws_route_table" "web-private-rt" {
  vpc_id = "${var.vpc_id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
  tags = {
    Name = "${var.name}-private-route-table"
  }
}
resource "aws_route_table_association" "web-private-rt" {
  subnet_id = "${aws_subnet.private-subnet.id}"
  route_table_id = "${aws_route_table.web-private-rt.id}"
}
resource "aws_security_group" "sg_web_public" {
  name = "vpc_kirtpub_web"
  description = "Allow incoming HTTP connections & SSH access"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["212.161.55.68/32"]
  }
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  tags = {
    Name = "${var.name}-security-group-public"
  }
}
resource "aws_security_group" "sg_web_private" {
  name = "vpc_kirtpri_web"
  description = "Allow incoming HTTP connections & SSH access"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["212.161.55.68/32"]
  }
  vpc_id = "${var.vpc_id}"
  tags = {
    Name = "${var.name}-security-group-private"
  }
}
resource "aws_instance" "app_instance_public"{
  ami = "${var.app_ami_id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.kirtpair.id}"
  subnet_id = "${aws_subnet.public-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_web_public.id}"]
  tags = {
    Name = "${var.name}-public-app"
  }
}
resource "aws_instance" "app_instance_private"{
  ami = "${var.app_ami_id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.kirtpair.id}"
  subnet_id = "${aws_subnet.private-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_web_private.id}"]
  tags = {
    Name = "${var.name}-private-app"
  }
}
resource "aws_key_pair" "kirtpair" {
  key_name = "terraformkirt"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
