#!/bin/bash
mkdir -p /home/ubuntu/.ssh
mkdir -p /home/ubuntu/boot
chmod 700 /home/ubuntu/.ssh
echo "${pub_key}" >> /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
apt update -y
apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
echo "* * * * * ubuntu aws s3 cp /home/ubuntu/boot/boots.log s3://logger-bucket-314159/boot/boots.log" >> /etc/cron.d/push-logs