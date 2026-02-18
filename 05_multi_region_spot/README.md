# 起動前準備

### 利用ツール等

- Terraform: バージョン1.4以上を推奨
- AWS CLI : 実験においては2.26.5を利用
- Docker: Lambdaレイヤー作成や依存関係のビルドに使用するケースがある
- Python: Lambda関数でも同じバージョンを使用
- AWSアカウント: 様々な権限が必要なので自分でポリシーを作れる権限があると好ましい(利用アカウントのリージョンはap-northeast-1を想定)

### その他実行に必要なもの

- ssh接続用のkey　(key以下にssh接続を行う用の鍵を生成してください )

```bash
cd key
ssh-keygen -t rsa -b 2048 -f <key_name>
# 暗号鍵は~/.ssh/以下にも設置
# たしか権限云々で必要だったはず（理由忘れた）
```

- lambdaファイルのzip化
- もし外部ライブラリを用いる場合はページ下部参照

```bash
cd lambda_source
zip boot_spot.zip boot_spot.py
```

- MEMO.mdを参照し、コードを変更

# 起動について

### 起動方法

```bash
cd envs/dev
# 最初のみ terraform init が必要
terraform apply -auto-approve
```

### 起動したスポットインスタンスの確認・接続

```bash
# ssh接続
ssh -i ~/.ssh/spot-db-test.pem ec2-user@<public-IP>

# 接続後、MySQLが正常に自動で起動しているか確認
sudo systemctl status mysqld

# MySQLへの接続 (appdbのemployeeテーブルが自動生成される)
sudo mysql -u root -p
Pass> Pass123!
use appdb;
```

# 中断実験

- スポットインスタンスの中断通知を意図的に発生させるためには、AWS FISを利用する必要がある
- envs/dev　配下のtemplete.jsonを利用する（中断させたいリージョンに合わせて書き換える必要あり）

### 手順

- 実験テンプレートの構築

```bash
aws fis create-experiment-template --region ap-northeast-1 --cli-input-json file://template.json
```

- 中断の実行

```bash
aws fis start-experiment --region ap-northeast-1　--experiment-template-id <experimentTemplate-id>
```

- 実行結果の確認

```bash
aws fis get-experiment --region ap-northeast-1 --id <experiment-id>
```

# その他

### terraformコマンド関連

- 変更箇所の確認

```bash
$ terraform plan (-var <KEY>=<VALUE>)(-var-file <VAR_FILE>)
```

- 起動したサービスの削除

```bash
terraform destroy (-auto-approve)
```

### ssh接続後

```bash
# スポットインスタンス立ち上げ時のログ
sudo cat /var/log/cloud-init-output.log
# 中断時動作が動作しているかの確認
systemctl status spot-interruption.service
# 中断時のログ（中断完了までの間のみ確認可能）
journalctl -t spot-handler --since "5 minutes ago"
```

### MySQL接続後

```bash
sudo mysql -u root -p
Pass123!　# パスワード
use appdb;
# データの表示
select * from employees;
# データ数の確認
SELECT COUNT(*) FROM employees;

# 単体データ挿入
INSERT INTO employees (id, name, email) VALUES (3, "chao", "chao@example.com");
# 全データをコピーして挿入（既存データが倍になる。データ数を増やしたいときに）
INSERT INTO employees (id, name, email) SELECT id, name, email FROM employees;
# 全データをコピーして挿入 -250000が上限
INSERT INTO employees (id, name, email) SELECT id, name, email FROM employees LIMIT 250000;
```

### lambda zip 作り方（外部ライブラリを用いる場合）

```bash
$ zip boot_spot.zip boot_spot.py

# 外部ライブラリを使う場合
docker run -it --rm amazonlinux:2023 bash
dnf update -y
dnf install -y python3 python3-pip gcc libffi-devel openssl-devel make zip
python3 --version  # 3.9.x のはず
mkdir /layer
cd /layer

# 入れるものは用途に合わせて
python3 -m pip install --user --upgrade pip setuptools wheel
pip3 install paramiko==3.2.0 pycrypto==2.6.1 cryptography==3.4.8 bcrypt==3.2.2 -t python/
zip -r9 paramiko-layer.zip python/
exit

# 別のターミナルで実行
docker ps
docker cp <container_id>:/layer/paramiko-layer.zip .
aws lambda publish-layer-version \
  --layer-name paramiko-layer \
  --description "paramiko layer" \
  --zip-file fileb://paramiko-layer.zip \
  --compatible-runtimes python3.9 python3.10 python3.11 \
  --region ap-northeast-1
```

### Lambdaから直接関数を実行する際のテストイベント

```bash
{
"version": "0",
"id": "abcd1234-5678-90ab-cdef-EXAMPLE11111",
"detail-type": "EC2 Spot Instance Interruption Warning",
"source": "aws.ec2",
"account": "XX",  # example value; replace with your AWS account ID
"time": "2025-12-31T07:15:00Z",
"region": "us-west-2",
"resources": [
"arn:aws:ec2:us-west-2:XX:instance/i-0abcd1234efgh5678"  # example ARN
],
"detail":
{
"instance-id": "i-0abcd1234efgh5678",
"instance-action": "terminate"
}
}
```

# 注意点

### リファクタ

- 実験後にハードコーディングを解消するために、一部コードを変更しています。差分はとても多いわけではないですが、正常に動かない箇所がある可能性があります。
- 大きな修正が必要になることはないと思いますが十分に気をつけてください

### ハードコーディング

- 自分の実験のために作ったので、ハードコーディングがひどいです。(少し手直しはしました)
- README.md、MEMO.md、ARD.mdを残していますが、他の環境で再構築できるかわかりません。抜けているところがある可能性があります。
- 参考程度の位置づけで見ていただけたらと思います。

### 自動化の失敗箇所1

- 12時間に1度、意図的にスポットインスタンスの再配置(lambdaの再実行)を行う構成になっています。（意図はARD.mdに残しています）
- この時、古いスポットインスタンスはデータを退避させ、中断すべきですが、この部分の自動化実装が間に合っていません。
- 中断時のデータ退避は「スポットインスタンスの中断イベント」でのみ発火します。一方で、lambda関数内でAWS FISで中断イベントを使うと、EventBridgeがこれを検知し、lambda関数を再実行してしまいます。
- 12時間に一度の再配置を自動化するためには、データ退避のトリガーをいじったり、中断方法を考え直す必要があります。

### 自動化の失敗箇所2

- lambda関数内でSPSと中断率データを取得します。
- 中断率データ取得の自動化実装が間に合っていないため、日次で手動設定する必要があります。SPSと比べて更新頻度は低いので、今回の実験では問題ないと判断しています。
