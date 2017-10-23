#!/usr/bin/expect
spawn localshop init
expect "Username (leave blank to use 'puppet’):"
send "admin\r"
expect "Email address:"
send "admin@example.com\r"
expect "Password:"
send "pass\r"
expect "Password (again):"
send "pass\r"
expect eof
