#!/bin/zsh
# request.zsh - Script to gather necessary files for debugging from the ifloat-staging directory

BASEDIR="/Users/tarunpacifica/Documents/freelancer/graeme-pristine/ifloat-staging"

echo "=== _header.html.erb ===" > requested_files.txt
cat "$BASEDIR/app/views/common/_header.html.erb" >> requested_files.txt

echo "\n=== controller_error.rb ===" >> requested_files.txt
cat "$BASEDIR/app/models/controller_error.rb" >> requested_files.txt

echo "\n=== exceptions.rb ===" >> requested_files.txt
cat "$BASEDIR/app/controllers/exceptions.rb" >> requested_files.txt

echo "\n=== categories.rb ===" >> requested_files.txt
cat "$BASEDIR/app/controllers/categories.rb" >> requested_files.txt