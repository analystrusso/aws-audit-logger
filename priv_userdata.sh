#!/bin/bash
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
apt update -y
apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
aws ssm get-parameter \
  --region us-east-1 \
  --name "/dev/logger/private-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > /home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
echo "* * * * * ubuntu scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa /var/log/boot.log ubuntu@${pub_private_ip}:~/boot/boot.log" >> /etc/cron.d/push-logs