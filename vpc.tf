resource "aws_vpc" "example" {
  cidr_block           = var.vpc_network.entire_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "tf-${var.use_case.name}-vpc-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_subnet" "database" {
  count             = length(var.vpc_network.database_subnets)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.vpc_network.database_subnets[count.index]
  vpc_id            = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-subnet-database-${element(data.aws_availability_zones.available.names, count.index)}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_subnet" "private" {
  count             = length(var.vpc_network.private_subnets)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.vpc_network.private_subnets[count.index]
  vpc_id            = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-subnet-private-${element(data.aws_availability_zones.available.names, count.index)}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_subnet" "public" {
  count             = length(var.vpc_network.public_subnets)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.vpc_network.public_subnets[count.index]
  vpc_id            = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-subnet-public-${element(data.aws_availability_zones.available.names, count.index)}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_default_network_acl" "example" {
  default_network_acl_id = aws_vpc.example.default_network_acl_id

  egress {
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
  }
  egress {
    rule_no         = 101
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
  }

  ingress {
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
  }
  ingress {
    rule_no         = 101
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
  }

  lifecycle {
    ignore_changes = [
      subnet_ids
    ]
  }

  tags = {
    Name    = "tf-${var.use_case.name}-default-nacl-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_default_route_table" "example" {
  default_route_table_id = aws_vpc.example.default_route_table_id

  timeouts {
    create = "5m"
    update = "5m"
  }

  tags = {
    Name    = "tf-${var.use_case.name}-default-route-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-igw-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-route-tbl-private-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_route_table_association" "database" {
  count          = length(var.vpc_network.database_subnets)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.database[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.vpc_network.private_subnets)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_default_route_table.example.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example.id

  timeouts {
    create = "5m"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-route-tbl-public-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.vpc_network.public_subnets)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_db_subnet_group" "example" {
  name        = "tf-${var.use_case.name}-db-subnet-group-example-${random_string.suffix.result}"
  description = "Database subnet group for Postgres"

  subnet_ids = concat(
    [for s in aws_subnet.private : s.id],
    [for s in aws_subnet.public : s.id]
  )

  tags = {
    Name    = "tf-${var.use_case.name}-db-subnet-group-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_security_group" "example" {
  description = "tf-${var.use_case.name}-sg-example-${random_string.suffix.result}"
  name_prefix = "tf-${var.use_case.name}-"
  vpc_id      = aws_vpc.example.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  timeouts {
    create = "10m"
    delete = "15m"
  }

  tags = {
    Name    = "tf-${var.use_case.name}-sg-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}

resource "aws_security_group_rule" "example" {
  description       = "PostgreSQL access from within VPC"
  from_port         = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.example.id
  to_port           = 5432
  type              = "ingress"
  cidr_blocks       = ["10.0.0.0/16"]
}

resource "aws_default_security_group" "example" {
  revoke_rules_on_delete = true
  vpc_id                 = aws_vpc.example.id

  tags = {
    Name    = "tf-${var.use_case.name}-dsg-example-${random_string.suffix.result}"
    Owner   = var.use_case.owner
    UseCase = var.use_case.name
  }
}
