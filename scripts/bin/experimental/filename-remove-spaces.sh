#!/bin/bash
mv -n "${1}" $(echo "${1}" | sed 's/ /_/g')
