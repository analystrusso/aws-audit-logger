#!/bin/bash
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
cat > /home/ubuntu/.ssh/id_rsa << KEYEOF
${private_key}
KEYEOF
chmod 600 /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
echo "* * * * * ubuntu scp -i /home/ubuntu/.ssh/id_rsa -o StrictHostKeyChecking=no /var/log/auth.log ubuntu@${pub_private_ip}:~/auth/auth.log" >> /etc/cron.d/push-logs