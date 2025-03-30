data "local_file" "db_users_data" {
  filename = "iamusers.json"
}

locals {
  # 解析 JSON 文件为用户列表
  users = jsondecode(data.local_file.db_users_data.content)
}
data "aws_s3_bucket_object" "check_file" {
  bucket = "onewonder-tfstate"
  key    = "github/iamusers.json"
}
