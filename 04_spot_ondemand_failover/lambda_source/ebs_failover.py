import boto3
import os
import logging
import paramiko
import time
from botocore.exceptions import ClientError

# ロギングの設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client('ssm', region_name='ap-northeast-1')

def get_ssh_key_from_ssm(param_name):
    """SSMパラメータストアからSSH秘密鍵を取得して一時ファイルに保存"""
    try:
        response = ssm.get_parameter(Name=param_name, WithDecryption=True)
        private_key_str = response['Parameter']['Value']

        temp_key_path = "/tmp/ssh_key.pem"
        with open(temp_key_path, 'w') as f:
            f.write(private_key_str)
        
        os.chmod(temp_key_path, 0o600)
        return temp_key_path
    except ClientError as e:
        logger.error(f"Failed to retrieve SSH key from SSM: {str(e)}")
        raise e

def execute_ssh_command(host, username, key_path, command):
    """SSHでコマンドを実行する関数"""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        with open(key_path, 'r') as key_file:
            private_key = paramiko.RSAKey.from_private_key_file(key_path)
        
        ssh.connect(host, username=username, pkey=private_key)
        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode()
        error = stderr.read().decode()
        
        if error:
            logger.error(f"Command error: {error}")
            return False, error
        
        return True, output
    except Exception as e:
        logger.error(f"SSH error: {str(e)}")
        return False, str(e)
    finally:
        ssh.close()

def lambda_handler(event, context):
    try:
        # 環境変数から設定を取得
        source_instance_id = event['detail']['instance-id']
        destination_instance_id = os.environ['ONDEMAND_INSTANCE_ID']
        volume_id = os.environ['VOLUME_ID']
        source_host = os.environ['SOURCE_HOST']
        destination_host = os.environ['DESTINATION_HOST']
        
        # SSMパラメータストアから秘密鍵を取得
        ssm_param_name = "/spot-ondemand-failover/dev/ssh_private_key"
        key_path = get_ssh_key_from_ssm(ssm_param_name)
        
        # EC2クライアントの初期化
        ec2 = boto3.client('ec2', region_name='ap-northeast-1')
        
        # 1. ソースインスタンスでの処理
        logger.info("Starting EBS unmount process on source instance")
        
        # MySQLの停止
        success, output = execute_ssh_command(
            source_host, 'ec2-user', key_path,
            'sudo systemctl stop mysqld'
        )
        if not success:
            raise Exception(f"Failed to stop MySQL: {output}")
        
        # マウント解除
        success, output = execute_ssh_command(
            source_host, 'ec2-user', key_path,
            'sudo umount /data'
        )
        if not success:
            raise Exception(f"Failed to unmount volume: {output}")
        
        # fstabのバックアップと編集
        commands = [
            'sudo cp /etc/fstab /etc/fstab.backup',
            'sudo sed -i \'s|/dev/xvdf /data xfs defaults,nofail 0 2|#/dev/xvdf /data xfs defaults,nofail 0 2|\' /etc/fstab'
        ]
        for cmd in commands:
            success, output = execute_ssh_command(source_host, 'ec2-user', key_path, cmd)
            if not success:
                raise Exception(f"Failed to modify fstab: {output}")
        
        # 2. EBSのデタッチ
        logger.info("Detaching EBS volume")
        ec2.detach_volume(VolumeId=volume_id)
        
        # デタッチの完了を待機
        waiter = ec2.get_waiter('volume_available')
        waiter.wait(VolumeIds=[volume_id])
        
        # 3. EBSのアタッチ
        logger.info("Attaching EBS volume to destination instance")
        ec2.attach_volume(
            VolumeId=volume_id,
            InstanceId=destination_instance_id,
            Device='/dev/xvdf'
        )
        
        # アタッチの完了を待機
        waiter = ec2.get_waiter('volume_in_use')
        waiter.wait(VolumeIds=[volume_id])
        
        # 4. デスティネーションインスタンスでの処理
        logger.info("Starting EBS mount process on destination instance")
        
        mount_commands = [
            'sudo mkdir -p /data',
            'sudo mount /dev/xvdf /data',
            'sudo rm -rf /var/lib/mysql',
            'sudo ln -s /data/mysql /var/lib/mysql',
            'sudo chown -R mysql:mysql /data/mysql',
            'sudo chmod 750 /data/mysql',
            'sudo systemctl start mysqld'
        ]
        
        for cmd in mount_commands:
            success, output = execute_ssh_command(destination_host, 'ec2-user', key_path, cmd)
            if not success:
                raise Exception(f"Failed to execute command: {cmd}, Error: {output}")
        
        logger.info("EBS failover completed successfully")
        return {
            'statusCode': 200,
            'body': 'EBS failover completed successfully'
        }
        
    except Exception as e:
        logger.error(f"Error during EBS failover: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error during EBS failover: {str(e)}'
        }