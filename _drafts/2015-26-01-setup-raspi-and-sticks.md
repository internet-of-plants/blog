# Setting up the Raspberry

While providing our office flowers with intelligent equipment to measure humidity and provide communication abilities
to form a network over IEEE802.15.4 with other plants, this network is autonomous and separated from the Internet.  
To provide a connection between this network and the Internet we need to setup a border router to enhance the _network of plants_ to the _Internet of Plants_.

## Install the Raspbian on the Raspberry Pi
First we need to download a recent [Raspbian](http://www.raspbian.org/) Image to be flashed on the SD Card as operating system.  
We use the __Rasbian Debian Wheezy, version December 2014__ which can be downloaded here: http://www.raspberrypi.org/downloads/.  

After the download finished we write the Rasbian image to the SD Card.  
_A comprehensive guide how to write to a SD Card can be found here: http://elinux.org/RPi_Easy_SD_Card_Setup._

We insert the fresh flashed SD Card to our RasPi, connect a monitor, plug in a keyboard and connect the RasPi to with the Internet over _good old ethernet_.  
When we finish the installation/setup procedure, restart and login we are finally presented with (or similar):
```
Linux raspberrypi 3.12.35+ #730 PREEMPT Fri Dec 19 18:31:24 GMT 2014 armv6l

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Mon Jan 26 10:13:52 2015
pi@raspberrypi ~ $
```
Note: if you chosen the graphical login and logged in, open a terminal (i.e. click the "black monitor" icon) to proceed.  
Obviously this only works if you plugged in a mouse or similar.  
If not, you can hit `CTRL+ESC` to navigate through the Menu and choose `Accessoirees > Terminal` with the arrow keys and hit enter,
which also opens a new terminal window.


To finish the initial installation, we do an update of the Raspbian to get the most recent versions of the installed packages.  
We enter one by one:
```
sudo apt-get update
sudo apt-get upgrade
sudo apt-get dist-upgrade
```
- The first line fetches all information for packages and available updates.
- The second line updates the current installed packages.
- The third line installs new and updated packages.

Now we have a recent foundation of Raspbian to start creating a border router.

# Prepare the Internet of Plants
After the initial installation of Rasbian we need to configure it further to enable the RasPI acting as border router.  
First we need to enable IPv6. In the initial configuration of Raspbian only IPv4 handling is activated automatically.
We can check this by entering `lsmod | grep ipv6` in a terminal.
When IPv6 support is not activated, this command returns with no output.

To load the IPv6 kernel module we enter `sudo modprobe ipv6`, which should return with no output if the loading succeeded.
Entering `lsmod | grep ipv6` again will present us with:
```
ipv6                  316254  20
```
telling us that the module is loaded.

To load the module automatically at boot we enter `echo ipv6 | sudo tee -a /etc/modules`, which appends `ipv6` as last line to `/etc/modules`.
The next time we boot, the `ipv6` module will be loaded automatically.

## Operate the R-IDGE USB router
To provide connectivity to other IEEE802.15.4 devices we use the [R-IDGE](http://rosand-tech.com/products/r-idge/prod.html) 6LoWPAN USB router.
After the USB stick is plugged in, it should create a new available network interface, `usb0`.
We can check this entering `ifconfig usb0` which will provide us with information on the given network interface:
```
usb0      Link encap:Ethernet  HWaddr 02:12:4b:e4:0a:83  
inet6 addr: fe80::12:4bff:fee4:a83/64 Scope:Link
UP BROADCAST RUNNING MULTICAST  MTU:1280  Metric:1
RX packets:0 errors:0 dropped:0 overruns:0 frame:0
TX packets:13 errors:0 dropped:0 overruns:0 carrier:0
collisions:0 txqueuelen:1000
RX bytes:0 (0.0 B)  TX bytes:2018 (1.9 KiB)
```
Note: if you are presented with (or similar):
```
pi@raspberrypi ~ $ ifconfig usb0
usb0: error fetching interface information: Device not found
```
you can enter `ifconfig` without specifying an interface which will show all available and active interfaces.

To check if the shown network interface `usb0` is our R-IDGE USB router, we enter `dmesg -T | tail | grep RNDIS`.  
We will be presented with the following output:
```
[Mon Jan 26 12:39:27 2015] rndis_host 1-1.3.4:1.0 usb0: register 'rndis_host' at usb-bcm2708_usb-1.3.4, RNDIS device, 02:12:4b:e4:0a:83
```
and can compare the shown hardware address (at the far end of the shown line) with the `HWaddr` presented in the first line of the entered `ifconfig usb0` command.  
If the addresses match everything is fine and we can move on to configure our R-IDGE 6LoWPAN USB router.

### Configure the R-IDGE 6LoWPAN USB router
To configure the router, we need to use the provided _Configuration program_ from [Rosand Technologies](http://rosand-tech.com/products/r-idge/doc.html).  
Unfortunately the provided binary/installation packages are not compiled for being used on the Raspbian, so we need to build them from source.
For the build we need to install 2 tools required to build the source by entering `sudo apt-get install bison flex`.

After `bison` and `flex` are installed we can build the _Configuration program_:
- First we download the source archive for the _Configuration program_ from here: http://rosand-tech.com/downloads/cfgtool-1.00.tar.gz
- Now we extract the downloaded archive entering `tar -xvfz cfgtool-1.00.tar.gz`.
- We change the directory to the extracted folder `cd cfgtool-1.00`.
- Then we enter `./configure` to setup the build.
- After that we enter `make` which starts to build the sources.

When the build finished, we create a new directory for the compiled binary `mkdir ../cfgtool-bin`, and copy the relevant 2 files there by entering `cp cfgtool ../cfgtool-bin/ && cp cftool.conf ../cfgtool-bin/`.

Now we change the directory to `cd ../cfgtool-bin` and configure our R-IDGE USB router.  
To have a look in the current setup of the R-IDGE USB router, we enter `./cfgtool -p ridge -c serial -C ./cfgtool.conf -U channel:r: -U power:r: -U panid:r: -U prefix:r:`
This will present us with the following (or similar):
```
pi@raspberrypi ~/cfgtool-bin $ ./cfgtool -p ridge -c serial -C ./cfgtool.conf -U channel:r: -U power:r: -U panid:r: -U prefix:r:
channel = 21
power = 21
panid = 0x3e9
prefix = 3
```
The most interesting values here are the `channel` and the `panid`. These both values must be the same for the communication participants, i.e. the R-IDGE router and any node in the network.
To change these values we set the according parameter to write and provide an appropriate value, e.g we set channel to 22 and the panid to 0x123:
```
pi@raspberrypi ~/cfgtool-bin $ ./cfgtool -p ridge -c serial -C ./cfgtool.conf -U channel:w:22: -U panid:w:0x123:
cfgtool: swra327_paged_write: programmer did not respond to command.
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
```
Reading the configuration again reveals that the new values are set:
```
pi@raspberrypi ~/Development/cfgtool $ ./cfgtool -p ridge -c serial -C ./cfgtool.conf -U channel:r: -U power:r: -U panid:r: -U prefix:r:
channel = 22
power = 21
panid = 0x123
prefix = 3
```

With the `cfgtool` we have a tool at hand to set the desired parameters for the R-IDGE USB router.  
Next, we need to prepare some nodes for the _Internet of Plants_.

## Operate the nodes with RIOT [TODO]
## Make them talk [TODO]
