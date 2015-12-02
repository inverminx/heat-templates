#!/usr/bin/expect
set timeout 120
set host1 [lindex $argv 0]
set access1IP [lindex $argv 1]
set network1IP [lindex $argv 2]
set inner1CIDR [lindex $argv 3]
set inner1IP [lindex $argv 4]
set host2 [lindex $argv 5]
set access2IP [lindex $argv 6]
set network2IP [lindex $argv 7]
set inner2CIDR [lindex $argv 8]
set inner2IP [lindex $argv 9]
set accessPortName dp0s4
set networkPortName dp0s5
#set innerPortName dp0s6

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
send "set interfaces dataplane ${accessPortName} address ${inner1CIDR}\r"
sleep 1
expect "\[edit\]"
send "set interfaces dataplane ${networkPortName} address ${access1IP}\r"
sleep 1
expect "\[edit\]"
send "set protocols static route 22.22.22.0/24 next-hop ${inner2IP}\r"
sleep 1
expect "\[edit\]"
send "commit\r"
sleep 1
expect "\[edit\]"
send "save\r"
sleep 5
expect "\[edit\]"
send "exit\r"
sleep 1
expect "vyatta@vyatta"
send "exit\r"
sleep 5

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}\@${host2}
expect "password:"
send "$password\r"
expect "vyatta@vyatta"
sleep 1
send "configure\r"
sleep 1
expect "\[edit\]"
send "set interfaces dataplane ${accessPortName} address ${inner2CIDR}\r"
sleep 1
expect "\[edit\]"
send "set interfaces dataplane ${networkPortName} address ${network2IP}\r"
sleep 1
expect "\[edit\]"
send "set protocols static route 33.33.33.0/24 next-hop ${inner1IP}\r"
sleep 1
expect "\[edit\]"
send "commit\r"
sleep 1
expect "\[edit\]"
send "save\r"
sleep 5
expect "\[edit\]"
send "exit\r"
sleep 1
expect "vyatta@vyatta"
send "exit\r"
sleep 1


