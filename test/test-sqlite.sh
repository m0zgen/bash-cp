#!/bin/sh
sqlite3 test.db <<EOF
create table users (id INTEGER PRIMARY KEY,u TEXT,s TEXT);
insert into users (u,s) values ('user1','site1.local');
select * from users;
EOF