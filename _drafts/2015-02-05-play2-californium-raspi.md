---
layout: post
title: Raspi/Californium/Play2
author: lucas
---

* The raspberry serves both as coap client/server as well as webserver for the watr-li management dashboard (manages nodes)
* Dashboard (play app) is started, which then starts the coap client/server
* background job is an actor started in the play's object Global 
* deploying application to the raspi: `./activator stage` then rsync to raspi and start with low memory settings
* sqlite because easy and low memory footprint

TODO: connect the stuff to usb0
TODO: how to test web-interface locally

In build.sbt before building add (if openjdk7 is used and you have Java 8):

    javacOptions ++= Seq("-source", "1.7", "-target", "1.7")

First

    ./activator stage # on the build system

Then rsync `target/universe/stage` to raspi. Then run

    JAVA_OPTS="-Xmx64M -Xms16M -XX:PermSize=24M -XX:MaxPermSize=64M" ../bin/iop-dashboard

Woohooo!
