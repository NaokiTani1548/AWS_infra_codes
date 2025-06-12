# #!/bin/bash
# set -e

# cd "$(dirname "$0")/../lambda_source"
# zip -r ebs_failover.zip ebs_failover.py > /dev/null
# echo "✅ lambda_source/ebs_failover.zip created"

#!/bin/bash
set -e

# ディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAMBDA_SRC_DIR="$SCRIPT_DIR/../lambda_source"
BUILD_DIR="$SCRIPT_DIR/../build"
ZIP_NAME="ebs_failover.zip"
OUTPUT_ZIP="$LAMBDA_SRC_DIR/$ZIP_NAME"

# 一時ビルド用フォルダ作成（古いものは削除）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "📦 Building Lambda package using amazonlinux:2023..."

# Docker を使って Amazon Linux 2023 環境で依存関係をインストール＆zip化
docker run --rm \
  -v "$LAMBDA_SRC_DIR":/lambda \
  -v "$BUILD_DIR":/out \
  amazonlinux:2023 \
  /bin/bash -c "
    dnf install -y python3 python3-pip gcc git zip libffi-devel openssl-devel make > /dev/null && \
    pip3 install boto3 paramiko --target /out > /dev/null && \
    cp /lambda/ebs_failover.py /out/ && \
    cd /out && zip -r $ZIP_NAME . > /dev/null
  "

# zip を lambda_source に移動
mv "$BUILD_DIR/$ZIP_NAME" "$OUTPUT_ZIP"

echo "✅ Lambda ZIP created at: $OUTPUT_ZIP"





# WSLから実行