resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name" : "my-vpc"
  }
}

resource "aws_subnet" "public-subnet" {
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  vpc_id            = aws_vpc.vpc.id
  tags = {
    "Name" : "public-subnet"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "public-subnet-1" {
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  vpc_id            = aws_vpc.vpc.id
  tags = {
    "Name" : "public-subnet-1"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private-subnet" {
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    "Name" : "private-subnet"
  }
  vpc_id = aws_vpc.vpc.id
}

resource "aws_internet_gateway" "name" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" : "my-internet-gateway"
  }
}

resource "aws_eip" "name" {
  tags = {
    "Name" : "my-eip"
  }
}

resource "aws_nat_gateway" "my-nat" {
  allocation_id = aws_eip.name.id
  subnet_id     = aws_subnet.public-subnet.id
  tags = {
    Name = "myNATGateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" : "my-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" : "my-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.name.id
}

resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my-nat.id
}

resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs-sg" {
  name        = "ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9106
    to_port     = 9106
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public-subnet.id, aws_subnet.public-subnet-1.id]
  tags = {
    "Name" : "my-alb"
  }

}

resource "aws_alb_listener" "name" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.name.arn
  }
}

resource "aws_alb_listener_rule" "prometheus-rule" {
  listener_arn = aws_alb_listener.name.arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.prometheus.arn
  }
  condition {
    path_pattern {
      values = ["/prometheus/*"]
    }
  }

}

resource "aws_alb_listener_rule" "grafana-rule" {
  listener_arn = aws_alb_listener.name.arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.grafana.arn
  }
  condition {
    path_pattern {
      values = ["/grafana/*"]
    }
  }

}

resource "aws_alb_target_group" "name" {
  name        = "my-target-group"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
}

resource "aws_alb_target_group" "prometheus" {
  name        = "my-prometheus-target"
  protocol    = "HTTP"
  port        = 9090
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path = "/prometheus/-/healthy"

  }


}

resource "aws_alb_target_group" "grafana" {
  name        = "my-grafana-target"
  protocol    = "HTTP"
  port        = 3000
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path = "/grafana/api/health"
  }
}


# ECR Repository
resource "aws_ecr_repository" "name" {
  name = "my-application-repository"
}

#ECS Cluster
resource "aws_ecs_cluster" "ecs-cluster" {
  name = "my-ecs-cluster"
  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}

resource "aws_cloudwatch_log_group" "name" {
  name              = "/ecs/my-application-logs"
  retention_in_days = 7
  tags = {
    "Name" : "myECSLOGS"
  }


}

# IAM role for ECS task execution
resource "aws_iam_role" "name" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }

    ]

  })
}

resource "aws_iam_role_policy_attachment" "name" {
  role       = aws_iam_role.name.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "name" {
  family                   = "my-application-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.name.arn
  container_definitions = jsonencode([
    {
      name      = "my-application-container"
      image     = "${aws_ecr_repository.name.repository_url}"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ],
      memory = 1024,
      cpu    = 512,
      log_configuration = {
        log_driver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.name.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }

  }])


}

resource "aws_ecs_service" "name" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.name.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.private-subnet.id]
    security_groups  = [aws_security_group.ecs-sg.id]
    assign_public_ip = true

  }
  load_balancer {
    target_group_arn = aws_alb_target_group.name.arn
    container_name   = "my-application-container"
    container_port   = 5000
  }
  service_registries {

    registry_arn = aws_service_discovery_service.prometheus-sd.arn
  }

}

# Monitoring Setup

## ECR Repo for Prometheus

resource "aws_ecr_repository" "prometheus-repo" {
  name = "prometheus-repository"
}

## ECR Repo for AlertManagee
resource "aws_ecr_repository" "alertmanager-repo" {
  name = "alertmanager-repository"
}

## ECR Repo for cloud watch exporter
resource "aws_ecr_repository" "cloudwatch-exporter-repo" {
  name = "cloudwatch-exporter-repository"
}

# Prometheus Setup

resource "aws_iam_role" "prometheus-task-role" {
  name = "prometheus-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }

    ]

  })
}

