#!/bin/bash

# depends on mozrepl
echo "gBrowser.selectedTab = gBrowser.addTab(\"$*\");"\
    | nc localhost 4242 -q1 > /dev/null 2>&1
