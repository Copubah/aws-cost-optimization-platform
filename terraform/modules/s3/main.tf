resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project_name}-${var.environment}-app-data-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app-data"
    }
  )
}

# Block public access
resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "app_data" {
  count = var.enable_lifecycle_policies ? 1 : 0

  bucket = aws_s3_bucket.app_data.id

  # Transition to Infrequent Access
  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    filter {
      prefix = ""
    }
  }

  # Transition to Glacier
  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.transition_to_glacier_days
      storage_class = "GLACIER"
    }

    filter {
      prefix = "archive/"
    }
  }

  # Expire old objects
  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = var.expiration_days
    }

    filter {
      prefix = "temp/"
    }
  }

  # Clean up incomplete multipart uploads
  rule {
    id     = "cleanup-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {
      prefix = ""
    }
  }

  # Expire old versions
  rule {
    id     = "expire-old-versions"
    status = var.enable_versioning ? "Enabled" : "Disabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    filter {
      prefix = ""
    }
  }
}

# Logging bucket
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle for logs
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 30
    }

    filter {
      prefix = ""
    }
  }
}

# Enable logging for app data bucket
resource "aws_s3_bucket_logging" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

data "aws_caller_identity" "current" {}
