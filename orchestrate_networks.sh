#!/bin/bash
stackName="networkInfra"
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
echo "Using config file $openstackConfigFile"
cat $openstackConfigFile





heat stack-create -f heat_networkInfra.yml -P "$openstackConfig" $stackName
exitStatus=$?
if [[ $exitStatus != "0" ]];then
	echo "Error while executing heat command!"
	exit 1
fi



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
echo "Finished!"
