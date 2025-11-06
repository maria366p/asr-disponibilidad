# ***************** Universidad de los Andes ***********************
# ****** Departamento de Ingeniería de Sistemas y Computación ******
# ********** Arquitectura y diseño de Software - ISIS2503 **********
#
# Infraestructura para experimento ASR de Disponibilidad
# (Gestión de Salidas con Falla de Inventario)
# ******************************************************************

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

provider "aws" {
  region = var.region
}

locals {
  prefix       = "asr"
  project_name = "${local.prefix}-disponibilidad"
  common_tags = {
    Project   = local.project_name
    ManagedBy = "Terraform"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ===================== SECURITY GROUPS ===========================
resource "aws_security_group" "traffic_gestor" {
  name        = "${local.prefix}-traffic-gestor"
  description = "Allow traffic on port 8080"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.prefix}-traffic-gestor" })
}

resource "aws_security_group" "traffic_cb" {
  name        = "${local.prefix}-traffic-cb"
  description = "Expose Kong circuit breaker ports"
  ingress {
    from_port   = 8000
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.prefix}-traffic-cb" })
}

resource "aws_security_group" "traffic_db" {
  name        = "${local.prefix}-traffic-db"
  description = "Allow PostgreSQL access"
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.prefix}-traffic-db" })
}

resource "aws_security_group" "traffic_ssh" {
  name        = "${local.prefix}-traffic-ssh"
  description = "Allow SSH access"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.prefix}-traffic-ssh" })
}

# ===================== INSTANCIAS ================================
# Circuit Breaker - Kong Gateway
resource "aws_instance" "kong" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.traffic_cb.id, aws_security_group.traffic_ssh.id]

  user_data = <<-EOT
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              mkdir -p /opt/kong
              cd /opt/kong
              cat <<EOF > kong.yml
              _format_version: "3.0"
              services:
                - name: inventario
                  url: http://${aws_instance.inventario.private_ip}:8081
                  routes:
                    - name: inventario-route
                      paths: ["/inventario/"]
                      strip_path: false
              upstreams:
                - name: inventario_upstream
                  targets:
                    - target: ${aws_instance.inventario.private_ip}:8081
                      weight: 100
                  healthchecks:
                    active:
                      type: http
                      http_path: /health/
                      timeout: 0.3
                      healthy:
                        interval: 5
                        successes: 1
                      unhealthy:
                        interval: 3
                        http_failures: 1
                        tcp_failures: 1
                        timeouts: 1
              EOF

              docker run -d --name kong --network host \
                -v /opt/kong/kong.yml:/kong/declarative/kong.yml \
                -e KONG_DATABASE=off \
                -e KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml \
                -e KONG_ADMIN_LISTEN=0.0.0.0:8001 \
                -p 8000:8000 -p 8001:8001 \
                kong/kong-gateway:2.7.2.0-alpine
              EOT

  tags = merge(local.common_tags, { Name = "${local.prefix}-kong", Role = "circuit-breaker" })
}

# Servicio de Inventario
resource "aws_instance" "inventario" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.traffic_gestor.id, aws_security_group.traffic_ssh.id]
  user_data = <<-EOT
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3-pip python3-venv git
              mkdir -p /opt/inventario
              cd /opt/inventario
              python3 -m venv venv
              source venv/bin/activate
              pip install fastapi uvicorn psycopg2-binary
              echo "from fastapi import FastAPI; app=FastAPI(); @app.get('/health/')\ndef h(): return {'ok':True}" > app.py
              nohup venv/bin/uvicorn app:app --host 0.0.0.0 --port 8081 &
              EOT
  tags = merge(local.common_tags, { Name = "${local.prefix}-inventario", Role = "inventario" })
}

# Gestor de Bodega
resource "aws_instance" "gestor" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.traffic_gestor.id, aws_security_group.traffic_ssh.id]
  tags = merge(local.common_tags, { Name = "${local.prefix}-gestor", Role = "gestor-bodega" })
}

# Base de datos RDS
resource "aws_db_instance" "rds" {
  allocated_storage    = 10
  engine               = "postgres"
  engine_version       = "16.10"
  instance_class       = "db.t3.micro"
  db_name              = "inventario_db"
  username             = "admin"
  password             = "isis2503"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.traffic_db.id]
  tags = merge(local.common_tags, { Name = "${local.prefix}-rds" })
}

# ===================== OUTPUTS ===============================
output "kong_public_ip" {
  value = aws_instance.kong.public_ip
}
output "gestor_public_ip" {
  value = aws_instance.gestor.public_ip
}
output "inventario_public_ip" {
  value = aws_instance.inventario.public_ip
}
output "rds_endpoint" {
  value = aws_db_instance.rds.address
}
