# 実行時に変更が必要な箇所

- 紹介する他にも変更が必要な箇所がある可能性があります。エラーを見て変更いただければ幸いです。

### envs/dev/main.tf

- aws_key_pairの登録

```bash
# ファイル名を生成したkeyの名前に変える必要がある
public_key = file("../../key/spot-db-test.pub")
```

### modules/event_bridge/main.tf

- aws_lambda_functionの定義

```bash
# layersを自分の作ったもののARNに合わせる　作り方はREDME参照
layers = [ "arn:aws:lambda:ap-northeast-1:058898200941:layer:paramiko-layer:5" ]
```

- aws_sns_topic_subscriptionの定義

```bash
# 中断時のメール送信先を自分のものに指定
endpoint  = "cguh1095@mail4.doshisha.ac.jp"
```

### modules/event_bridge_all_region/main.tf

- aws_cloudwatch_event_targetの定義

```bash
# 指定する番号をAWSのアカウントIDに変更してください
arn  = "arn:aws:events:ap-northeast-1:058898200941:event-bus/central-spot-events"
```
