#!/bin/bash
source /root/openrc
function yesNo {
while true; do
    read -p "Do you wish to install this program?" yn
    case $yn in
        [Yy]* ) make install; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
}

function deployVNF {
colorReset
useCase=$1
az=$2
#rand=$(cat /dev/urandom | tr -dc '0-9' | fold -w 6 | head -n 1)
stackName="$useCase-$az"
configFile=${node}.ini
defaultConfigFile=openstackConfig.ini

if [ ! -f "$defaultConfigFile" ];then
        colorRed "Default Configuration file $defaultConfigFile does not exist!"
		colorReset
        exit 1
fi

if [ ! -f $configFile ]; then
		echo "Config file $configFile not found! Creating new from defaults"
		cp $defaultConfigFile $configFile
fi

openstackConfigFile=$configFile
openstackConfig=$(sed ':a;N;$!ba;s/\n/;/g' $openstackConfigFile)
echo "Using config file $openstackConfigFile"
cat $openstackConfigFile

heat stack-create -f heat_$useCase.yml -P "availability_zone=$az;$openstackConfig" $stackName
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

case "$useCase" in

vyatta)  
	echo "Waiting for Vyatta to be accessible for ssh connection..."
	vyattaFloatingIP=$(heat output-show $stackName vyatta_floating_IP|sed -r 's/\"//g')
	vyattaAccessIP=$(heat output-show $stackName vyatta_access_IP|sed -r 's/\"//g')
	vyattaNetworkIP=$(heat output-show $stackName vyatta_network_IP|sed -r 's/\"//g')
	until nc -vzw 2 $vyattaFloatingIP 22; do sleep 2; done
	expect expect_$useCase.sh $vyattaFloatingIP ${vyattaAccessIP}/24 ${vyattaNetworkIP}/24    
	;;
	
	
vyatta-vyatta)
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
	expect expect_$useCase.sh $vyatta1FloatingIP ${vyatta1AccessIP}/24 ${vyatta1NetworkIP}/24 ${vyatta1InnerIP}/24 ${vyatta1InnerIP} $vyatta2FloatingIP ${vyatta2AccessIP}/24 ${vyatta2NetworkIP}/24 ${vyatta2InnerIP}/24 ${vyatta2InnerIP}

    ;;
vyatta-vyatta-vyatta)
	echo "Waiting for Vyatta to be accessible for ssh connection..."
	vyatta1FloatingIP=$(heat output-show $stackName vyatta3_floating_IP|sed -r 's/\"//g')
	vyatta1AccessIP=$(heat output-show $stackName vyatta3_access_IP|sed -r 's/\"//g')
	vyatta1InnerIP=$(heat output-show $stackName vyatta3_inner_IP|sed -r 's/\"//g')
	vyatta2FloatingIP=$(heat output-show $stackName vyatta2_floating_IP|sed -r 's/\"//g')
	vyatta2Inner1IP=$(heat output-show $stackName vyatta2_inner_IP_2|sed -r 's/\"//g')
	vyatta2Inner2IP=$(heat output-show $stackName vyatta2_inner_IP|sed -r 's/\"//g')
	vyatta3FloatingIP=$(heat output-show $stackName vyatta1_floating_IP|sed -r 's/\"//g')
	vyatta3Inner2IP=$(heat output-show $stackName vyatta1_inner_IP|sed -r 's/\"//g')
	vyatta3NetworkIP=$(heat output-show $stackName vyatta1_network_IP|sed -r 's/\"//g')
	accessCIDR=$(echo $vyatta1AccessIP|awk -F. {'print $1"."$2"."$3".0/24"'})
	innerAccessCIDR=$(echo $vyatta1InnerIP|awk -F. {'print $1"."$2"."$3".0/24"'})
	innerNetworkCIDR=$(echo $vyatta2Inner2IP|awk -F. {'print $1"."$2"."$3".0/24"'})
	networkCIDR=$(echo $vyatta3NetworkIP|awk -F. {'print $1"."$2"."$3".0/24"'})
	echo "accessCIDR $accessCIDR innerAccessCIDR $innerAccessCIDR innerNetworkCIDR $innerNetworkCIDR networkCIDR $networkCIDR"
	until nc -vzw 2 $vyatta1FloatingIP 22; do sleep 2; done
	until nc -vzw 2 $vyatta2FloatingIP 22; do sleep 2; done
	until nc -vzw 2 $vyatta3FloatingIP 22; do sleep 2; done
	echo "Configuring Vyatta1 interfaces..."
	expect expect_configureVyatta.sh $vyatta1FloatingIP ${vyatta1InnerIP}/24 ${vyatta1AccessIP}/24
	echo "Configuring Vyatta2 interfaces..."
	expect expect_configureVyatta.sh $vyatta2FloatingIP ${vyatta2Inner2IP}/24 ${vyatta2Inner1IP}/24
	echo "Configuring Vyatta3 interfaces..."
	expect expect_configureVyatta.sh $vyatta3FloatingIP ${vyatta3NetworkIP}/24 ${vyatta3Inner2IP}/24
	echo "Configuring Vyatta1 static route"
	echo expect expect_configureStaticRoute.sh $vyatta1FloatingIP "$innerAccessCIDR" $vyatta2Inner1IP
	expect expect_configureStaticRoute.sh $vyatta1FloatingIP "$innerNetworkCIDR" $vyatta2Inner1IP
	echo "Configuring Vyatta1 static route"
	expect expect_configureStaticRoute.sh $vyatta1FloatingIP "$networkCIDR" $vyatta2Inner1IP
	echo "Configuring Vyatta2 static route"
	expect expect_configureStaticRoute.sh $vyatta2FloatingIP "$networkCIDR" $vyatta3Inner2IP
	echo "Configuring Vyatta2 static route"
	expect expect_configureStaticRoute.sh $vyatta2FloatingIP "$accessCIDR" $vyatta1InnerIP
	echo "Configuring Vyatta3 static route"
	expect expect_configureStaticRoute.sh $vyatta3FloatingIP "$accessCIDR" $vyatta2Inner2IP
	echo "Configuring Vyatta3 static route"
	expect expect_configureStaticRoute.sh $vyatta3FloatingIP "$innerAccessCIDR" $vyatta2Inner2IP
    ;;