resource "aws_iam_role_policy" "name" {
  name = "prometheus-policy"
  role = aws_iam_role.prometheus-task-role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:ListTagsForResource",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_ecs_task_definition" "prometheus-task" {
  family                   = "my-prometheus-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.name.arn
  task_role_arn            = aws_iam_role.prometheus-task-role.arn
  container_definitions = jsonencode([
    {
      name      = "prometheus-container"
      image     = aws_ecr_repository.prometheus-repo.repository_url
      essential = true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
        }
      ],

      memory = 1024,
      cpu    = 512,
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.name.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "prometheus-service" {
  name                              = "prometheus-service"
  cluster                           = aws_ecs_cluster.ecs-cluster.id
  task_definition                   = aws_ecs_task_definition.prometheus-task.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  network_configuration {
    subnets          = [aws_subnet.private-subnet.id]
    security_groups  = [aws_security_group.ecs-sg.id]
    assign_public_ip = true

  }
  load_balancer {
    target_group_arn = aws_alb_target_group.prometheus.arn
    container_name   = "prometheus-container"
    container_port   = 9090
  }
  enable_execute_command = true
}

# Service Discovery setup for App Service

resource "aws_service_discovery_private_dns_namespace" "name" {
  name = "monitoring.local"
  vpc  = aws_vpc.vpc.id
}

resource "aws_service_discovery_service" "prometheus-sd" {
  name = "myapp"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.name.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}

# Garafana Setup

resource "aws_ecs_task_definition" "grafana-task" {
  family                   = "my-grafana-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.name.arn
  container_definitions = jsonencode([
    {
      name      = "grafana-container"
      image     = "grafana/grafana:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ],
      memory = 1024,
      cpu    = 512,
      environment = [
        {
          name  = "GF_SECURITY_ADMIN_USER"
          value = "admin"
        },
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = "admin123"
        },

        {
          "name" : "GF_SERVER_ROOT_URL",
          "value" : "%(protocol)s://%(domain)s/grafana/"
        },
        {
          "name" : "GF_SERVER_SERVE_FROM_SUB_PATH",
          "value" : "true"
        }

      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.name.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "grafana"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "grafana-service" {
  name                              = "grafana-service"
  cluster                           = aws_ecs_cluster.ecs-cluster.id
  task_definition                   = aws_ecs_task_definition.grafana-task.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  network_configuration {
    subnets          = [aws_subnet.private-subnet.id]
    security_groups  = [aws_security_group.ecs-sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.grafana.arn
    container_name   = "grafana-container"
    container_port   = 3000
  }
}

# Alert Manager Setup

resource "aws_ecs_task_definition" "alertmanager-task" {
  family                   = "my-alertmanager-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.name.arn
  container_definitions = jsonencode([
    {
      name      = "alertmanager-container"
      image     = aws_ecr_repository.alertmanager-repo.repository_url
      essential = true
      portMappings = [
        {
          containerPort = 9093
          hostPort      = 9093
        }
      ],
      memory = 1024,
      cpu    = 512,
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.name.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "alertmanager"
        }
      }
    }
  ])

}
resource "aws_service_discovery_service" "alertmanager-sd" {
  name = "alertmanager"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.name.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_ecs_service" "alertmanager-service" {
  name            = "alertmanager-service"
  task_definition = aws_ecs_task_definition.alertmanager-task.arn
  cluster         = aws_ecs_cluster.ecs-cluster.id
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.private-subnet.id]
    security_groups  = [aws_security_group.ecs-sg.id]
    assign_public_ip = true
  }
  service_registries {

    registry_arn = aws_service_discovery_service.alertmanager-sd.arn
  }
}


# CloudWatch Exporter Setup

resource "aws_iam_role" "cloudwatch-role" {
  name = "cloudwatch-exporter-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }

    ]

  })
}

resource "aws_iam_role_policy" "cloudwatch-policy" {
  role = aws_iam_role.cloudwatch-role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_ecs_task_definition" "cloudwatch-exporter-task" {
  family                   = "my-cloudwatch-exporter-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.name.arn
  task_role_arn            = aws_iam_role.cloudwatch-role.arn
  container_definitions = jsonencode([
    {
      name      = "cloudwatch-exporter-container"
      image     = aws_ecr_repository.cloudwatch-exporter-repo.repository_url
      essential = true
      portMappings = [
        {
          containerPort = 9106
          hostPort      = 9106
        }
      ],
      memory = 1024,
      cpu    = 512,
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.name.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "cloudwatch-exporter"
        }
      }
    }
  ])
}

# Service Discovery for CloudWatch Exporter

resource "aws_service_discovery_service" "cloudwatch-exporter-sd" {
  name = "cloudwatch-exporter"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.name.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}
resource "aws_ecs_service" "cloudwatch-exporter" {
  name            = "CloudWatch-Exporter"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.cloudwatch-exporter-task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.private-subnet.id]
    security_groups  = [aws_security_group.ecs-sg.id]
    assign_public_ip = true
  }

  service_registries {

    registry_arn = aws_service_discovery_service.cloudwatch-exporter-sd.arn
  }
}
