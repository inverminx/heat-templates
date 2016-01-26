for stack in $(heat stack-list|grep -v "\-\-\-"|grep -v creation_time|awk {'print $2'});do heat stack-delete $stack;done
counter=1
output="a"
while [[ "$output" != "" ]];do 
	output=$(heat stack-list|grep -v stack_status|grep -v "\-\-\-")
	echo "[$counter/20] $output"
	sleep 2
	((counter++))
	if [[ "$counter" -gt "20" ]];then 
		echo "Failed to delete stacks!"
		exit 1;
	fi 
done
echo "All stacks were successfully deleted"

#while [[ "$deleteStatus" != "" ]]; do
#        deleteStatus=$(heat stack-list|awk -F\| {'print $4'}|sed -r "s/ //g"|grep -v stack_status)
#        sleep 2
#        echo "Current stack status is [${deleteStatus}]. Waiting for stack to be deleted..."
#        if [[ "$creationStatus" == "DELETE_FAILED" ]];then
#                echo "Stack $stackName deletion failed! quitting..."
#                exit 1
#        fi
#done


