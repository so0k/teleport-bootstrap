resource "aws_security_group" "node" {
  name        = "${var.name_prefix}-security-group"
  description = "${var.name_prefix} security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-security-group"
  })

  egress {
    description      = "Unrestricted egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "cloudinit_config" "node" {
  gzip          = var.userdata_gzip
  base64_encode = true
  part {
    # https://cloudinit.readthedocs.io/en/latest/topics/format.html#user-data-script
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/config/cloud-init.sh.tpl", {
      name_prefix         = var.name_prefix
      datadog_api_key_arn = var.datadog_api_key_arn
      datadog_host_tags   = var.datadog_host_tags
      bootstrap_commands  = var.bootstrap_commands
    })
  }
}

resource "aws_launch_template" "node" {
  name                                 = "${var.name_prefix}-node"
  vpc_security_group_ids               = concat(var.security_group_ids, [aws_security_group.node.id])
  image_id                             = var.ami_id
  instance_type                        = var.instance_types[0]
  instance_initiated_shutdown_behavior = "terminate"
  disable_api_stop                     = false
  disable_api_termination              = false

  user_data = data.cloudinit_config.node.rendered

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.ebs_root_volume_size
      volume_type = "gp3"
      encrypted   = var.encryption
      kms_key_id  = var.kms_key_id
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.node.name
  }

  dynamic "tag_specifications" {
    for_each = ["instance", "network-interface", "volume"]

    content {
      resource_type = tag_specifications.value

      tags = merge(var.tags, {
        Name = "${var.name_prefix}-${tag_specifications.value}"
      })
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }
}

resource "aws_autoscaling_group" "node" {
  name_prefix         = var.name_prefix
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = var.asg_scale_up_desired
  min_size            = var.asg_min
  max_size            = var.asg_max
  health_check_type   = "EC2"

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.use_spot_instances ? 0 : 1
      on_demand_percentage_above_base_capacity = var.use_spot_instances ? 0 : 100
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.node.id
        version            = aws_launch_template.node.latest_version
      }
      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  instance_refresh {
    strategy = "Rolling"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-node"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  timeouts {
    delete = "15m"
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}

resource "aws_autoscaling_schedule" "scale_down" {
  count                  = var.hour_to_scale_down != null ? 1 : 0
  scheduled_action_name  = "${var.name_prefix}-scale-down"
  min_size               = var.asg_min
  max_size               = var.asg_max
  desired_capacity       = var.asg_scale_up_desired
  recurrence             = "0 ${var.hour_to_scale_down} * * *"
  autoscaling_group_name = aws_autoscaling_group.node.name
  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "aws_autoscaling_schedule" "scale_up" {
  count                 = var.hour_to_scale_up != null ? 1 : 0
  scheduled_action_name = "${var.name_prefix}-scale-up"
  min_size              = var.asg_min
  max_size              = var.asg_max
  desired_capacity      = var.asg_scale_down_desired
  # UTC 23:00 SUN == SGT 07:00 MON
  # UTC 23:00 THU == SGT 07:00 FRI
  recurrence             = "0 ${var.hour_to_scale_up} * * SUN-THU"
  autoscaling_group_name = aws_autoscaling_group.node.name
  lifecycle {
    ignore_changes = [start_time]
  }
}
