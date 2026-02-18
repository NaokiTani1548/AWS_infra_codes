import boto3
from botocore.exceptions import ClientError
import os
import time
import random
import logging
import json
from datetime import datetime, timezone

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

INSTANCE_TYPE = "m6i.large"

SOURCE_REGION = "ap-northeast-1"
SOURCE_AMI_ID = "ami-09cd9fdbf26acc6b4"

cloudwatch = boto3.client("cloudwatch")

# 中断率データを手動で設定(変更頻度が遅いため)・使わない場合はすべて1で統一
BASE_SCORE = {
    "ap-northeast-1": 1,
    "ap-southeast-1": 1,
    "us-east-1": 1,
    "us-west-2": 1,
    "eu-central-1": 1,
    "eu-west-1": 1,
}

REGION_AZ_MAP = {
    "ap-northeast-1": "ap-northeast-1c",
    "ap-southeast-1": "ap-southeast-1a",
    "us-east-1": "us-east-1b",
    "us-west-2": "us-west-2a",
    "eu-central-1": "eu-central-1a",
    "eu-west-1": "eu-west-1a",
}
REGIONS = list(REGION_AZ_MAP.keys())


def get_spot_scores():
    ec2 = boto3.client("ec2", region_name=SOURCE_REGION)
    resp = ec2.get_spot_placement_scores(
        InstanceTypes=[INSTANCE_TYPE],
        TargetCapacity=1,
        SingleAvailabilityZone=False,
        RegionNames=REGIONS,
        MaxResults=100,
    )

    results = []
    for s in resp.get("SpotPlacementScores", []):
        region = s.get("Region")
        score = s.get("Score", 0)
        base = BASE_SCORE.get(region, 0)
        availability = score + base
        results.append({
            "region": region,
            "score": availability,
            "raw_score": score,
            "base_score": base,
            "availability_zone": None
        })

    # --- スコア順にソート (availability first, then base_score) ---
    results.sort(key=lambda x: (x["score"], x.get("base_score", 0)), reverse=True)

    for r in results:
        logger.info("region=%s score=%s az=%s",
                    r["region"], r["score"], r["availability_zone"])

    return results


def choose_best_region(scores):
    """
    最高スコア順に並べ、トップが複数ある場合は
    BASE_SCORE（base_scoreフィールド）が高いものを優先する。
    それでも複数ある場合のみランダム選択する。
    """
    top_score = scores[0]["score"]

    # availability が同じリージョンを抽出
    top_regions = [s for s in scores if s["score"] == top_score]

    if len(top_regions) == 1:
        return top_regions[0]

    # base_score の高い順でソート
    top_regions.sort(key=lambda x: x.get("base_score", 0), reverse=True)
    best_base = top_regions[0].get("base_score", 0)
    candidates = [s for s in top_regions if s.get("base_score", 0) == best_base]

    if len(candidates) == 1:
        return candidates[0]

    # まだ複数 → ランダム選択
    return random.choice(candidates)

def get_latest_al2023_ami(region):
    ssm = boto3.client("ssm", region_name=region)

    param_name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

    resp = ssm.get_parameter(Name=param_name)
    return resp["Parameter"]["Value"]


