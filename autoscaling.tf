
# EC2 Launch Template for Auto Scaling Group
resource "aws_launch_template" "web" {
  name_prefix   = "sz-terraform-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type


  # Bootstrap Nginx with the Ansible playbook on every new EC2
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -euxo pipefail

    # Install Python tooling
    dnf install -y python3 python3-pip

    # Install Ansible into an isolated virtual environment
    python3 -m venv /opt/ansible-venv
    /opt/ansible-venv/bin/pip install ansible-core

    # Decode the Ansible playbook embedded by Terraform
    mkdir -p /opt/sz-terraform-lab
    cat > /opt/sz-terraform-lab/playbook.b64 <<'PLAYBOOK'
    ${filebase64("${path.module}/ansible/deploy_nginx.yml")}
    PLAYBOOK

    base64 -d /opt/sz-terraform-lab/playbook.b64 > /opt/sz-terraform-lab/deploy_nginx.yml

    # Run Ansible against this EC2 instance
    /opt/ansible-venv/bin/ansible-playbook \
      -i 'web,' \
      -c local \
      /opt/sz-terraform-lab/deploy_nginx.yml
  USERDATA
  )

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-asg-ec2"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}


# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name = "${var.project_name}-asg"

  min_size         = 1
  desired_capacity = 2
  max_size         = 3

  vpc_zone_identifier = [
    aws_subnet.public.id,
    aws_subnet.public_2.id
  ]

  target_group_arns = [
    aws_lb_target_group.web.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 600

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_route_table_association.public,
    aws_route_table_association.public_2
  ]

}

# Scale in and out based on average CPU utilization
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}
