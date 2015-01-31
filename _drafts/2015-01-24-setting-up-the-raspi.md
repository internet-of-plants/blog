---
layout: post
title:  Development setup of the Raspberry Pi with the R-Idge 6LoWPAN router
author: lucas
---

<!-- more -->

# Packages to install




# Starting the R-Idge border router

[Docs](http://rosand-tech.com/products/r-idge/doc.html) for the R-Idge router.

1. load the ipv6 kernel module
        - `sudo modprobe ipv6`

2. sudo modprobe rndis_host

3. sudo ip -6 address add 2001:db8:1::1/64 dev usb0


4. sudo su // for ND
        - echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
        - exit

4. Create a /etc/radvd.conf with the following content

        interface usb0
        {
           AdvSendAdvert on;
           prefix 2001:db8::/64 # should this not be 2001:db8:1::/64?
           {
           };
        };


ifconfig should look something like this:

    usb0    Link encap:Ethernet  HWaddr 02:12:4b:e4:0a:e8
            inet6 addr: 2001:db8:1::1/64 Scope:Global
            inet6 addr: fe80::12:4bff:fee4:ae8/64 Scope:Link

5.  sudo service radvd start


4. sudo ./rpld -i usb0 // for rpld


# Configuring R-idge

We need to

1. set the pan id
    
    # read the panid
    sudo ./cfgtool -C cfgtool.conf  -p ridge -c serial -U panid:r:

    # write the panid
    sudo ./cfgtool -C cfgtool.conf  -p ridge -c serial -U panid:w:0x3e9:
    

1. set the channel number

    # read the channel number
    sudo ./cfgtool -C cfgtool.conf  -p ridge -c serial -U channel:r: #

    # write the channel number
    sudo ./cfgtool -C cfgtool.conf  -p ridge -c serial -U channel:w:21:


# Logging the packets with (t)wireshark

On the console:

    sudo tshark -i usb0
