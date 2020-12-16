#!/bin/bash

/tmp/nvm/install-nvm.sh
export PATH=PATH=/usr/local/meritcommons/meritcommons/script:/usr/lib/postgresql/9.5/bin:/usr/local/meritcommons/node_modules/.bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/local/meritcommons/bin
export NVM_DIR=/usr/local/meritcommons/.nvm
export NODE_VERSION=v8.9.1
source $NVM_DIR/nvm.sh
nvm install $NODE_VERSION
nvm use $NODE_VERSION
npm install -g graceful-fs@^4.1.11 minimatch@^3.0.4
npm install -g bower@^1.8.2
npm install -g gulp@^3.9.1 requirejs@^2.3.5
npm install -g grunt@^1.0.1 grunt-cli@^1.2.0 grunt-contrib-requirejs@^1.0.0 \
               grunt-modernizr@^1.0.2 grunt-contrib-jshint@^1.1.0 grunt-contrib-watch@^1.0.0 
