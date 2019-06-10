provider "aws"{
  region = "eu-west-1"
}
resource "aws_vpc" "kirts_vpc" {
  cidr_block = "10.120.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}
resource "aws_subnet" "public-subnet" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  cidr_block = "10.120.122.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "${var.name}-public-subnet"
  }
}
resource "aws_subnet" "private-subnet" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  cidr_block = "10.120.123.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "${var.name}-private-subnet"
  }
}
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
  tags = {
    Name = "${var.name}-internet-gateway"
  }
}
resource "aws_route_table" "web-public-rt" {
  vpc_id = "${aws_vpc.kirts_vpc.id}"
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
  vpc_id = "${aws_vpc.kirts_vpc.id}"
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
  ingress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
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
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    cidr_blocks =  ["10.120.122.0/24"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["212.161.55.68/32"]
  }
  vpc_id = "${aws_vpc.kirts_vpc.id}"
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
  user_data = "${data.template_file.public_app_init.rendered}"
  tags = {
    Name = "${var.name}-public-app"
  }
}
resource "aws_instance" "app_instance_private"{
  ami = "${var.db_ami_id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.kirtpair.id}"
  subnet_id = "${aws_subnet.private-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_web_private.id}"]
  user_data = "${data.template_file.private_app_init.rendered}"
  tags = {
    Name = "${var.name}-private-app"
  }
}
resource "aws_key_pair" "kirtpair" {
  key_name = "terraformkirt"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
data "template_file" "public_app_init"{
  template = "${file("./scripts/app/${var.app_run}")}"
}
data "template_file" "private_app_init"{
  template = "${file("./scripts/app/${var.db_run}")}"
}

# Create a new load balancer
resource "aws_elb" "public_load_balancer" {
  name               = "${var.name}-public-terraform-elb"
  subnets = ["${aws_subnet.public-subnet.id}"]

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 20
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = ["${aws_instance.app_instance_public.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${var.name}-public-terraform-elb"
  }
}

resource "aws_launch_configuration" "team1_public" {
  name = "${var.name}-launch-config-public"
  image_id = "${var.app_ami_id}"
  instance_type = "t2.micro"
  ebs_optimized = false
  security_groups = ["${aws_security_group.sg_web_public.id}"]

}

resource "aws_autoscaling_group" "autoscaling_group_public" {
  name                      = "${var.name}_autoscaling_group_public"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.team1_public.name}"
  vpc_zone_identifier       = ["${aws_subnet.public-subnet.id}"]
  load_balancers = ["${aws_elb.public_load_balancer.id}"]
  tags = [{
  key = "Name"
  value = "${var.name}_AutoScaling_Instance_Public"
  propagate_at_launch = true
  }]
}

resource "aws_elb" "load_balancer_private" {
  name               = "${var.name}-private-terraform-elb"
  subnets = ["${aws_subnet.public-subnet.id}"]

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 20
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = ["${aws_instance.app_instance_private.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${var.name}-private-terraform-elb"
  }
}

resource "aws_launch_configuration" "team1_private" {
  name = "${var.name}-launch-config-private"
  image_id = "${var.db_ami_id}"
  instance_type = "t2.micro"
  ebs_optimized = false
  security_groups = ["${aws_security_group.sg_web_private.id}"]

}

resource "aws_autoscaling_group" "autoscaling_group_private" {
  name                      = "${var.name}_autoscaling_group_private"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.team1_private.name}"
  vpc_zone_identifier       = ["${aws_subnet.private-subnet.id}"]
  load_balancers = ["${aws_elb.load_balancer_private.id}"]
  tags = [{
  key = "Name"
  value = "${var.name}_AutoScaling_Instance_Private"
  propagate_at_launch = true
  }]
}
