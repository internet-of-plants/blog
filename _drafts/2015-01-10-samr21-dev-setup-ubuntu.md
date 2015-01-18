---
layout: post
title:  Development setup with the Samr21 xproblablub on Ubuntu 14.10
date:   2015-01-10
categories: jekyll update
---

# TODO

* Explain what OpenOCD is?
* Make sources look nicer
* Add picture
* Add flashing section
    * why slow?
* perhaps try eclipse based debugging just for fun?
* Can flashing be done without r00t?



# Package requirements

The following packages are necessary for building the necessary tools and the RIOT application:

* General: git, pkg-config, autoconf
* OpenOCD: libudev-dev, libusb-1.0-0-dev

They are easily installable through apt by running

    sudo apt-get install git pkg-config autoconf libudev-dev libusb-1.0-0-dev




# Building OpenOCD

The current release (v0.8.0) of [OpenOCD](http://openocd.sourceforge.net/) does not contain configuration files for the Samr21 board, so it has to be built from source. OpenOCD also requires hidapi, which is not available as a package on Ubuntu 14.10. The following script will clone, build and install hidapi if all goes well:

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
        sudo ln -s /usr/local/lib/libhidapi-hidraw.so.0 /usr/lib/libhidapi-hidraw.so.0

Now that all requirements are installed, OpenOCD can be built:

    TMP=$(mktemp) &&
        rm -r $TMP &&
        mkdir -p $TMP &&
        cd $TMP &&
        git clone http://repo.or.cz/openocd.git &&
        cd openocd &&
        ./bootstrap &&
        ./configure --enable-maintainer-mode --enable-cmsis-dap --enable-hidapi-libusb &&
        make &&
        sudo make install




# Installing the toolchain

The "[GNU Tools for ARM Embedded Processors](https://launchpad.net/gcc-arm-embedded)" toolchain (as recommended in [the RIOT wiki](https://github.com/RIOT-OS/RIOT/wiki/Board:-Samr21-xpro)) can easily be installed via apt using the following script.

Note that a warning could be displayed that there are conflicting package names with the Debian apt repositories. That warning is already taken into consideration here and you can safely proceed by pressing enter. Also note that this installs the 64-bit version of the toolchain.

    sudo apt-get remove binutils-arm-none-eabi gcc-arm-none-eabi &&
        sudo add-apt-repository ppa:terry.guo/gcc-arm-embedded &&
        sudo apt-get update &&
        sudo apt-get install gcc-arm-none-eabi=4.9.3.2014q4-0utopic12




# Building the RIOT example application

Now that all the requirements are setup, a very basic RIOT-based application can be built and flashed onto the board. So after RIOT is cloned into a directory of choice (via [github.com/RIOT](https://github.com/RIOT-OS/RIOT)) we can navigate to the `examples/hello-world` directory and build the application:

    export BOARD=samr21-xpro &&
        make

Get RIOT: https://github.com/RIOT-OS/RIOT
Build the example app


# Flashing and seeing output (TODO: Better title)

# Debugging (?)

# Troubleshooting

* The CMSIS-DAP interface for flashing and debugging is quite slow (should be around 2KiB/s). So when flashing, you might need to wait a little longer.
* If you get a permission error, such as "Unable to open CMSIS-DAP device": Flashing might need to be performed as root.

# Sources

* http://karibe.co.ke/2013/08/setting-up-linux-opensource-build-and-debug-tools-for-freescale-freedom-board-frdm-kl25z/
* https://github.com/RIOT-OS/RIOT/wiki/Board:-Samr21-xpro
