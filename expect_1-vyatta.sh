#!/usr/bin/expect
set timeout 120
set host [lindex $argv 0]
set accessIP [lindex $argv 1]
set networkIP [lindex $argv 2]
set accessPortName dp0s4
set networkPortName dp0s5


set user vyatta
set password vyatta
#spawn $env(SHELL)
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}\@${host}
#spawn ssh "$user\@$host"
expect "password:"
#sleep 1
send "$password\r"
expect "vyatta@vyatta"
sleep 1
send "configure\r"
sleep 1
expect "\[edit\]"
send "set interfaces dataplane ${accessPortName} address ${accessIP}\r"
sleep 1
expect "\[edit\]"
send "set interfaces dataplane ${networkPortName} address ${networkIP}\r"
sleep 1
expect "\[edit\]"
send "commit\r"
sleep 1
expect "\[edit\]"
send "save\r"
sleep 1
expect "\[edit\]"
send "exit\r"
sleep 1
expect "vyatta@vyatta"
send "exit\r"
sleep 1
