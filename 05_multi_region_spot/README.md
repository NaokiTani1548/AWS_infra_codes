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
