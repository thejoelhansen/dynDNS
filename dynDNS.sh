#!/usr/bin/env bash

# Import config
source dynDNS.conf

date=`date`

# echo $DNS; exit

# Fix - TODO broken log path?
#log="$installPath/dynDNS.log"
log=/app/dynDNS/dynDNS.log

ipUrl=https://ifconfig.me

# Get current IP and DNS, log them

currentIp=$(curl $ipUrl -s)
currentDns=$(dig $DNS +short)

echo $date "Host has IP of" $currentIp "and" $DNS "resolves to" $currentDns >> $log

# Compare current IP and DNS
if [ $currentIp == $currentDns ] 
then
	echo $date "IPs =" $currentIp " - no need to update" >> $log
	exit 0
elif [ $currentIp != $currentDns ] 
then	
	# Update log that the DNS is out of sync
	echo $date "IPs don't match - updating DNS..." >> $log

	# remove old A record	
	gcloud beta dns --project=$gcProject record-sets transaction start --zone=$gcZone >> $log
	gcloud beta dns --project=$gcProject record-sets transaction remove $currentDns --name=$DNS. --ttl=60 --type=A --zone=$gcZone >> $log 
	gcloud beta dns --project=$gcProject record-sets transaction execute --zone=$gcZone >> $log 

	# create new A record
	gcloud beta dns --project=$gcProject record-sets transaction start --zone=$gcZone >> $log 
	gcloud beta dns --project=$gcProject record-sets transaction add $currentIp --name=$DNS. --ttl=60 --type=A --zone=$gcZone >> $log 
	gcloud beta dns --project=$gcProject record-sets transaction execute --zone=$gcZone >> $log 

	# Update log that DNS was updated and they are now in sync
	echo $date $DNS "succesfully updated to" $currentIp >> $log
	exit 0
fi
