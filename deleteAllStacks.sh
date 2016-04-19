#!/bin/bash


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

function isNovaOnline {
echo $(nova availability-zone-list |grep ProVM -A1|grep ":-)" -B1|grep -v ":-)"|sed s/\|//g|sed "s/ //g"|grep -v "\-\-"|sed "s/^\-//g")|grep "$1" >/dev/null 2>&1 && colorGreen Online || colorRed "Offline"
}

function isNeutronOnline {
echo $(neutron agent-list|grep ":-)"|grep ProVM|awk {'print $7'}|grep $1 >/dev/null 2>&1 && colorGreen Online || colorRed "Offline")
}


##########
## MAIN ##
##########


stackList="$(heat stack-list|grep -v "\-\-\-"|grep -v creation_time|awk {'print $4'})"
colorBold "\nSelect heat stack to delete:"
colorReset ""
heat stack-list
colorReset
selector "ALL $stackList"

colorReset ""
if [[ "$selectorResult" == "ALL" ]]; then 
	deleteMode=ALL
	deleteList=$(heat stack-list|grep -v "\-\-\-"|grep -v creation_time|awk {'print $2'})
else
	selectedStack=$selectorResult
	deleteList=$(heat stack-list|grep -v "\-\-\-"|grep -v creation_time|awk {'print $2,$4'}|grep -w "$selectorResult"|awk {'print $1'})
fi
for stack in $deleteList;do heat stack-delete $stack;done
counter=1
output="a"
while [[ "$output" != "" ]];do 
	if [[ "$deleteMode" == "ALL" ]]; then 
		output=$(heat stack-list|grep -v stack_status|grep -v "\-\-\-")
	else
		output=$(heat stack-list|grep -v stack_status|grep -v "\-\-\-"|grep -w $selectedStack)
	fi
	
	echo "[$counter/20] $output"
	sleep 2
	((counter++))
	if [[ "$counter" -gt "20" ]];then 
		echo "Failed to delete !"
		exit 1;
	fi 
done
echo "Delete $selectedStack $deleteMode completed"

#while [[ "$deleteStatus" != "" ]]; do
#        deleteStatus=$(heat stack-list|awk -F\| {'print $4'}|sed -r "s/ //g"|grep -v stack_status)
#        sleep 2
#        echo "Current stack status is [${deleteStatus}]. Waiting for stack to be deleted..."
#        if [[ "$creationStatus" == "DELETE_FAILED" ]];then
#                echo "Stack $stackName deletion failed! quitting..."
#                exit 1
#        fi
#done


