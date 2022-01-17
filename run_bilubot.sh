#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# This will cause the script to run in a loop so that the bot auto-restarts
# when you use the shutdown command
LOOP=true

run() {
    ruby ${SCRIPT_DIR}/server.rb
}

while
    run
    $LOOP
do
    continue
done 
