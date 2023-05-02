resource "aws_s3_bucket" "example" {
  bucket = "aksdjlkadjlkfjakld"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}
