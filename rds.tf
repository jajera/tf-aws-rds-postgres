locals {
  db = {
    log_group_names = ["postgresql", "upgrade"]
  }
  current = {
    user_id = split("/", data.aws_caller_identity.current.arn)[1]
  }
}

resource "aws_cloudwatch_log_group" "example" {
  count             = length(local.db.log_group_names)
  name              = "/aws/rds/instance/${var.use_case.name}-${random_string.suffix.result}/${local.db.log_group_names[count.index]}"
  retention_in_days = 7

  tags = {
    Name    = "tf-log-group-${local.db.log_group_names[count.index]}-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "random_password" "example" {
  length           = 16
  special          = true
  override_special = "_!#%&*()-<=>?[]^_{|}~"
}

resource "aws_kms_key" "example" {
  description              = "KMS key for cross region automated backups replication"
  enable_key_rotation      = true
  is_enabled               = true
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  multi_region             = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Default"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "KeyOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/tf-dev-administrator-role/${local.current.user_id}"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "tf-${var.use_case.name}-kms-key-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_kms_alias" "example" {
  name_prefix   = "alias/rds/${var.use_case.name}-${random_string.suffix.result}-"
  target_key_id = aws_kms_key.example.id
}

resource "aws_iam_role" "enhanced-monitoring" {
  name_prefix = "tf-${var.use_case.name}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  description = "Description for monitoring role"

  tags = {
    Name    = "tf-${var.use_case.name}-iam-role-enhanced-monitoring-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_iam_role_policy_attachment" "enhanced-monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.enhanced-monitoring.name
}

resource "aws_secretsmanager_secret" "example" {
  name                    = "tf-${var.use_case.name}-secretmanager-secret-example-1-${random_string.suffix.result}"
  recovery_window_in_days = 0

  tags = {
    Name    = "tf-${var.use_case.name}-secretsmanager-secret-example-1-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = "{\"example-1\": \"${random_password.example.result}\"}"
}

resource "aws_db_instance" "example" {
  allocated_storage                     = 5
  storage_type                          = "gp2"
  engine                                = "postgres"
  engine_version                        = "14"
  instance_class                        = "db.t3.micro"
  identifier                            = "tf-${var.use_case.name}-rds-example-1-${random_string.suffix.result}"
  username                              = "ec2user"
  password                              = random_password.example.result
  parameter_group_name                  = "default.postgres14"
  db_subnet_group_name                  = aws_db_subnet_group.example.name
  vpc_security_group_ids                = [aws_security_group.example.id]
  multi_az                              = true
  backup_retention_period               = 1
  backup_window                         = "03:00-06:00"
  maintenance_window                    = "mon:00:00-mon:03:00"
  storage_encrypted                     = true
  deletion_protection                   = false
  apply_immediately                     = false
  skip_final_snapshot                   = true
  copy_tags_to_snapshot                 = false
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.enhanced-monitoring.arn
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  max_allocated_storage                 = 5
  port                                  = 5432

  tags = {
    Name    = "tf-${var.use_case.name}-db-instance-example-1-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }

  depends_on = [
    aws_cloudwatch_log_group.example,
    aws_db_parameter_group.example
  ]
}

resource "aws_db_parameter_group" "example" {
  name_prefix = "tf-${var.use_case.name}-"
  family      = "postgres14"
  description = "tf-${var.use_case.name}-${random_string.suffix.result} parameter group"

  parameter {
    apply_method = "immediate"
    name         = "autovacuum"
    value        = "1"
  }

  parameter {
    apply_method = "immediate"
    name         = "client_encoding"
    value        = "utf8"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = {
    Name      = "tf-${var.use_case.name}-db-param-grp-example-${random_string.suffix.result}"
    Owner     = var.use_case.owner
    UseCase   = var.use_case.name
    Sensitive = "low"
  }
}

resource "aws_db_instance" "replica" {
  instance_class                        = "db.t3.micro"
  identifier                            = "tf-${var.use_case.name}-rds-replica-${random_string.suffix.result}"
  replicate_source_db                   = aws_db_instance.example.identifier
  storage_type                          = "gp2"
  engine                                = "postgres"
  engine_version                        = "14"
  vpc_security_group_ids                = [aws_security_group.example.id]
  multi_az                              = true
  apply_immediately                     = false
  storage_encrypted                     = true
  copy_tags_to_snapshot                 = false
  max_allocated_storage                 = 5
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.enhanced-monitoring.arn
  parameter_group_name                  = aws_db_parameter_group.example.name
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  port                                  = 5432
  skip_final_snapshot                   = true

  tags = {
    Name    = "tf-${var.use_case.name}-db-replica-1-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_kms_key" "replica" {
  description              = "KMS key for cross region automated backups replication"
  enable_key_rotation      = true
  is_enabled               = true
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  multi_region             = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Default"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "KeyOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/tf-dev-administrator-role/${local.current.user_id}"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "tf-${var.use_case.name}-kms-key-replica-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }

  provider = aws.replica
}

resource "aws_db_instance_automated_backups_replication" "example" {
  source_db_instance_arn = aws_db_instance.example.arn
  kms_key_id             = aws_kms_key.replica.arn
  retention_period       = 1

  provider = aws.replica
}
