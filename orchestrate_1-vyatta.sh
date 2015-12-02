#!/bin/bash
stackName="vyatta-1-stack"
heat stack-create -f /root/heat/heat_1-vyatta.yml $stackName
while [[ "$creationStatus" != "CREATE_COMPLETE" ]]; do
	creationStatus=$(heat stack-list|grep ${stackName}|awk -F\| {'print $4'}|sed -r "s/ //g")
	sleep 2
	echo "Current stack $stackName creation status is [${creationStatus}]. Waiting for stack creation to be completed..."
	if [[ "$creationStatus" == "CREATE_FAILED" ]];then
		echo "Stack $stackName creation failed! quitting..."
		exit 1
	fi
done


echo Done.
echo Detecting output varaiables:
for key in $(heat output-list $stackName|grep \||grep -v description|awk {'print $2'});do echo "$key = $(heat output-show $stackName $key)";done
echo "Waiting for Vyatta to be accessible for ssh connection..."
vyattaFloatingIP=$(heat output-show $stackName vyatta_floating_IP|sed -r 's/\"//g')
vyattaAccessIP=$(heat output-show $stackName vyatta_access_IP|sed -r 's/\"//g')
vyattaNetworkIP=$(heat output-show $stackName vyatta_network_IP|sed -r 's/\"//g')
until nc -vzw 2 $vyattaFloatingIP 22; do sleep 2; done


expect expect_1-vyatta.sh $vyattaFloatingIP ${vyattaAccessIP}/24 ${vyattaNetworkIP}/24 

