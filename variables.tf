variable "region" {
    type = string
    default = "us-east-1"
}

variable "default_tags" {
  type    = map(string)
  default = {}
}

variable "key_name" {
  type = string
}

variable "priv_security_group_name" {
  type = string
  default = "logger-priv-sg"
}

variable "pub_security_group_name" {
  type = string
  default = "logger-pub-sg"
  
}

variable "ami" {
  type = string
  default = "ami-0b6d9d3d33ba97d99"
}