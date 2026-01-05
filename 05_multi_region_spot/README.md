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