def launch_spot_instance():
    """
    SPS が最も高いリージョンにスポットインスタンスを起動
    """
    logger.info("Start: launching spot instance based on SPS ranking...")

    # SPSを取得
    scores = get_spot_scores()
    best_region = choose_best_region(scores)
    logger.info(f"Top SPS region = {best_region}")

    ami_id = get_latest_al2023_ami(region=best_region["region"])

    # Lambda 環境変数から設定取得
    network_map = json.loads(os.environ["NETWORK_MAP"])
    keypair_map = json.loads(os.environ["KEYNAME_MAP"])
    sg_map = json.loads(os.environ["SECURITY_GROUP_MAP"])

    selected = network_map[best_region["region"]]
    vpc_id = selected["vpc_id"]
    subnet_id = selected["subnet_id"]
    keypair_name = keypair_map[best_region["region"]]
    sg_id = sg_map[best_region["region"]].split(",")
    seed_s3_path = os.environ["S3_DATA_PATH"]

    ec2 = boto3.client("ec2", region_name=best_region["region"])

    # スポットインスタンス実行
    try:
        response = ec2.run_instances(
            ImageId=ami_id,
            InstanceType=INSTANCE_TYPE,
            MinCount=1,
            MaxCount=1,
            InstanceMarketOptions={
                "MarketType": "spot",
                "SpotOptions": {
                    "SpotInstanceType": "one-time",
                    "InstanceInterruptionBehavior": "terminate"
                }
            },
            KeyName=keypair_name,
            SubnetId=subnet_id,
            SecurityGroupIds=sg_id,
            IamInstanceProfile={
                "Name": "ec2-s3-full-role"
            },
            UserData="""#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data-debug.log) 2>&1
START_A=$(date -Is)

sudo dnf update -y
sudo dnf install -y awscli gzip
sudo dnf remove -y mariadb-*

sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
wget https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
sudo rpm --import RPM-GPG-KEY-mysql-2023

sudo dnf --enablerepo=mysql80-community install -y mysql-community-server mysql-community-devel

sudo systemctl stop mysqld

########################################
# データディレクトリ確認（触らない）
########################################
ls -ld /var/lib/mysql || true

########################################
# SELinux（AL2023 は基本 permissive だが安全側）
########################################
if command -v getenforce >/dev/null && [ "$(getenforce)" != "Disabled" ]; then
dnf install -y policycoreutils-python-utils
fi

INSTALL_DONE_B=$(date -Is)
########################################
# MySQL 初期化（初回のみ）
########################################
if [ ! -d /var/lib/mysql/mysql ]; then
echo "Initializing MySQL data directory"
mysqld --initialize --user=mysql
fi

########################################
# local_infile 有効化
########################################
cat >/etc/my.cnf <<'EOF'
[mysqld]
local_infile=1
secure_file_priv=""

[mysql]
local_infile=1
EOF

########################################
# systemd に完全に任せて起動
########################################
systemctl enable mysqld
systemctl restart mysqld

########################################
# 起動待ち
########################################
for i in {1..30}; do
if systemctl is-active --quiet mysqld; then
    echo "MySQL started successfully"
    break
fi
sleep 1
done

########################################
# 起動確認
########################################
if ! systemctl is-active --quiet mysqld; then
echo "MySQL failed to start"
journalctl -u mysqld --no-pager -n 100
exit 1
fi

########################################
# 完了ログ
########################################
echo "===== MySQL is running ====="
systemctl status mysqld --no-pager

########################################
# root パスワード固定（初回 or 未設定時）
########################################
MYSQL_ROOT_PASSWORD="Pass123!"
DB_NAME="appdb"
TABLE_NAME="employees"

if ! mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
  echo "===== Setting MySQL root password ====="

  systemctl stop mysqld

  mysqld --skip-grant-tables --skip-networking --user=mysql &
  sleep 10

  mysql <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost'
IDENTIFIED WITH mysql_native_password
BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

  pkill mysqld
  sleep 3

  systemctl start mysqld
fi
MYSQL_RUN_DONE_C=$(date -Is)

########################################
# S3 から CSV 取得
########################################
S3_CSV_PATH="s3://dev-multi-region-spot-data-source/data_source/employee_data.csv"
CSV_LOCAL_PATH="/var/tmp/seed.csv"
echo "===== Fetch CSV from S3 ====="
CSV_FETCH_START_TS=$(date +%s%3N)
aws s3 cp "${S3_CSV_PATH}" "${CSV_LOCAL_PATH}"
CSV_CP_DONE_D=$(date -Is)

########################################
# DB / Table 作成 & 再ロード（S3が正）
########################################
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
USE ${DB_NAME};

CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
  id INT,
  name VARCHAR(100),
  email VARCHAR(255)
);

TRUNCATE TABLE ${TABLE_NAME};
EOF

mysql --local-infile=1 -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
USE ${DB_NAME};
LOAD DATA LOCAL INFILE '${CSV_LOCAL_PATH}'
INTO TABLE ${TABLE_NAME}
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
EOF

CSV_LOAD_DONE_E=$(date -Is)

BUCKET="dev-multi-region-spot-data-source"
PREFIX="mysql/"
MYSQL_ROOT_PASSWORD="Pass123!"
DB_NAME="appdb"

KEY=$(aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "$PREFIX" \
  --query 'Contents[?Size>`0`]|sort_by(@,&LastModified)[-1].Key' \
  --output text || echo "")

if [ -n "$KEY" ]; then
  echo "Found S3 object: $KEY. Proceeding with data import."
  aws s3 cp "s3://${BUCKET}/${KEY}" - | gunzip -c | tee >(wc -c >&2) | mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB_NAME}"
else
  echo "No valid S3 object found. Skipping data import."
fi

DATA_CP_DONE_F=$(date -Is)

########################################
# 完了
########################################
echo "===== MySQL is ready ====="
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e \
  "SELECT COUNT(*) AS rows_loaded FROM ${DB_NAME}.${TABLE_NAME};"
MYSQL_READY_TS=$(date +%s%3N)
DATA_LOAD_DONE_G=$(date -Is)
DURATION_MS=$((MYSQL_READY_TS - CSV_FETCH_START_TS))

LOG_GROUP_NAME="/aws/lambda/multi-region-spot-dev-boot-spot"
LOG_STREAM_NAME="spot-instance-log-stream"
REGION="ap-northeast-1"

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%s%3N)
MESSAGE="userdata_completed start=${START_A} install_done=${INSTALL_DONE_B} MySQL_run_done=${MYSQL_RUN_DONE_C} csv_cp_done=${CSV_CP_DONE_D} csv_load_done=${CSV_LOAD_DONE_E} data_cp_done=${DATA_CP_DONE_F} data_load_done=${DATA_LOAD_DONE_G} data_load_duration_ms=${DURATION_MS}"

# Log stream 作成（存在してもOK）
aws logs create-log-stream \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name "$LOG_STREAM_NAME" \
  --region "$REGION" 2>/dev/null || true

# SequenceToken 取得
SEQUENCE_TOKEN=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name-prefix "$LOG_STREAM_NAME" \
  --region "$REGION" \
  --query "logStreams[0].uploadSequenceToken" \
  --output text)

# JSON を安全に生成
LOG_EVENT=$(printf '[{"timestamp":%s,"message":"%s"}]' "$TIMESTAMP" "$MESSAGE")

if [ "$SEQUENCE_TOKEN" = "None" ] || [ -z "$SEQUENCE_TOKEN" ]; then
  aws logs put-log-events \
    --log-group-name "$LOG_GROUP_NAME" \
    --log-stream-name "$LOG_STREAM_NAME" \
    --region "$REGION" \
    --log-events "$LOG_EVENT"
else
  aws logs put-log-events \
    --log-group-name "$LOG_GROUP_NAME" \
    --log-stream-name "$LOG_STREAM_NAME" \
    --region "$REGION" \
    --sequence-token "$SEQUENCE_TOKEN" \
    --log-events "$LOG_EVENT"
fi

########################################
# EBS snapshot 共通スクリプト
########################################

cat <<'EOF' > /usr/local/bin/create-ebs-snapshot.sh
#!/bin/bash
set -euo pipefail

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
  | grep region | awk -F\" '{print $4}')

VOLUME_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='/dev/xvda'].Ebs.VolumeId" \
  --output text)

TS=$(date -Is)

logger -t ebs-snapshot "Creating snapshot volume=${VOLUME_ID}"

aws ec2 create-snapshot \
  --region "$REGION" \
  --volume-id "$VOLUME_ID" \
  --description "spot-db-snapshot ${TS}" \
  --tag-specifications "ResourceType=snapshot,Tags=[
    {Key=InstanceId,Value=${INSTANCE_ID}},
    {Key=Type,Value=periodic},
    {Key=CreatedAt,Value=${TS}}
  ]"

logger -t ebs-snapshot "Snapshot request submitted"
EOF

chmod +x /usr/local/bin/create-ebs-snapshot.sh

########################################
# Spot 中断検知セットアップ
########################################

cat <<'EOF' > /usr/local/bin/spot-interruption-handler.sh
#!/bin/bash
set -euo pipefail

IMDS_URL="http://169.254.169.254/latest/meta-data/spot/instance-action"
MYSQL_ROOT_PASSWORD="Pass123!"
DB_NAME="appdb"
S3_BUCKET="dev-multi-region-spot-data-source"

while true; do
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds:15")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-aws-ec2-metadata-token: $TOKEN" --connect-timeout 1 --max-time 2 http://169.254.169.254/latest/meta-data/spot/instance-action)
  if [[ "$HTTP_CODE" == "200" ]]; then
    DETECT=$(date -Is) 
    logger -t spot-handler "Spot interruption detected"

    TS=$(date +%Y%m%d-%H%M%S)
    DUMP="/var/tmp/${DB_NAME}-${TS}.sql.gz"

    logger -t spot-handler "MySQL dump started"
    mysqldump -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB_NAME}" | gzip > "${DUMP}"
    logger -t spot-handler "MySQL dump finished"
    logger -t spot-handler "Uploading to S3"
    START_TS=$(date +%s)
    logger -t spot-handler "Uploading to S3 start=${START_TS}"
    if aws s3 cp "${DUMP}" "s3://${S3_BUCKET}/mysql/"; then
      END_TS=$(date +%s)
      END_IS=$(date -Is)
      DURATION=$((END_TS - START_TS))
      logger -t spot-handler "Uploading to S3 finished success end=${END_TS} duration_sec=${DURATION}"
      logger -t spot-handler "TIME... start=${DETECT} end=${END_IS}"
    else
      END_TS=$(date +%s)
      DURATION=$((END_TS - START_TS))
      logger -t spot-handler "Uploading to S3 failed end=${END_TS} duration_sec=${DURATION}"
    fi
    logger -t spot-handler "Upload finished"

    # 最終 EBS snapshot
    logger -t spot-handler "Final EBS snapshot start"
    /usr/local/bin/create-ebs-snapshot.sh || true
    logger -t spot-handler "Final EBS snapshot requested"

    sleep 120
    exit 0
  fi
  sleep 5
done
EOF

chmod +x /usr/local/bin/spot-interruption-handler.sh

echo "===== systemd ====="

cat <<'EOF' > /etc/systemd/system/spot-interruption.service
[Unit]
Description=Spot Interruption Handler
After=network-online.target mysqld.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/spot-interruption-handler.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable spot-interruption.service
systemctl start spot-interruption.service

cat <<'EOF' > /etc/systemd/system/ebs-snapshot.service
[Unit]
Description=Hourly EBS Snapshot

[Service]
Type=oneshot
ExecStart=/usr/local/bin/create-ebs-snapshot.sh
EOF

cat <<'EOF' > /etc/systemd/system/ebs-snapshot.timer
[Unit]
Description=Run EBS snapshot every hour

[Timer]
OnBootSec=15min
OnUnitActiveSec=1h
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ebs-snapshot.timer
            """,
            TagSpecifications=[
                {
                    'ResourceType': 'instance',
                    'Tags': [{'Key': 'Name', 'Value': 'auto-boot-spot'}]
                }
            ]
        )

    except Exception as e:
        logger.error(f"Failed to request spot instance: {e}", exc_info=True)
        raise

    instance_id = response["Instances"][0]["InstanceId"]
    logger.info(f"Spot instance launched: {instance_id}")

    return {
        "status": "success",
        "region": best_region,
        "instance_id": instance_id,
        "score": scores[0]["score"],
    }

