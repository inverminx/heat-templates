#!/bin/bash
stackName="vyatta-3-stack"
heat stack-create -f /root/heat/heat_3-vyatta.yml $stackName
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
#send "set protocols static route 22.22.22.0/24 next-hop ${inner2IP}\r"
echo "Finished"

