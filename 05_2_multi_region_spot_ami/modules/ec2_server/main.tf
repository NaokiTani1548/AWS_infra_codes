# ---------------------------------------------
# key pair
# ---------------------------------------------
resource "aws_key_pair" "keypair" {
  key_name   = "${var.project}-${var.env}-keypair"
  public_key = file("../../key/spot-db-test.pub")
  tags = {
    Name    = "${var.project}-${var.env}-keypair"
    Project = var.project
    Env     = var.env
  }
}

# ---------------------------------------------
# ami base script
# ---------------------------------------------
resource "aws_instance" "base_ami" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.keypair.key_name
  subnet_id              = var.public1ID
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  associate_public_ip_address = true
  ebs_optimized          = false
  iam_instance_profile = aws_iam_instance_profile.ec2_ebs_profile.name

  tags = {
    Name    = "${var.project}-${var.env}-ondemand-db"
    Project = var.project
    Env     = var.env
    Type    = "ondemand"
  }
  user_data = <<-EOF
    #!/bin/bash

    # パッケージの更新
    dnf update -y

    # 既存パッケージの削除
    # sudo dnf remove -y mariadb-*

    # # MySQLのリポジトリをyumに追加
    # sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm

    # # MySQLのインストール
    # sudo dnf install -y wget
    # wget https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
    # sudo rpm --import RPM-GPG-KEY-mysql-2023
    # sudo dnf --enablerepo=mysql80-community install -y mysql-community-server mysql-community-devel

    # # MySQL起動
    # sudo systemctl start mysqld

  EOF

}


# ---------------------------------------------
# security group
# ---------------------------------------------
resource "aws_security_group" "db_sg" {
  name        = "${var.project}-${var.env}-db-sg"
  description = "Security group for DB server"
  vpc_id      = var.VPCID

  # SSHポートのインバウンドルール
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # または特定のIPアドレス範囲
  }
  # DBポートのインバウンドルール
  ingress {
    from_port   = 3306  # MySQLの場合
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC内からのアクセスのみ
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAMロールの作成
resource "aws_iam_role" "ec2_ebs_role" {
  name = "${var.project}-${var.env}-ec2-ebs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAMポリシーの作成
resource "aws_iam_role_policy" "ec2_ebs_policy" {
  name = "${var.project}-${var.env}-ec2-ebs-policy"
  role = aws_iam_role.ec2_ebs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
            "ssm:SendCommand",
            "ssm:GetCommandInvocation",
            "ssm:DescribeInstanceInformation",
            "ec2:CreateImage",
            "ec2:CreateTags",
            "ec2:DetachVolume",
            "ec2:AttachVolume",
            "ec2:DescribeVolumes",
            "ec2:DescribeVolumeStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAMインスタンスプロファイルの作成
resource "aws_iam_instance_profile" "ec2_ebs_profile" {
  name = "${var.project}-${var.env}-ec2-ebs-profile"
  role = aws_iam_role.ec2_ebs_role.name
}