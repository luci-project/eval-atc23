#!/bin/bash

find . -regextype egrep -regex '^./[0-9a-f]{40}$' -type d -exec rm -rf {} \;
