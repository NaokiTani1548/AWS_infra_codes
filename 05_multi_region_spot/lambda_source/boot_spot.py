import os
import boto3

def lambda_handler(event, context):
    ami_id = "ami-090a79e3d754223dd"
    region = "ap-northeast-1"
    instance_type = "t3.micro"
    keypair_name = os.environ['KYENAME']
    subnet_id = os.environ['SUBNETID']
    security_groupe_id = os.environ['SECURITYGROUPEIDS']
    ec2 = boto3.client("ec2", region_name=region)

    # Spotインスタンスリクエスト
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
        TagSpecifications=[
            {
                'ResourceType': 'instance',
                'Tags': [
                    {'Key': 'Name', 'Value': 'auto-boot-spot'},
                ]
            }
        ],
        KeyName=keypair_name,
        SecurityGroupIds=[security_groupe_id],
        SubnetId=subnet_id,
        UserData="""#!/bin/bash
        sudo yum update -y
        """
    )

    instance_id = response["Instances"][0]["InstanceId"]
    return {
        "status": "success",
        "instance_id": instance_id
    }
