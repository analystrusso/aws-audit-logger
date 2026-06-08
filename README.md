The idea for this project came from Day 49 of KodeKloud's 100 Days of Cloud (AWS). What this does is gather boot.log from /var/log/boots.log on a private EC2 instance, uses a cron job to securely copy it to a public instance, which then copies it to an S3 bucket for further study or ingestion by other AWS services. More to come later.

I've started adding the public infrastructure: VPC, subnets, IGW, route table, and EC2 and associated moving parts.

Where I see a potential avenue for improvement: since the log data will eventually end up in an S3 bucket, I could use a VPC endpoint for S3 instead of an internet gateway. That way, no traffic needs to leave AWS. However, I may want a Nat Instance/Gateway to allow outbound traffic for the sake of the EC2 instances, so that may be a wash. I'll consider it further.
