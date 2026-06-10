# One-time manual step
ssh-keygen -t rsa -b 4096 -f logger-key.pem
aws ssm put-parameter --name "/dev/logger/private-key" --type SecureString --value file://logger-key.pem
aws ec2 import-key-pair --key-name "logger-key" --public-key-material fileb://logger-key.pem.pub