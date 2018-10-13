---
layout: post
title: Setting up the Border Router
subtitle: R-Idge 6LoWPAN router meets the Rasperry Pi
cover_image: covers/raspi.jpg
authors:
    - martin
    - lucas
---

Providing our office flowers with intelligent equipment to measure humidity and giving them the ability to form a network over IEEE 802.15.4 is all well and good. Unfortunately, this only creates a network amongst office flowers, which is separated from the internet.

To provide a connection between this network and the Internet, thus enabling Humans™ to know that they should water the plants, we need to setup a border router to evolve the _network of plants_ to the _Internet of Plants_. This post explains how to prepare the border router components, for which we have chosen the Rasperry Pi with 6LoWPAN capabilities provided by the R-Idge USB router.

<!-- more -->

# Installing Raspbian on the Raspberry Pi

First we need to download a recent version of [Raspbian](http://www.raspbian.org/), a Linux distribution specifically made for the Raspberry Pi. This image will be flashed onto an SD Card to serve as the operating system. For this post we used __Rasbian Debian Wheezy, version December 2014__, which can be downloaded [here](http://www.raspberrypi.org/downloads). After the download finishes we follow the [comprehensive guide](http://elinux.org/RPi_Easy_SD_Card_Setup) on how to flash the image to the SD Card published by [elinux.org](http://elinux.org/RPi_Easy_SD_Card_Setup), which covers Windows, OS X and Linux users.

Now we insert the freshly flashed SD Card into our RasPi, connect a monitor, plug in a keyboard and connect the RasPi to with the Internet using a _good old_ ethernet cable.

![](images/raspi/raspi-config2.png)

When booting the Raspberry Pi, you will be presented with an initial configuration screen for basic setup of the operating system similar to the above. This screen includes the "Expand Filesystem" option which gives you read-write access to the entire SD card from within Raspbian. This one should be definitely selected. For a more detailed explanation on all options please check out [elinux.org](http://elinux.org/RPi_raspi-config). After finishing the setup procedure, restarting and logging in, we are finally presented with (or similar):

    Linux raspberrypi 3.12.35+ #730 PREEMPT Fri Dec 19 18:31:24 GMT 2014 armv6l

    The programs included with the Debian GNU/Linux system are free software;
    the exact distribution terms for each program are described in the
    individual files in /usr/share/doc/*/copyright.

    Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
    permitted by applicable law.
    Last login: Mon Jan 26 10:13:52 2015
    pi@raspberrypi ~ $
{: .wide }

**Note:** if you've chosen the graphical user interface, open a terminal (i.e. click the "black monitor" icon) to proceed. Of course this only works if you plugged in a mouse or similar. If not, you can hit `CTRL+ESC` to navigate through the Menu and choose `Accessoirees > Terminal` with the arrow keys and hit enter, which also opens a new terminal window.
{: .alert .alert-info }

To finish the initial installation, we do an update of Raspbian to get the most recent versions of the installed packages. To do this, we run in a terminal:

~~~bash
sudo apt-get update &&
    sudo apt-get upgrade &&
    sudo apt-get dist-upgrade
~~~

**Warning:** Running a `dist-upgrade` is a potentially destructive operation, so it is **NOT** recommended if you don't have a dedicated installation of Raspian for this excercise.
{: .alert .alert-danger }

- The first line fetches all information for packages and available updates.
- The second line updates the currently installed packages.
- The third line installs new and updated packages, including kernel updates.

Now we have an up-to-date foundation of Raspbian to start setting up a border router!

# Preparing the Internet of Plants

After the initial installation of Raspbian we need to configure it further to enable the Raspberry Pi to act as a border router. The first thing to be done is to enable IPv6. In the initial configuration of Raspbian only IPv4 handling is activated. We can check this by entering `lsmod | grep ipv6` in a terminal. When IPv6 support is not activated, this command returns with no output. To load the IPv6 kernel module we enter `sudo modprobe ipv6`, which should return with no output if the loading succeeded. Entering `lsmod | grep ipv6` again will present us with:

    ipv6                  316254  20

indicating that the module is loaded. To load the module automatically at boot time we enter

    :bash:
    echo ipv6 | sudo tee -a /etc/modules

which appends `ipv6` as last line to `/etc/modules`. The next time we boot, the `ipv6` module will be loaded automatically.

# Operating the R-Idge USB router

To provide connectivity to other IEEE 802.15.4 devices we use the [R-Idge](http://rosand-tech.com/products/r-idge/prod.html) 6LoWPAN USB router. After the USB stick is plugged in, it should create a new available network interface called `usb0`. We can check this entering `ifconfig usb0` which will provide us with information on the interface:

    usb0      Link encap:Ethernet  HWaddr 02:12:4b:e4:0a:83
    inet6 addr: fe80::12:4bff:fee4:a83/64 Scope:Link
    UP BROADCAST RUNNING MULTICAST  MTU:1280  Metric:1
    RX packets:0 errors:0 dropped:0 overruns:0 frame:0
    TX packets:13 errors:0 dropped:0 overruns:0 carrier:0
    collisions:0 txqueuelen:1000
    RX bytes:0 (0.0 B)  TX bytes:2018 (1.9 KiB)

Note: if you are presented with (or similar):

    pi@raspberrypi ~ $ ifconfig usb0
    usb0: error fetching interface information: Device not found

the interface has probably received a different name from the operating system. You can list all available and active interfaces by entering `ifconfig`.

To verify if any of shown network interface is our R-Idge USB router, we enter `dmesg -T | tail | grep RNDIS`.
We will be presented with the following output:

    [Mon Jan 26 12:39:27 2015] rndis_host 1-1.3.4:1.0 usb0: register 'rndis_host' at usb-bcm2708_usb-1.3.4, RNDIS device, 02:12:4b:e4:0a:83

We can then compare the shown hardware address (at the far end of the shown line) with the `HWaddr` presented in the first line of the entered `ifconfig` command. If the addresses match everything is fine and we can move on to configure our R-Idge 6LoWPAN USB router.

## Configuring the R-Idge 6LoWPAN router

To configure the router, we need to use the provided _Configuration program_ from [Rosand Technologies](http://rosand-tech.com/products/r-idge/doc.html). Unfortunately the provided binary/installation packages are not compiled for being used on the Raspbian, so we need to build them from source. For the build we need to install the tools required to build the source by entering

    sudo apt-get install bison flex wget

After `bison` and `flex` are installed we can proceed to build the configuration program:

~~~bash
wget http://rosand-tech.com/downloads/cfgtool-1.00.tar.gz &&
    tar -xvzf cfgtool-1.00.tar.gz &&
    cd cfgtool-1.00 &&
    ./configure &&
    make
~~~
{: .wide }

After the build finishes, we create a new directory for the compiled binary (`mkdir ../cfgtool-bin`), and copy the relevant files there by entering

    cp cfgtool ../cfgtool-bin/ &&
        cp cftool.conf ../cfgtool-bin/

Now we change the directory to `cd ../cfgtool-bin` and configure our R-Idge USB router. To have a look in the current setup of the R-Idge USB router, we enter

~~~bash
./cfgtool -p ridge \
          -c serial \
          -C ./cfgtool.conf \
          -U channel:r: \
          -U power:r: \
          -U panid:r: \
          -U prefix:r:
~~~

This will present us with the following (or similar):

    channel = 21
    power = 21
    panid = 0x3e9
    prefix = 3

The most interesting values here are the `channel` and the `panid`. These values must both be the same for all  communication participants, i.e. the R-Idge router and any node in the network. To change these values we set the according parameters to write (exchange `:r:` with `:w:` in the command above) and provide an appropriate value, e.g we set channel to 22 and the panid to 0x123:

~~~bash
./cfgtool -p ridge \
          -c serial \
          -C ./cfgtool.conf \
          -U channel:w:22: \
          -U panid:w:0x123:
~~~

Which should result in the following output:

    cfgtool: 1 bytes of channel written
    cfgtool: verifying channel memory:
    cfgtool: reading on-chip channel data:
    cfgtool: verifying ...
    cfgtool: 1 bytes of channel verified
    cfgtool: 2 bytes of panid written
    cfgtool: verifying panid memory:
    cfgtool: reading on-chip panid data:
    cfgtool: verifying ...
    cfgtool: 2 bytes of panid verified

Reading the configuration again (as done above) reveals that the new values are set:

    channel = 22
    power = 21
    panid = 0x123
    prefix = 3

**Note:** These values are examples. You need to make sure that whatever you set in the configuration tool for the R-Idge router matches the parameters that you set in your RIOT application and/or other hardware which might want to communicate with the border router.
{: .alert .alert-info }


# Next steps

This concludes the basic setup of the R-Idge router on the Raspberry Pi. Now that we have both the {% postlink 2015-01-10-samr21-dev-setup-ubuntu SAM R21 %} and the Rasperry Pi set up, the next step is to establish communication between both devices, which will be the topic of an upcoming post. So stay tuned :smile:
