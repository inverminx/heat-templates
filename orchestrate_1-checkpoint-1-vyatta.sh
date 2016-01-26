#!/bin/bash

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
stackName="vyatta-checkpoint-1-stack"
keyFileName="/root/heat/checkpoint.pem"
heat stack-create -f heat_1-vyatta-1-checkpoint.yml -P "$openstackConfig" $stackName
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
vyattaInnerIP=$(heat output-show $stackName vyatta_inner_IP|sed -r 's/\"//g')
vyattaNetworkIP=$(heat output-show $stackName vyatta_network_IP|sed -r 's/\"//g')
checkpointFloatingIP=$(heat output-show $stackName checkpoint_floating_IP|sed -r 's/\"//g')
checkpointInnerIP=$(heat output-show $stackName checkpoint_inner_IP|sed -r 's/\"//g')
checkpointAccessIP=$(heat output-show $stackName checkpoint_access_IP|sed -r 's/\"//g')
checkpointPrivateKey=$(heat output-show $stackName checkpoint_Private_Key|sed -r 's/\"//g')
accessPortMacAddress=$(heat output-show $stackName access_Port_Mac_Address|sed -r 's/\"//g')
networkPortMacAddress=$(heat output-show $stackName network_Port_Mac_Address|sed -r 's/\"//g')
#Create a private key file
echo -e $checkpointPrivateKey > $keyFileName
chmod 400 $keyFileName

accessCIDR=$(echo $checkpointAccessIP|awk -F. {'print $1"."$2"."$3".0/24"'})
innerCIDR=$(echo $vyattaInnerIP|awk -F. {'print $1"."$2"."$3".0/24"'})
networkCIDR=$(echo $vyattaNetworkIP|awk -F. {'print $1"."$2"."$3".0/24"'})

until nc -vzw 2 $vyattaFloatingIP 22; do sleep 2; done

echo "Configuring Vyatta interfaces..."
expect expect_configureVyatta.sh $vyattaFloatingIP ${vyattaNetworkIP}/24 ${vyattaInnerIP}/24

echo "Configuring Vyatta static route"
expect expect_configureStaticRoute.sh $vyattaFloatingIP "$accessCIDR" $checkpointInnerIP
echo "Configuring Checkpoint image..."
until nc -vzw 2 $checkpointFloatingIP 22; do sleep 2; done
expect expect_configureCheckPoint.sh $checkpointFloatingIP $keyFileName $checkpointInnerIP $checkpointAccessIP $networkCIDR $vyattaInnerIP


