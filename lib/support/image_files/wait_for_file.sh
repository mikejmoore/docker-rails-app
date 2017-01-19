#!/bin/bash

file=$1

while ! exit | [ -e "$file" ]; 
  do echo "Waiting for file: $file" && sleep 3; 
done
echo ""
echo "File found: $file"