def launch_spot_instance_with_retry():
    """
    起動が成功するまで30秒刻みでリクエストを繰り返す
    """
    max_retries = 30  # 最大リトライ回数（例: 30回）
    retry_delay = 30  # リトライ間隔（秒）
    logger.info(f"Current time: {datetime.now(timezone.utc).isoformat()}")

    for attempt in range(max_retries):
        try:
            logger.info(f"Attempt {attempt + 1}/{max_retries}: Launching spot instance...")
            return launch_spot_instance()
        except ClientError as e:
            if "InsufficientInstanceCapacity" in str(e) or "InvalidParameter" in str(e):
                logger.warning(f"Retrying in {retry_delay} seconds due to error: {e}")
                time.sleep(retry_delay)
            else:
                logger.error("Unexpected error occurred. Aborting retries.")
                raise
    raise Exception("Failed to launch spot instance after maximum retries")

def lambda_handler(event, context):
    interruption_time = event["time"]

    interruption_unix = int(
        datetime.fromisoformat(
            interruption_time.replace("Z", "+00:00")
        ).timestamp()
    )


    logger.info(json.dumps({
        "event": "spot_interruption_detected",
        "interruption_time": interruption_time,
        "interruption_unix": interruption_unix
    }))
    return launch_spot_instance_with_retry()
