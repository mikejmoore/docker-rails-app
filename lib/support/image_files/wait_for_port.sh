#!/bin/bash

host=$1
port=$2

echo "Waiting for port to respond: $host:$port"
while ! exit | nc -q 1 "$host" "$port"; 
  do echo "Waiting for: $host Port: $port" && sleep 3; 
done
echo ""
echo "Port responding: $host:$port"