vyatta-checkpoint)
   ;;
ecpa-vyatta)
	echo "Waiting for Vyatta to be accessible for ssh connection..."
	vyattaFloatingIP=$(heat output-show $stackName vyatta_floating_IP|sed -r 's/\"//g')
	vyattaAccessIP=$(heat output-show $stackName vyatta_access_IP|sed -r 's/\"//g')
	vyattaNetworkIP=$(heat output-show $stackName vyatta_network_IP|sed -r 's/\"//g')
	sourceIP=22.22.22.6
	destMAC=52:53:12:34:56:78
	until nc -vzw 2 $vyattaFloatingIP 22; do sleep 2; done
	expect expect_$useCase.sh $vyattaFloatingIP ${vyattaAccessIP}/24 ${vyattaNetworkIP}/24 $sourceIP $destMAC   ;;
*)
   ;;
esac

 
echo "Finished!"

}


function selector {

i=0
list=$1
for line in $1; do
 (( i++ ))

 colorGreen "[$i] $line"
done
colorBold ""
read -p "    Select <1-$i> " selection
if [[ ! $selection =~ ^-?[0-9]+$ ]] || [ "$selection" -gt "$i" ] || [ "$selection" -lt "1" ];then
	colorRed "Invalid Selection"
	colorReset
	selector "$1"
fi
selectorResult=$(echo $list|awk {'print $"'"$selection"'"'})	
echo

}
function colorBold {
echo -e "\e[1m${1}"
}
function colorReset {
echo -e "\e[39m\e[0m${1}"
}
function colorGreen {
echo -e "\e[92m${1}"
}
function colorRed {
echo -e "\e[31m${1}"
}



function trimTable {
echo $1
# grep -v "\-\-\-"|sed 1d|sed -r "s/\|//g"
}
function getComputeNodes {
for line in $(nova hypervisor-list|grep -v "\-\-\-"|sed 1d|sed -r "s/\|//g" |awk {'print $2'});do echo "$line";done
}
function getAvailabilityZones {
for line in $(nova aggregate-list|grep -v "\-\-\-"|sed 1d|sed -r "s/\|//g" |awk {'print $3'});do echo "$line";done
}



function getInstancesPerHypervisor {
hyperVisor=$1
for line in $(nova hypervisor-servers $hyperVisor|grep -v "\-\-\-"|sed 1d|sed -r "s/\|//g" |awk {'print $1'});do echo "$line";done
}


function getNodeStatus {

nodeStatus=$(nova hypervisor-show $1|grep state|awk {'print $4'})
if [[ "$?" != "0" ]];then
	colorRed "Error getting node status!"
	exit 1
fi

}
mode=interactive

if [ "$#" -eq 2 ]; then
    echo "mode=auto"
	mode=auto
	auto_computeNode=$1
	auto_scenario=$2
fi
if [ "$#" -ne 2 ] && [ "$#" -gt 0 ]; then
colorRed "Usage: $0  - Interactive mode"
colorGreen	 " or"
colorRed	"$0 [ProVM number] [scenario]"
colorGreen	"Chose Scenario:"
echo " 1. vyatta"
echo " 2. vyatta-vyatta"
echo " 3. vyatta-vyatta-vyatta"
echo " 4. vyatta-checkpoint"
echo " 5. ecpa-yatta"
echo
colorBold "For example $0 150 2"

colorReset
exit 1
fi

clear
colorBold "Adva Orchestrator\n"
colorReset "Select target node:"
nodes=$(getComputeNodes)
colorGreen

if [[ "$mode" == "auto" ]]; then 
	selectorResult=$auto_computeNode
else
	selector "$nodes"
fi
getNodeStatus $selectorResult
if [[ "$nodeStatus" != "up" ]]; then
	colorRed "Node $selectorResult state is $nodeStatus"
	exit 1
fi
node=$selectorResult
instances=$(getInstancesPerHypervisor $node)
if [[ "$instances" != "" ]]; then
	colorRed "There are currently running instances on node $node"
	colorGreen "$instances"
	colorRed "Please remove them"
	colorReset
	exit 1
fi
colorReset "Select service chain"
colorGreen

if [[ "$mode" == "auto" ]]; then 
	selectorResult=$auto_scenario
else
	selector "vyatta vyatta-vyatta vyatta-vyatta-vyatta vyatta-checkpoint ecpa-vyatta"
fi
useCase=$selectorResult
availabilityZonesList=$(getAvailabilityZones)


if [[ $availabilityZonesList != *"$node"* ]]
then
  colorRed "Did not find availability Zone $node on the controller";
  colorReset
  exit 1
fi

deployVNF $useCase $node

#getNodeStatus ProVM-104



exit 0

#rand=$(cat /dev/urandom | tr -dc '0-9' | fold -w 6 | head -n 1)
stackName="vyatta-1-stack-$az"
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

heat stack-create -f heat_1-vyatta.yml -P "$openstackConfig" $stackName
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


