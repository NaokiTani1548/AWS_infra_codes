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
# spot instance request
# ---------------------------------------------
resource "aws_spot_instance_request" "spot-db" {
    #spot instance request
    wait_for_fulfillment            = "true"
    spot_type                       = "persistent"
    instance_interruption_behavior = "stop"

    tags = {
        Name = "${var.project}-${var.env}-spot-db"
        Project = var.project
        Env = var.env
        Type = "spot"
    }

    lifecycle {
        ignore_changes = [ "id" ]
    }

    ami                         = "ami-027fff96cc515f7bc"
    availability_zone           = "ap-northeast-1c"
    ebs_optimized               = false
    instance_type               = "t2.micro"
    key_name                    = aws_key_pair.keypair.key_name
    associate_public_ip_address = true
    subnet_id = var.public1ID
    iam_instance_profile = aws_iam_instance_profile.ec2_ebs_profile.name
    vpc_security_group_ids = [
        aws_security_group.db_sg.id
    ]
    user_data = <<-EOF
            #!/bin/bash
            # エラーが発生したら即座に終了
            set -e

            # /dev/xvdf がフォーマットされていなければ初期化
            if ! blkid /dev/xvdf; then
                mkfs -t xfs /dev/xvdf
            fi

            # マウントポイントの作成
            mkdir -p /data
            
            # ボリュームのマウント
            mount /dev/xvdf /data
            
            # 永続的なマウントの設定
            echo "/dev/xvdf /data xfs defaults,nofail 0 2" >> /etc/fstab

            # パッケージの更新
            sudo yum update -y

            # 既存パッケージの削除
            sudo yum remove -y mariadb-*

            # MySQLのリポジトリをyumに追加
            sudo yum localinstall -y https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm

            # MySQLのインストール
            sudo yum install -y --enablerepo=mysql80-community mysql-community-server
            sudo yum install -y --enablerepo=mysql80-community mysql-community-devel

            # MySQLサービスを停止
            sudo systemctl stop mysqld

            # 既存のデータディレクトリをバックアップ
            if [ -d /var/lib/mysql ]; then
                sudo mv /var/lib/mysql /var/lib/mysql.bak
            fi

            # データディレクトリの作成と権限設定
            sudo mkdir -p /data/mysql
            sudo chown -R mysql:mysql /data/mysql
            sudo chmod 750 /data/mysql

            # シンボリックリンクの作成
            sudo ln -sf /data/mysql /var/lib/mysql

            # 初回セットアップ時のMySQL初期化
            if [ ! -d /data/mysql/mysql ]; then
                echo "First time setup: Initializing MySQL..."
                # 既存のデータディレクトリを完全にクリーンアップ
                sudo rm -rf /data/mysql/*
                sudo rm -rf /var/lib/mysql/*
                # MySQLの初期化を実行
                sudo mysqld --initialize --user=mysql
                echo "MySQL initialization completed"
            else
                echo "Using existing MySQL data directory"
            fi

            # ログファイルの作成と権限設定
            sudo touch /var/log/mysqld.log
            sudo chown mysql:mysql /var/log/mysqld.log
            sudo chmod 640 /var/log/mysqld.log

            # SELinuxが有効な場合のみ設定を実行
            if [ "$(getenforce)" != "Disabled" ]; then
                sudo yum install -y policycoreutils-python
                sudo semanage fcontext -a -t mysqld_db_t "/data/mysql(/.*)?"
                sudo restorecon -R /data/mysql
            fi

            # MySQLの起動前にデータディレクトリの権限を再確認
            sudo chown -R mysql:mysql /data/mysql
            sudo chmod -R 750 /data/mysql

            # MySQLの起動
            sudo systemctl start mysqld

            # サービスの有効化
            sudo systemctl enable mysqld

            # 起動確認とログ出力
            for i in {1..30}; do
                if sudo systemctl is-active --quiet mysqld; then
                    echo "MySQL started successfully"
                    # 起動直後のログを確認
                    sudo tail -n 20 /var/log/mysqld.log
                    break
                fi
                if [ $i -eq 30 ]; then
                    echo "MySQL failed to start"
                    # エラー時のログを確認
                    sudo tail -n 50 /var/log/mysqld.log
                    exit 1
                fi
                sleep 1
            done
            EOF
}

resource "aws_ec2_tag" "spot_db_tag" {
  depends_on = [aws_spot_instance_request.spot-db]
  resource_id = aws_spot_instance_request.spot-db.spot_instance_id
  key         = "Name"
  value       = "SpotTest"
}

# ---------------------------------------------
# オンデマンドEC2インスタンス（起動時は停止）
# ---------------------------------------------
resource "aws_instance" "ondemand-db" {
  ami                    = "ami-027fff96cc515f7bc"
  instance_type          = "t2.micro"
  availability_zone      = "ap-northeast-1c"
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

  # 初期停止させておく（apply直後に stop する運用にするか、手動で停止）
  lifecycle {
    ignore_changes = [ "instance_state" ]
  }

  user_data = <<-EOF
              #!/bin/bash
              # エラーが発生したら即座に終了
              set -e

              # パッケージの更新
              sudo yum update -y

              # 既存パッケージの削除
              sudo yum remove -y mariadb-*

              # MySQLのリポジトリをyumに追加
              sudo yum localinstall -y https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm

              # MySQLのインストール
              sudo yum install -y --enablerepo=mysql80-community mysql-community-server
              sudo yum install -y --enablerepo=mysql80-community mysql-community-devel

              # MySQLサービスを停止
              sudo systemctl stop mysqld

              # ログファイルの作成と権限設定
              sudo touch /var/log/mysqld.log
              sudo chown mysql:mysql /var/log/mysqld.log
              sudo chmod 640 /var/log/mysqld.log

              # SELinuxが有効な場合のみ設定を実行
              if [ "$(getenforce)" != "Disabled" ]; then
                  sudo yum install -y policycoreutils-python
                  sudo semanage fcontext -a -t mysqld_db_t "/data/mysql(/.*)?"
                  sudo restorecon -R /data/mysql
              fi
              # データディレクトリの作成
              sudo mkdir -p /data/mysql

              # 既存のシンボリックリンクを削除
              sudo rm -rf /var/lib/mysql

              # 新しいシンボリックリンクを作成
              sudo ln -s /data/mysql /var/lib/mysql

              # 権限の設定
              sudo chown -R mysql:mysql /data/mysql
              sudo chmod -R 750 /data/mysql

              # MySQLの初期化（初回のみ）
              if [ ! -f /data/mysql/mysql ]; then
                  sudo mysqld --initialize-insecure --user=mysql
              fi
              EOF
}

# ---------------------------------------------
# ebs volume
# ---------------------------------------------
resource "aws_ebs_volume" "spot-db-volume" {
    availability_zone = "ap-northeast-1c"
    size = 20
    type = "gp3"
    tags = {
        Name = "${var.project}-${var.env}-spot-db-volume"
        Project = var.project
        Env = var.env
    }
}

resource "aws_volume_attachment" "spot-db-volume-attachment" {
    depends_on = [ aws_spot_instance_request.spot-db ]
    device_name = "/dev/xvdf"
    instance_id = aws_spot_instance_request.spot-db.spot_instance_id
    volume_id = aws_ebs_volume.spot-db-volume.id
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