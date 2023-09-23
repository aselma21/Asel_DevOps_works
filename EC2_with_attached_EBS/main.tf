provider "aws" {
    region = var.region
}
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "pk" {
  key_name   = "myKey"        
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./myKey.pem"
  }
}

resource "aws_vpc" "homework" {
  cidr_block = var.cidr_block

  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "homework" {
  vpc_id = "${aws_vpc.homework.id}"

  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "homework" {
  vpc_id            = "${aws_vpc.homework.id}"
  cidr_block        = var.cidr_block_subnets
}

resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.homework.id}"

  tags = {
    Name   = var.rt_name
    source = "terraform"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = "${aws_route_table.public_route.id}"
  destination_cidr_block = var.destination_cidr_block
  gateway_id             = "${aws_internet_gateway.homework.id}"
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = "${aws_subnet.homework.id}"
  route_table_id = "${aws_route_table.public_route.id}"
}

resource "aws_security_group" "ssh_http" {
  name_prefix = var.name_prefix
  vpc_id = "${aws_vpc.homework.id}"
  description = "Allow  traffic for http and ssh"

  
  ingress {
    from_port   = var.sg_inbound_ports
    to_port     = var.sg_inbound_ports
    protocol    = var.sg_protocol
    cidr_blocks = var.cidr_blocks
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = var.sg_http_inbound_ports
    to_port     = var.sg_http_inbound_ports
    protocol    = var.sg_http_protocol
    cidr_blocks = var.cidr_blocks
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}



data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = var.ami_name
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}


resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = "myKey" 
  vpc_security_group_ids  = [aws_security_group.ssh_http.id]
  subnet_id     = "${aws_subnet.homework.id}"
  user_data = "${file("data.sh")}"
  associate_public_ip_address = true
  tags = {
      Name = var.instance_name
  }

}

resource "aws_eip" "ip" {
  instance = aws_instance.web.id
  vpc      = true
}


resource "aws_ebs_volume" "ebs_att" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.ebs_att.id
  instance_id = aws_instance.web.id
}

