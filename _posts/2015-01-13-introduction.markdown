---
layout: post
title:  "The Internet of Plants: turning your collective black thumb green"
date:   2015-01-16 17:05:58
categories: About, Introduction
permalink: /about/
---
Keeping plants alive in an office without regular hours is hard: Either everybody thinks their colleagues have already watered the plants or multiple people water the same plant, resulting in either drought or overhydration. This can be solved with technology: If each plants' humidity status is displayed publicly, co-workers can take matters into their own hands without fear of interfering with an absent colleagues' plant-watering scheme.

This blog documents our journey towards the realization of such a system, dubbed the Internet of Plants (IoP).

## How does it work, exactly?
To the end user, the IoP consists of two different entities: one sensor node per plant, which is plugged into its flower pot, and a web interface, which is maintained by the so-called display node. The IoP is self-configuring. That means the user won't have to re-flash their nodes when they change plants, or register each new plant with the IoP. Whenever a new plant is detected in the IoP, the web interface will show a new, blank spot for this plant. Now, the humidity needs and a picture of the plant can be added by the user, and that's it.
A plant has three statuses: happy, okay or thirsty. Whenenver a member of the IoP feels thirsty, it will send a tweet and/or E-Mail. After it has been watered, it will tweet and/or E-Mail again to prevent overhydration. Additionally, the status of all plants can be checked through the web interface. This way, users can see that they should water an “okay” plant before a long weekend even though it did not cry for help yet.

## Protocol stack
- [CoAP](http://coap.technology) ([libcoap](http://libcoap.sourceforge.net) and [Californium](https://eclipse.org/californium/))
- [RPL](https://tools.ietf.org/html/rfc6550)/[AODVv2](http://tools.ietf.org/html/draft-ietf-manet-aodvv2-06)
- [6LowPAN](http://en.wikipedia.org/wiki/6LoWPAN)
- [IEEE 802.15.4](http://en.wikipedia.org/wiki/IEEE_802.15.4)

## Hard- and Software

### Plant nodes
For the plant nodes, we chose to use the [Atmel SAM R21](http://www.atmel.com/tools/ATSAMR21-XPRO.aspx) boards equipped with a [DFROBOT SEN0114 humidity sensor](http://www.dfrobot.com/index.php?route=product/product&product_id=599) because it is robust against oxidation caused by moist soil and said to be suitable for plant-monitoring.
All plant nodes run [RIOT](http://riot-os.org/), an embedded Operating System designed for the Internet of Things, featuring a network stack running 6LoWPAN over IEEE 802.15.4. Plant nodes will have an application which registers them with the IoP, reads their humidity sensor and reports back to the display node using CoAP.
The SAM R21 board is somewhat costly, so it might not be ideal for others that don't happen to have some lying around. However, the beauty of RIOT is that the base code can be re-used: As long as there is a RIOT port for the board you want to use, all it takes is one changed line in the Makefile to deploy the IoP code on it.

### Display node
The display node is a [Raspberry Pi](http://www.raspberrypi.org). It manages all plants, collects their humidity statuses and posts changes to the web interface. To accomplish this, it serves as a web server and runs Californuim. All CoAP messages received through Californium are handled and passed to the server if need be.
The display node also functions as the border router, connecting our Internet of Plants to the “big” internet. To do this, it is equipped with both an Ethernet connection to the internet and a [R-IDGE 6LoWPAN USB Router](http://rosand-tech.com/products/r-idge/prod.html) for communication with the plant nodes.

## Code
All of our code can be found [on github](https://github.com/internet-of-plants).
