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

echo "📦 Building Lambda package using Lambda base image..."

docker run --rm \
  -v "$LAMBDA_SRC_DIR":/lambda_source \
  -v "$BUILD_DIR":/build \
  public.ecr.aws/lambda/python:3.12 \
  /bin/sh -c "
    cd /build && \
    python3 -m pip install --upgrade pip && \
    pip install boto3 paramiko --target . && \
    cp /lambda_source/ebs_failover.py . && \
    zip -r9 /lambda_source/$ZIP_NAME .
  "

echo "✅ Lambda ZIP created at: $OUTPUT_ZIP"




# WSLから実行