---
layout: post
title: The Atmel SAM R21 
subtitle: Setting up a RIOT development environment
categories: jekyll update
author: lucas
cover_image: covers/samr21.jpg
---



For the internet of plants, we have decided to use the [Atmel SAM R21](http://www.atmel.com/tools/ATSAMR21-XPRO.aspx), a Cortex M0 based platform with an on-board IEEE 802.15.4 wireless module, to monitor our green friends.This post explains the general process of setting up a development environment for RIOT applications on Ubuntu 14.10, taking into account the peculiarities of the SAM R21 board.

<!-- more -->



# Package requirements

The following packages are needed for building the necessary tools and the RIOT application:

* General: git, pkg-config, autoconf, libtool, unzip
* OpenOCD: libudev-dev, libusb-1.0-0-dev

They are easily installable through apt by running

    sudo apt-get install git pkg-config autoconf \
        libudev-dev libusb-1.0-0-dev libtool unzip

In addition it is recommendable to update Ubuntu to the latest version after installing, by invoking

    sudo apt-get update &&
        sudo apt-get dist-upgrade



# Building OpenOCD

The Open On-Chip-Debugger (OpenOCD) is used by the RIOT buildsystem for flashing the application onto the board and to debug it. The current release (v0.8.0) of [OpenOCD](http://openocd.sourceforge.net/), however, does not contain configuration files for the SAM R21 board, so it has to be built from source. OpenOCD also requires hidapi, which is not available as a package on Ubuntu 14.10. The following script will clone, build and install hidapi if all goes well:
    
    :bash:
    TMP=$(mktemp) &&
        rm -r $TMP &&
        mkdir -p $TMP &&
        cd $TMP &&
        git clone http://github.com/signal11/hidapi.git &&
        cd hidapi &&
        ./bootstrap &&
        ./configure &&
        make &&
        sudo make install &&
        sudo ln -s /usr/local/lib/libhidapi-hidraw.so.0 \
            /usr/lib/libhidapi-hidraw.so.0

Now that all requirements are installed, OpenOCD can be built:

    :bash:
    TMP=$(mktemp) &&
        rm -r $TMP &&
        mkdir -p $TMP &&
        cd $TMP &&
        git clone http://repo.or.cz/openocd.git &&
        cd openocd &&
        ./bootstrap &&
        ./configure --enable-maintainer-mode \
                    --enable-cmsis-dap \
                    --enable-hidapi-libusb &&
        make &&
        sudo make install




# Installing the toolchain

The "[GNU Tools for ARM Embedded Processors](https://launchpad.net/gcc-arm-embedded)" toolchain (as recommended in [the RIOT wiki](https://github.com/RIOT-OS/RIOT/wiki/Board:-Samr21-xpro)) can easily be installed via apt using the following script.

Note that a warning could be displayed that there are conflicting package names with the Debian apt repositories. That warning is already taken into consideration here and you can safely proceed by pressing enter. Also note that this installs the 64-bit version of the toolchain.

    sudo apt-get remove binutils-arm-none-eabi gcc-arm-none-eabi &&
        sudo add-apt-repository ppa:terry.guo/gcc-arm-embedded &&
        sudo apt-get update &&
        sudo apt-get install gcc-arm-none-eabi=4.9.3.2014q4-0utopic12
{: .wide }



# Building the RIOT example application

Now that all the requirements are set up, a very basic RIOT-based application can be built and flashed onto the board. So after RIOT is cloned into a directory of choice (via [github.com/RIOT](https://github.com/RIOT-OS/RIOT)) we can navigate to the `examples/hello-world` directory and build the application:

    :bash:
    git clone git@github.com:RIOT-OS/RIOT.git &&
        cd RIOT/examples/hello-world &&
        export BOARD=samr21-xpro &&
        make

The only non-standard line here is the definition of the `BOARD` environment variable which tells the RIOT build system which hardware we are targeting. 


# Flashing and running the application

The next step is to get the application onto the board, run it and see the output it produces. The RIOT build system is already configured to do all of this for the SAMR board, under the assumption that OpenOCD is installed. For this we need two separate terminals: one where the command to flash the board is invoked and the other where the output from the board is displayed. In the first one we execute

    :bash:
    sudo usermod --append --groups dialout <your username>

**Note:** You need to log out and back in for the user group changes to take effect!
{: .alert .alert-warning }

This adds your user to the `dialout` group, which will allow it to access the serial console of the SAM R21 without requiring root privileges. Having the proper privileges we can then start [pyterm](http://pyterm.sourceforge.net/), a serial port terminal emulator written in Python, listening to the output of the board:

    :bash:
    export BOARD=samr21-xpro &&
        make term

Now that we will be able to see the output we can flash the application. Again, we have to take some extra steps so that this can be done without requiring root access. When using OpenOCD with the hidapi, `/dev/hidraw[0-9]+` devices are created. In order to access these, we have to create a new file in `/etc/udev/rules.d`. We will call this file `99-hidraw-permissions.rules` and add the following content:

    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0664", GROUP="plugdev"

This will enable the `plugdev` group, which your default Ubuntu user should already be a part of, to access the kernel devices required for flashing the board. Now that all privileges are set up, we can finally run

    :bash:
    export BOARD=samr21-xpro &&
        make flash

The CMSIS-DAP interface for flashing and debugging [is quite slow](http://sourceforge.net/p/openocd/mailman/message/32496519/) (should be around 2KiB/s). So when flashing, you might need to wait a little longer. You can also apply an [OpenOCD patch](http://openocd.zylin.com/#/c/2356/) that increases flashing speed by 50-100%.
{: .alert .alert-warning }

`make flash` flashes and subsequently resets the board, causing the application to run. For our hello world example, it should result in the following output being shown in the terminal window in which `make term` was executed:

    INFO # kernel_init(): This is RIOT! (Version: 2014.12-285-gfe295)
    INFO # kernel_init(): jumping into first task...
    INFO # Hello World!
    INFO # You are running RIOT on a(n) samr21-xpro board.
    INFO # This board features a(n) samd21 MCU.
{: .wide }




# That's all, folks!

Now that the development environment for RIOT has been set up and applications can be flashed onto the board, you're ready to develop your first RIOT-based IoT application!

For more information about RIOT on the SAM R21, please visit the [wiki page](https://github.com/RIOT-OS/RIOT/wiki/Board:-Samr21-xpro) for the board in the RIOT repository. If you have any questions on the setup procedure or if anything is not working quite right, please leave a comment!

This article is based on [a great post by David Karibe](http://karibe.co.ke/2013/08/setting-up-linux-opensource-build-and-debug-tools-for-freescale-freedom-board-frdm-kl25z/) on setting up an open-source development toolchain for the Freescale FRDM-KL25Z board.
