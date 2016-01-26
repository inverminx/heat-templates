#!/usr/bin/expect
set timeout 120
set host1 [lindex $argv 0]
set cidr [lindex $argv 1]
set nextHop [lindex $argv 2]

set user vyatta
set password vyatta
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}\@${host1}
expect "password:"
send "$password\r"
expect "vyatta@vyatta"
sleep 1
send "configure\r"
sleep 1
expect "\[edit\]"
send "set protocols static route $cidr next-hop $nextHop\r"
sleep 2
expect "\[edit\]"
send "commit\r"
sleep 2
expect "\[edit\]"
send "save\r"
sleep 2
expect "\[edit\]"
send "exit\r"
sleep 1
expect "vyatta@vyatta"
send "exit\r"
sleep 2
