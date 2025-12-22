import boto3
from botocore.exceptions import ClientError, BotoCoreError
import os
import time
import random
import logging
import json

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

SOURCE_REGION = "ap-northeast-1"
SOURCE_AMI_ID = "ami-09cd9fdbf26acc6b4"

def get_spot_scores():
    """
    SPS（Spot Placement Score）を取得し、score の高い順に並べた結果を返す
    """
    instance_types = ["t3.micro"]
    target_capacity = 1
    regions = ["ap-northeast-1","ap-northeast-2","us-west-2","us-east-1","eu-central-1"]
    region_for_call = "ap-northeast-1"

    ec2 = boto3.client("ec2", region_name=region_for_call)
    results = []

    params = {
        "InstanceTypes": instance_types,
        "TargetCapacity": target_capacity,
        "SingleAvailabilityZone": False,
        "RegionNames": regions,
        "MaxResults": 100
    }

    next_token = None
    while True:
        try:
            if next_token:
                params["NextToken"] = next_token
            resp = ec2.get_spot_placement_scores(**params)

        except (ClientError, BotoCoreError) as e:
            logger.error("get_spot_placement_scores failed: %s", e, exc_info=True)
            raise

        for s in resp.get("SpotPlacementScores", []):
            results.append({
                "region": s.get("Region"),
                "score": s.get("Score"),
                **({"availability_zone_id": s.get("AvailabilityZoneId")} if s.get("AvailabilityZoneId") else {})
            })

        next_token = resp.get("NextToken")
        if not next_token:
            break

    results.sort(key=lambda x: x["score"], reverse=True)
    return results

def choose_best_region(scores):
    """
    最高スコアのリージョンが複数ある場合のみランダム選択
    """
    top_score = scores[0]["score"]

    # 同率1位を抽出
    top_regions = [s for s in scores if s["score"] == top_score]

    if len(top_regions) == 1:
        return top_regions[0]  # １つだけ → そのまま採用

    # 複数 → ランダム選択
    return random.choice(top_regions)

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
    instance_type = "t3.micro"
    network_map = json.loads(os.environ["NETWORK_MAP"])
    selected = network_map[best_region["region"]]
    vpc_id = selected["vpc_id"]
    subnet_id = selected["subnet_id"]
    keypair_map = json.loads(os.environ["KEYNAME_MAP"])
    keypair_name = keypair_map[best_region["region"]]
    sg_map = json.loads(os.environ["SECURITY_GROUP_MAP"])
    sg_id = sg_map[best_region["region"]].split(",")

    ec2 = boto3.client("ec2", region_name=best_region["region"])

    # スポットインスタンス実行
    try:
        response = ec2.run_instances(
            ImageId=ami_id,
            InstanceType=instance_type,
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
            UserData="""#!/bin/bash
                sudo yum update -y
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


def lambda_handler(event, context):
    return launch_spot_instance()
