#!/bin/bash

docker run -it -p 4000:4000 -v"$(pwd):/mnt" test -c "bundle exec jekyll serve -w --trace"