#!/usr/bin/expect
set timeout 120
set host [lindex $argv 0]
set keyName [lindex $argv 1]
set innerIP [lindex $argv 2]
set accessIP [lindex $argv 3]
set networkCIDR [lindex $argv 4]
set nextHop [lindex $argv 5]
set user admin
spawn ssh -i $keyName -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}\@${host}

expect "checkpoint-1>"
sleep 1
send "set user admin password\r"
sleep 1
expect "New password:"
send "check123\r"
sleep 1
expect "Verify new password:"
send "check123\r"
sleep 1
expect "checkpoint-1>"
#send "save config\r"
#expect "checkpoint-1>"
#send "set interface eth1 ipv4-address $innerIP mask-length 24\r"
#expect "checkpoint-1>"
#send "set interface eth2 ipv4-address $accessIP mask-length 24\r"
#expect "checkpoint-1>"
#send "set interface eth1 state on\r"
#expect "checkpoint-1>"
#send "set interface eth2 state on\r"
#expect "checkpoint-1>"
#send "set static-route ${networkCIDR} nexthop gateway address $nextHop on\r"
#expect "checkpoint-1>"
send "save config\r"
expect "checkpoint-1>"
send "exit\r"
sleep 2
