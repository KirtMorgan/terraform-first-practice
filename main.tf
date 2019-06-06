provider "aws"{
  region = "eu-west-1"
}
resource "aws_vpc" "kirts_vpc" {
  cidr_block = "10.120.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "kirts_vpc"
  }
}
resource "aws_subnet" "public-subnet" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  cidr_block = "10.120.122.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "kirts_public_subnet"
  }
}
resource "aws_subnet" "private-subnet" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  cidr_block = "10.120.123.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "kirts_private_subnet"
  }
}
resource "aws_internet_gateway" "kmgw" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  tags = {
    Name = "kirts_gateway"
  }
}
resource "aws_route_table" "web-public-rt" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.kmgw.id}"
  }
  tags = {
    Name = "public_subnet_rt"
  }
}
resource "aws_route_table_association" "web-public-rt" {
  subnet_id = "${aws_subnet.public-subnet.id}"
  route_table_id = "${aws_route_table.web-public-rt.id}"
}
resource "aws_route_table" "web-private-rt" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.kmgw.id}"
  }
  tags = {
    Name = "private_subnet_rt"
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
    Name = "sg_web_public"
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
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  tags = {
    Name = "sg_web_private"
  }
}
resource "aws_instance" "app_instance_public"{
  ami = "ami-0b45d039456f24807"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.kirtpair.id}"
  subnet_id = "${aws_subnet.public-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_web_public.id}"]
  tags = {
    Name = "kirts_public_app"
  }
}
resource "aws_instance" "app_instance_private"{
  ami = "ami-0b45d039456f24807"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.kirtpair.id}"
  subnet_id = "${aws_subnet.private-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_web_private.id}"]
  tags = {
    Name = "kirts_private_app"
  }
}
resource "aws_key_pair" "kirtpair" {
  key_name = "terraformkirt"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
