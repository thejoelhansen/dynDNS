#!/usr/bin/env bash

# Import config
source conf

date=`date`

# !todo Check for missing /log, create if empty
log=$installPath"/log"

ipUrl=https://ifconfig.me

# Get current IP and DNS, log them

currentIp=$(curl $ipUrl -s)
currentDns=$(dig +short $DNS A)

echo $date >> $log
echo "Host =" $currentIp "&" $DNS "=" $currentDns >> $log

# Compare current IP and DNS
if [ $currentIp == $currentDns ] 
then
	exit 0
elif [ $currentIp != $currentDns ] 
then	
	# Update log that the DNS is out of sync
	echo "IP mismatch - updating DNS..." >> $log

	# Update A record	
	gcloud dns --project=$gcProject record-sets update $DNS --type="A" --zone=$gcZone --rrdatas=$currentIp --ttl=60 >> $log

	exit 0
fi
