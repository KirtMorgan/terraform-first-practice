variable "vpc_id" {
default ="aws_vpc.kirts_vpc.id"
}
variable "name" {
default ="Team1"
}
variable "app_ami_id" {
default ="ami-074844b6a187fa712"
}
variable "db_ami_id" {
default ="ami-09dc8417351e5cc57"
}
variable "app_run" {
default ="init.sh.tpl"
}
variable "db_run" {
default ="mongo_init.sh.tpl"
}
