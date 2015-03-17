---
layout: post
title: Running the Dashboard on a RasPi
author: lucas
#date: 2015-02-10
---

If you'd like to play around with the Watr.li Dashboard, you can deploy it on your own RasPi or wherever else you might want to. You don't even need any additional hardware since you can send the necessary CoAP requests with the Eclipse Copper Firefox plugin.

<!-- more -->

# What we're going to install

As described in LINK TO PREV POST, we're using the Play framework to build the webinterface, so you're going to need Java installed on the target system. MySQL is being used as the database, and since we need to serve static assets (the plant images) from an upload directory we're using nginx as a proxy server for all incoming HTTP requests (which excludes CoAP).

!!! the image !!!


* install mysql server >= 5.5
* install nginx >= 1.6.2
* install java runtime
* create a database for the watrli dashboard and optionally create user for it

# Running

After deploying the application (as described in [this post][http://watr.li/play2-californium.html]), copy the `application.conf` file from the `stage/conf/` directory to another location and edit the database settings (under `db.default`) and the `dashboard.uploadDirectory`. The latter must be set to an existing, writable directory which contains a `pictures` folder.

After this preparation, we can run the play application:

    JAVA_OPTS="-Xmx64M -Xms16M -XX:PermSize=24M -XX:MaxPermSize=64M -DapplyEvolutions.default=true -Dconfig.file=/home/pi/application.conf" ./bin/dashboard

The first four options are memory related. If you're on a system with more than 1GB of RAM, you can drop them. Also adjust the config.file directive such that it points to the configuration file you've created.

Now that the play application is running we still need to run the nginx proxy which will also serve the uploaded static assets.

You can get the nginx config I've used from 

    https://raw.githubusercontent.com/watr-li/dashboard/master/nginx/nginx.conf

Adjust the paths to logfiles according to your directory structure and make sure to set the `root` for the `location /pictures/` to the same path that you specified for `dashboard.uploadDirectory` in the play configuration.

After doing all that you can start nginx by running:

    nginx -p /home/pi/nginx -c nginx.conf

Where `-p` specifies the working directory for nginx, i.e. what the directories in the configuration file will be relative to, and -c specifies the name of the configuration file. An example of how I start nginx can be found [here](https://raw.githubusercontent.com/watr-li/dashboard/master/start_proxy.sh).


