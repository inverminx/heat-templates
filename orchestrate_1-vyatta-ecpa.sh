#!/bin/bash
stackName="vyatta-1-stack-ecpa"
if [[ $1 == "" ]];then
        openstackConfigFile=openstackConfig.ini
else
        openstackConfigFile=$1
fi
if [ ! -f "$openstackConfigFile" ];then
        echo "Configuration file $openstackConfigFile does not exist!"
        exit 1
fi

openstackConfig=$(sed ':a;N;$!ba;s/\n/;/g' $openstackConfigFile)
heat stack-create -f heat_1-vyatta.yml -P "$openstackConfig" $stackName
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
sourceIP=22.22.22.6
destMAC=52:54:12:34:56:78
until nc -vzw 2 $vyattaFloatingIP 22; do sleep 2; done


expect expect_1-vyatta-ecpa.sh $vyattaFloatingIP ${vyattaAccessIP}/24 ${vyattaNetworkIP}/24 $sourceIP $destMAC
echo "Finished!"
