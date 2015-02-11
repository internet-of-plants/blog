#!/bin/bash

JEKYLL_ENV=production bundle exec jekyll build &&
    rsync -avz _site/* x3ro@enif.uberspace.de:~/html/ --exclude="publish.sh"
