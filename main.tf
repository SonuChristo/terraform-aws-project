resource "aws_vpc" "name" {
    cidr_block = var.cidr_block
}
resource "aws_subnet" "Subnet1" {
    vpc_id = aws_vpc.name.id
    availability_zone = "sa-east-1"
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch=true
}

resource "aws_subnet" "Subnet2" {
    vpc_id = aws_vpc.name.id
    availability_zone = "sa-east-1"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch=true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.name.id
  
}

resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.name.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
  
}
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.Subnet1.id
    route_table_id = aws_route_table.rt.id
  
}
resource "aws_security_group" "WebSg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.name.id

  ingress {
    description = "SSH"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg"
  }
}
resource "aws_s3_bucket" "example" {
  bucket = "my-s3-terraform-first-bucket"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.example.id
  acl    = "public-read"
}
resource "aws_instance" "Webserver1" {
    ami = "ami-08af887b5731562d3"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.WebSg.id]
    subnet_id = aws_subnet.Subnet1.id
    user_data = base64encode(file("userdata.sh"))
}
resource "aws_instance" "Webserver2" {
    ami = "ami-08af887b5731562d3"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.WebSg.id]
    subnet_id = aws_subnet.Subnet2.id
    user_data = base64encode(file("userdata1.sh"))
}
resource "aws_lb" "myalb" {
    name = "myalb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.WebSg.id]
    subnets = [aws_subnet.Subnet1.id,aws_subnet.Subnet2.id]

    tags = {
        name="myalb"
    }
}
resource "aws_lb_target_group" "mytg" {
    name = "mytg"
    port = 80 
    protocol = "HTTP"
    vpc_id = aws_vpc.name.id

    health_check {
      path = "/"
      port = "traffic-port"
    }
  
}
resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.mytg.arn
    target_id = aws_instance.Webserver1.id
    port = 80
  
}
resource "aws_lb_target_group_attachment" "attach2" {
    target_group_arn = aws_lb_target_group.mytg.arn
    target_id = aws_instance.Webserver2.id
    port = 80
  
}

resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.myalb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      target_group_arn = aws_lb_target_group.mytg.arn
      type = "forward"
    }
  
}
output "lbdnsname" {
    value = aws_lb.myalb.dns_name
  
}