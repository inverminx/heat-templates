#!/bin/bash
stackName="vyatta-2-stack"
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



heat stack-create -f heat_2-vyatta.yml -P "$openstackConfig" $stackName
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
vyatta1FloatingIP=$(heat output-show $stackName vyatta1_floating_IP|sed -r 's/\"//g')
vyatta1AccessIP=$(heat output-show $stackName vyatta1_access_IP|sed -r 's/\"//g')
vyatta1NetworkIP=$(heat output-show $stackName vyatta1_network_IP|sed -r 's/\"//g')
vyatta1InnerIP=$(heat output-show $stackName vyatta1_inner_IP|sed -r 's/\"//g')

vyatta2FloatingIP=$(heat output-show $stackName vyatta2_floating_IP|sed -r 's/\"//g')
vyatta2AccessIP=$(heat output-show $stackName vyatta2_access_IP|sed -r 's/\"//g')
vyatta2NetworkIP=$(heat output-show $stackName vyatta2_network_IP|sed -r 's/\"//g')
vyatta2InnerIP=$(heat output-show $stackName vyatta2_inner_IP|sed -r 's/\"//g')

echo "Waiting for Vyatta 1 [$vyatta1FloatingIP] to be accessible for ssh connection..."
until nc -vzw 2 $vyatta1FloatingIP 22; do sleep 2; done
echo "Waiting for Vyatta 2 [$vyatta2FloatingIP] to be accessible for ssh connection..."
until nc -vzw 2 $vyatta2FloatingIP 22; do sleep 2; done

expect expect_2-vyatta.sh $vyatta1FloatingIP ${vyatta1AccessIP}/24 ${vyatta1NetworkIP}/24 ${vyatta1InnerIP}/24 ${vyatta1InnerIP} $vyatta2FloatingIP ${vyatta2AccessIP}/24 ${vyatta2NetworkIP}/24 ${vyatta2InnerIP}/24 ${vyatta2InnerIP}

echo "Finished!"
