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
# 指定する番号を自分のAWSのアカウントIDに変更してください
arn  = "arn:aws:events:ap-northeast-1:058898200941:event-bus/central-spot-events"
```

# 実行に必要な権限

- 冗長な可能性があります。
- セキュリティに全く配慮していません(Resource \* 指定が多いです)。
- 以下のポリシーを作成し、アタッチしてください。Bachelor グループの権限は与えられている前提です。

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "acm:DeleteCertificate",
                "route53:GetHostedZone",
                "iam:RemoveRoleFromInstanceProfile",
                "sns:Unsubscribe",
                "ssm:GetParameter",
                "fis:*",
                "ssm:DeleteParameter",
                "iam:DetachRolePolicy",
                "acm:RequestCertificate",
                "ssm:DescribeParameters",
                "iam:ListAttachedRolePolicies",
                "route53:ListResourceRecordSets",
                "sns:Subscribe",
                "sns:ListTagsForResource",
                "route53:CreateHostedZone",
                "iam:ListEntitiesForPolicy",
                "sns:CreateTopic",
                "route53:ChangeResourceRecordSets",
                "acm:AddTagsToCertificate",
                "iam:DeleteRole",
                "fis:UntagResource",
                "sns:GetSubscriptionAttributes",
                "ssm:GetParameters",
                "fis:ListTagsForResource",
                "fis:DeleteExperimentTemplate",
                "acm:ListTagsForCertificate",
                "ssm:PutParameter",
                "acm:DescribeCertificate",
                "route53:ChangeTagsForResource",
                "iam:GetRolePolicy",
                "route53:GetChange",
                "sns:DeleteTopic",
                "lambda:GetLayerVersion",
                "fis:ListExperimentTemplates",
                "fis:CreateExperimentTemplate",
                "sns:ListTopics",
                "sns:SetTopicAttributes",
                "fis:GetExperimentTemplate",
                "iam:ListInstanceProfilesForRole",
                "fis:TagResource",
                "iam:DeleteRolePolicy",
                "acm:ListCertificates",
                "route53:DeleteHostedZone",
                "iam:DeleteInstanceProfile",
                "fis:UpdateExperimentTemplate",
                "sns:GetTopicAttributes",
                "ssm:GetParameterHistory",
                "sns:ListSubscriptions",
                "sns:AddPermission",
                "route53:ListTagsForResource",
                "ssm:ListTagsForResource",
                "s3:PutBucketPolicy",
                "sns:ListPlatformApplications"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "ssm:ListTagsForResource",
            "Resource": "arn:aws:ssm:ap-northeast-1:058898200941:parameter/tastylog-dev/app/*"
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": "ssm:GetParameters",
            "Resource": [
                "arn:aws:ssm:ap-northeast-1:058898200941:parameter/tastylog-dev/app/MYSQL_HOST",
                "arn:aws:ssm:ap-northeast-1:058898200941:parameter/tastylog-dev/app/MYSQL_PORT",
                "arn:aws:ssm:ap-northeast-1:058898200941:parameter/tastylog-dev/app/MYSQL_DATABASE",
                "arn:aws:ssm:ap-northeast-1:058898200941:parameter/tastylog-dev/app/MYSQL_USERNAME",
                "arn:aws:ssm:ap-northeast-1:058898200941:parameter/tastylog-dev/app/MYSQL_PASSWORD"
            ]
        }
    ]
}
```
