## lambda zip 作り方

```bash
$ zip boot_spot.zip boot_spot.py

# 外部ライブラリを使う場合
# 依存関係
docker run -it --rm amazonlinux:2023 bash
# update
dnf update -y
# python3.9とpipなどをインストール
dnf install -y python3 python3-pip gcc libffi-devel openssl-devel make zip
# バージョン確認
python3 --version  # 3.9.x のはず
mkdir /layer
cd /layer
python3 -m pip install --user --upgrade pip setuptools wheel
# ライブラリをレイヤー用にインストール
pip3 install paramiko==3.2.0 pycrypto==2.6.1 cryptography==3.4.8 bcrypt==3.2.2 -t python/
# zip化
zip -r9 paramiko-layer.zip python/
exit

docker ps
docker cp <container_id>:/layer/paramiko-layer.zip .

aws lambda publish-layer-version \
  --layer-name paramiko-layer \
  --description "paramiko layer" \
  --zip-file fileb://paramiko-layer.zip \
  --compatible-runtimes python3.9 python3.10 python3.11 \
  --region ap-northeast-1
```


## ssh接続
ssh -i ~/.ssh/spot-db-test.pem ec2-user@<public-IP>

### mysqlの起動、確認
sudo systemctl start mysqld
sudo systemctl status mysqld
### 初期パスワード確認
```
$ sudo grep 'temporary password' /var/log/mysqld.log
# MySQL接続
$ sudo mysql -u root -p
$ Pass123!
$ use appdb;
$ select * from employees;
INSERT INTO employees (id, name, email) VALUES (3, "chao", "chao@example.com");
INSERT INTO employees (id, name, email) SELECT id, name, email FROM employees;
INSERT INTO employees (id, name, email) SELECT id, name, email FROM employees LIMIT 250000;
SELECT COUNT(*) FROM employees;
```

## 中断
1.  実験テンプレートの構築
```
$ aws fis create-experiment-template --region ap-northeast-2 --cli-input-json file://template.json
```
2. 実験の実行
```
$ aws fis start-experiment --experiment-template-id EXT2ZaPZWL8ituj6
$ aws fis start-experiment --region ap-northeast-2 --experiment-template-id EXT2ogaeJwL6dGAC
$ aws fis start-experiment --region us-west-2 --experiment-template-id EXT3BeJR1aDmRfG4
$ aws fis start-experiment --region us-east-1 --experiment-template-id EXT85Gc7qrwuu5MuA
$ aws fis start-experiment --region eu-central-1 --experiment-template-id EXT4DHowXggtzc
$ aws fis start-experiment --region eu-west-1 --experiment-template-id EXTCZaT11H1zHhWqn
$ aws fis start-experiment --region ap-southeast-1 --experiment-template-id EXTRBsFwy2iPsLC
```

3. 実行の確認
```
$ aws fis get-experiment --region ap-northeast-2 --id <experiment-id>
```


sudo cat /var/log/cloud-init-output.log

systemctl status spot-interruption.service

journalctl -t spot-handler --since "5 minutes ago"

{
  "version": "0",
  "id": "abcd1234-5678-90ab-cdef-EXAMPLE11111",
  "detail-type": "EC2 Spot Instance Interruption Warning",
  "source": "aws.ec2",
  "account": "123456789012",
  "time": "2025-12-31T07:15:00Z",
  "region": "us-west-2",
  "resources": [
    "arn:aws:ec2:us-west-2:123456789012:instance/i-0abcd1234efgh5678"
  ],
  "detail": {
    "instance-id": "i-0abcd1234efgh5678",
    "instance-action": "terminate"
  }
}

TZ=Asia/Tokyo date -d @176760699

INSERT INTO employees (id, name, email) VALUES
(1, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(2, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(3, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(4, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(5, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(6, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(7, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(8, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(9, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(30, "chao_abcdef123456", "chao_abcdef123456@example.com");

INSERT INTO employees (id, name, email) VALUES
(1, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(2, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(3, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(4, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(5, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(6, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(7, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(8, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(9, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(10, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(11, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(12, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(13, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(14, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(15, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(16, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(17, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(18, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(19, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(20, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(21, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(22, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(23, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(24, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(25, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(26, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(27, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(28, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(29, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(30, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(31, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(32, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(33, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(34, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(35, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(36, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(37, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(38, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(39, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(40, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(41, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(42, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(43, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(44, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(45, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(46, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(47, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(48, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(49, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(50, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(51, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(52, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(53, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(54, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(55, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(56, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(57, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(58, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(59, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(60, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(61, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(62, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(63, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(64, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(65, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(66, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(67, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(68, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(69, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(70, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(71, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(72, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(73, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(74, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(75, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(76, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(77, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(78, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(79, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(80, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(81, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(82, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(83, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(84, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(85, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(86, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(87, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(88, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(89, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(90, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(91, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(92, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(93, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(94, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(95, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(96, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(97, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(98, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(99, "chao_abcdef123456", "chao_abcdef123456@example.com"),
(100, "chao_abcdef123456", "chao_abcdef123456@example.com");