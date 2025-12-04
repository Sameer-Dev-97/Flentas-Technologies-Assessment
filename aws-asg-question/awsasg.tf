variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ASG"
  type        = list(string)
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

# ALB + TG + Listener
resource "aws_lb" "Sameer_alb" {
  name               = "Sameer-ALB"  
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.Sameer-private-subnet1.id
  security_groups    = [aws_security_group.alb_sg.id]

  tags = { Name = "Sameer-ALB" }
}

resource "aws_lb_target_group" "Sameer_tg" {
  name        = "Sameer-target-group" 
  port        = 80
  protocol    = "HTTP"
  vpc_id = aws_vpc.Sameer-vpc.id
  target_type = "instance"

  health_check {
    path     = "/"
    protocol = "HTTP"
    interval = 30
  }

  tags = { Name = "Sameer-target-group" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.Sameer_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Sameer_tg.arn
  }
}


# AWS Launch Instance

resource "aws_launch_template" "Sameer_template" {
  name_prefix   = "Sameer-template"          
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl enable httpd
systemctl start httpd
echo "<h1>Served by ASG instance</h1>" > /var/www/html/index.html
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Sameer-asg-instance"
    }
  }
}


# Auto Scaling Group

resource "aws_autoscaling_group" "Sameer_autoscaling" {
  name                      = "Sameer-autoscaling"  
  desired_capacity          = var.desired_capacity
  max_size                  = 3
  min_size                  = 1

  launch_template {
    id      = aws_launch_template.Sameer_template.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = [
    aws_lb_target_group.Sameer_tg.arn
  ]

  health_check_type        = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "Sameer-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb_listener.http]
}

