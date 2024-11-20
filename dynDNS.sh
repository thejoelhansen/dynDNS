#!/usr/bin/env bash

# Import config
. /home/joel/projects/dynDNS/conf

date=$(date)

# !todo Check for missing /log, create if empty
log=$installPath"/log"

ipUrl=https://ifconfig.me

# Get current IP and DNS, log them

currentIp=$(curl $ipUrl -s)
currentDns=$(dig +short "$DNS" A)

# empty line break to log
echo -en '\n' >> "$log"

#scratch

# while [ -z $dnsLoopIteration ]; do 

#	dnsCount=1
#	dnsLoopIteration=dns"$dnsCount"
#	echo ${!dnsLoopIteration}

# dnsCount=$((dnsCount+1))

#	echo $dnsLoopIteration
#	echo ${!dnsLoopIteration}
#	echo ${dnsLoopIteration:3:1}



# done
# exit 0

# !todo change to pull from last dns# entry in conf
# something like var=(grep dns conf | tail -n 1); maxDnsCount=${var:3:1} 
maxDnsCount=2
maxDnsCount=$((maxDnsCount+1))

# Iterate through each DNS entry from conf, starting with dns1

for (( count=1; count<"$maxDnsCount"; count++ )); do

# Set loop variables	
dnsLoop='dns'"$count"
cloudProviderLoop='cloudProvider'"$count"

echo $date >> "$log"
echo "Host = ${!dnsLoop} @ $currentIp" >> "$log"

# ! I left off here... test loop

echo ${!cloudProviderLoop}
exit 0
done
	
if [ $cloudProviderLoop = gc ]; then

	# Set Google Cloud variables		
	gcProjectLoop='gcProject'"$count"
	gcZoneLoop='gczone'"$count"

	# Compare current IP and DNS
	if [ $currentIp == $currentDns ]; then
		exit 0
	elif [ $currentIp != $currentDns ]; then
	
	# Update log that the DNS is out of sync
		echo "IP mismatch - updating DNS..." >> $log

	# Update A record
		gcloud dns --project=${!gcProjectLoop} record-sets update ${!dnsLoop} --type="A" --zone=${!gcZone} --rrdatas=$currentIp --ttl=60 >> $log

		exit 0
	fi
fi

# !todo 
if [ $cloudProviderLoop = aws ]; then

	echo "Sorry, AWS Route 53 isn't implemented yet"
	echo "Could not update" ${!dnsLoop}
	exit 0 
fi 

done

exit 0
