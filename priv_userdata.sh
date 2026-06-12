#!/bin/bash
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
cat > /home/ubuntu/.ssh/id_rsa << 'KEYEOF'
${private_key}
KEYEOF
chmod 600 /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
touch /var/log/boot.log
printf "* * * * * ubuntu scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa /var/log/boot.log ubuntu@${pub_private_ip}:~/boot/boot.log\n" >> /etc/cron.d/push-logs