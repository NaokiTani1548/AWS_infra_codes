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
resource "aws_spot_instance_request" "spot-db-test" {
    #spot instance request
    wait_for_fulfillment            = "true"
    spot_type                       = "persistent"
    instance_interruption_behaviour = "stop"

    tags = {
        Name = "${var.project}-${var.env}-spot-db"
        Project = var.project
        Env = var.env
        Type = "spot"
    }

    lifecycle {
        ignore_changes = [ "id" ]
    }

    ami                         = data.aws_ami.app.id
    availability_zone           = "ap-northeast-1c"
    ebs_optimized               = false
    instance_type               = "t2.micro"
    key_name                    = aws_key_pair.keypair.key_name
    associate_public_ip_address = true
    subnet_id = var.public1ID
    vpc_security_group_ids = [
        aws_security_group.db_sg.id
    ]
    user_data = <<-EOF
            #!/bin/bash
            # ファイルシステムの作成
            mkfs -t xfs /dev/xvdf
            
            # マウントポイントの作成
            mkdir /data
            
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

            # ログファイルの作成
            sudo touch /var/log/mysqld.log

            # データディレクトリの移動
            sudo mv /var/lib/mysql /data/
            sudo ln -s /data/mysql /var/lib/mysql

            # 権限の設定
            sudo chown -R mysql:mysql /data/mysql
            sudo chmod 750 /data/mysql

            # MySQLの起動
            sudo systemctl start mysqld

            # サービスの有効化
            sudo systemctl enable mysqld
            EOF
}

resource "aws_spot_instance_request" "spot-db-test-destination" {
    #spot instance request
    wait_for_fulfillment            = "true"
    spot_type                       = "persistent"
    instance_interruption_behaviour = "stop"

    tags = {
        Name = "${var.project}-${var.env}-spot-db-destination"
        Project = var.project
        Env = var.env
        Type = "spot"
    }

    lifecycle {
        ignore_changes = [ "id" ]
    }

    ami                         = data.aws_ami.app.id
    availability_zone           = "ap-northeast-1c"
    ebs_optimized               = false
    instance_type               = "t2.micro"
    key_name                    = aws_key_pair.keypair.key_name
    associate_public_ip_address = true
    subnet_id = var.public1ID
    vpc_security_group_ids = [
        aws_security_group.db_sg.id
    ]
    user_data = <<-EOF
            #!/bin/bash
            # パッケージの更新
            sudo yum update -y

            # 既存パッケージの削除
            sudo yum remove -y mariadb-*

            # MySQLのリポジトリをyumに追加
            sudo yum localinstall -y https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm

            # MySQLのインストール
            sudo yum install -y --enablerepo=mysql80-community mysql-community-server
            sudo yum install -y --enablerepo=mysql80-community mysql-community-devel

            # ログファイルの作成
            sudo touch /var/log/mysqld.log

            # マウントポイントの作成
            sudo mkdir /data

            # サービスの有効化
            sudo systemctl enable mysqld
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
    depends_on = [ aws_spot_instance_request.spot-db-test ]
    device_name = "/dev/xvdf"
    instance_id = aws_spot_instance_request.spot-db-test.spot_instance_id
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