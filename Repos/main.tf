resource "aws_iam_user" "db_users" {
  for_each = { for user in local.users : user["IAMユーザー"] => user }

  name = each.key

  tags = {
    Policy = each.value["ポリシー"]  # 通过 "ポリシー" 获取策略名称
  }
}