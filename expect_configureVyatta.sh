#!/usr/bin/expect
set timeout 120
set host [lindex $argv 0]
set leftIP [lindex $argv 1]
set rightIP [lindex $argv 2]
set leftPortName dp0s4
set rightPortName dp0s5


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
send "set interfaces dataplane ${leftPortName} address ${leftIP}\r"
sleep 1
expect "\[edit\]"
send "set interfaces dataplane ${rightPortName} address ${rightIP}\r"
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
