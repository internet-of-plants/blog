---
layout: post
title: Workshop Guide
hidden: true
author: lotte
date: 2015-01-29
---


# Grenoble RIOT Workshop Guide

For the workshop we will assume that you are familiar with the basics of the following:

- Using a linux terminal
- The C programming language

However, first and foremost, we're here to learn and help each other. You don't have to know everything in order to be able to participate. If you're unsure about anything, or feel that you'd like some help, please do not hesitate to ask the RIOT team. We know that it may be a lot to grasp at once, and we're happy to answer all questions, no matter how trivial they may seem.


# Development environment

RIOT requires you to install and compile some dependencies. We've prepared a VMware Virtual Machine which is all set up and ready to go. We will distribute said virtual machine via USB sticks at the beginning of the workshop. To use it, you will need to have VMware installed on your system. Trials are available at [vmware.com](https://my.vmware.com/web/vmware/downloads).

In case you prefer to set everyting up yourself, you can follow [this guide](http://watr.li/samr21-dev-setup-ubuntu.html) up until (but not including) the section “Building a RIOT example application”.

RIOT does have experimental Windows support. If you'd prefer to use Windows as your host system, you can consult [this guide](https://github.com/RIOT-OS/RIOT/wiki/Build-RIOT-on-Windows-OS), but it doesn't cover how to flash an application. However, a word of warning: you probably know much more about your Windows machine than we do, and we might not be able to help you in case you run into trouble.


## Tip: SSH & sshfs for your VM

While our VM has a GUI, this can be annoyingly slow. Alternatively, you can use sshfs to mount your VM's home directory as if it were a regular directory on your host system:

    sshfs riot@ip.of.your.vm:/home/riot some_directory/

(get your VM's IP by launching the Terminal application and entering ``ifconfig eth0``)

You can then ssh onto your VM and run all make, flash etc commands from your host system's terminal:

    ssh riot@ip.of.your.vm:/home/riot


# Getting started with RIOT

Now that you're well-prepared, let's get you started! The goal of this section is to show you how to build and flash a RIOT application. 

## Building a RIOT app

Checking out the RIOT repository work like follows. We've used a fork of the main RIOT repository to work around a memory issue on the SAM R21 that has not yet been merged to the RIOT master.

    git clone https://github.com/watr-li/RIOT.git &&
        cd RIOT &&
        git checkout workshop &&
        cd ..

Now that we have checked out the RIOT repository, we can fetch some example applications:

    git clone https://github.com/watr-li/applications.git &&
    cd applications &&
    git checkout master
{: .wide }

Now we're inside the `applications/` folder and we can try to build our first application, the `chat`:

    cd chat &&
        make all


## Running it in native mode

You can run and test an application on your own computer with the ``native`` mode. The network is emulated through tun/tap devices which are connected through a tapbridge. This bridge has to be created beforehand:

    RIOT/cpu/native/tapsetup.sh create
    
Now you can start your RIOT application in native mode:

    make term

In a new terminal, start another RIOT, this time listening on ``tap1``:

    PORT=tap1 make term

(Note that `make term` only works if you've previously built your application. For non-native mode it will try to open up a serial connection to the hardware.)

Type help to see all commands available in the RIOT shell.
Use the ``say`` command in one RIOT shell to send a string to the other RIOT instance. If it arrives, you're ready to go!


## Flashing it to the SAMR21

Attach your SAM R21 board via microUSB. You'll need two terminals for this: one for flashing and one to view the debug output.  

#### Setting up the output terminal

In this terminal we start a [pyterm](http://pyterm.sourceforge.net/) instance, a serial port terminal emulator written in Python, listening to the output of the board:

    :bash:
    export BOARD=samr21-xpro &&
        make term

This should result in the following being printed, after which pyterm waits for output from the board:

    INFO # Connect to serial port /dev/ttyACM0
    Welcome to pyterm!
    Type '/exit' to exit.


#### Running the flash command

Now we can switch to the other terminal window in which we will invoke the commands to flash the application onto the board:

    :bash:
    export BOARD=samr21-xpro &&
        make flash

The CMSIS-DAP interface for flashing and debugging [is quite slow](http://sourceforge.net/p/openocd/mailman/message/32496519/) (should be around 3-5KiB/s). So when flashing, you might need to wait a little longer. You can also apply an [OpenOCD patch](http://openocd.zylin.com/#/c/2356/) that increases flashing speed by 50-100%.
{: .alert .alert-warning }

`make flash` flashes and subsequently resets the board, causing the application to run. For our hello world example it should result in the same output you've already seen in the native version of the application.

You can play around with the application, send messages to the other workshop participants over UDP and see if their messages arrive on your board!



## Adding your own code

Now that you're familiar with RIOT, it's time to add your own code. At the end of this tutorial, you'll have built a distributed chat application which lets you communicate with the other workshop participants. All chat messages will be sent over CoAP, and the resource the CoAP messages are targeting determines the chat channel you're in.

### ``nick``: add your own shell command

**Goal:** Create a shell command ``nick <nickname>`` which lets you set your nickname.
{: .alert .alert-info }

RIOT has a shell implementation which can be extended with your own commands. To do this, you'll have to extend the ``shell_commands[]`` array with your own ``shell_command_t``, which is defined as follows:

    :c:
    /**
     * @brief           A single command in the list of the supported commands.
     * @details         The list of commands is NULL terminated,
     *                  i.e. the last element must be ``{ NULL, NULL, NULL }``.
     */
    typedef struct shell_command_t {
        const char *name; /**< Name of the function */
        const char *desc; /**< Description to print in the "help" command. */
        shell_command_handler_t handler; /**< The callback function. */
    } shell_command_t;

For your first step towards chatting with RIOT, write a function that lets you set your nickname. Then, add a ``shell_command_t`` which lets you call this function from your RIOT shell with the command ``nick <nickname>``.

Re-build your application with ``make`` (in native mode) and try your new shell command by executing the binary with:

    make term


### ``say``: send chat messages

**Goal:** Create a shell command ``say <message>`` which sends a chat message. The message should be in the payload of a CoAP PUT request directed at the resource ``chat/default/``. The message should be prepended with your nick.
{: .alert .alert-info }

Now that you can set your nick name, let's send some chat messages!
Again, we'll need to add a ``say <message>`` command to the shell. 
Each message should be wrapped into a CoAP PUT request. CoAP requests are– just like HTTP requests– directed at a *resource*. The default resource for our messages is ``chat/default/``.

In microcoap, resources are represented by the following struct:

    :c:
    typedef struct
    {
        int count;
        const char *elems[MAX_SEGMENTS];
    } coap_endpoint_path_t;

Each element of ``coap_endpoint_path_t.elems`` should be one segment of the path, like so:

    coap_endpoint_path_t chat_path = {2, {"chat", "default"}};
{: .wide }

The payload of the PUT request is our chat message. In order to make it identifiable, make sure to prepend it with your nickname, like so:

    "my_nick: hello"

Once you've created your payload, you can use ``int coap_ext_build_PUT(uint8_t *buf, size_t *buflen, char *payload, coap_endpoint_path_t *path)`` to build your put request. Now, you can use ``chat_udp_send()`` to send the content of ``buf``.

(For the sake of simplicity, all messages are sent to the link-local all nodes multicast address by ``chat_udp_send()``)

If you want to send messages wich contain spaces, the shell will recognize each word as a single argument, so you can have different values for ``argc`` and ``argv``. Bonus points for concatenating them!
{: .alert .alert-info }

### Receive messages

The base application contains a ``chat_udp_server_loop()`` which receives plain UDP mssages. However, our chat messages aren't plain text anymore, they're CoAP packets now. So instead of just printing the contents of ``buffer_main``, you'll need to handle these packets properly. We'll be doing this with microcoap too.

For a more detailed explanation of microcoap servers, please visit [this page.](http://watr.li/microcoap-and-ff-copper.html){: .alert .alert-info }

First, you'll need to specify an endpoint which specifies for which combinations of request method and resource path a certain callback function should be called. Endpoints are defined as follows:

	:c:
	typedef struct
	{
    	coap_method_t method;
    	coap_endpoint_func handler;
    	const coap_endpoint_path_t *path;
    	const char *core_attr;
	} coap_endpoint_t;

All endpoints need to be stored in an array which **must** be called ``endpoints`` and end with a NULL'ed script. It should look something like this:

	:c:
	const coap_endpoint_t endpoints[] =
	{
    	{COAP_METHOD_GET, handle_get_response, &path, "ct=0"},
    	{(coap_method_t)0, NULL, NULL, NULL} /* marks the end of 
        	                                  * the endpoints array */
	};
{: .wide }

But keep in mind that we're expecting to handle a ``PUT`` request! ;)   
Now you can implement the callback function handling the CoAP packet (which is called ``handle_get_response`` in the above).   
After doing that, you'll need to teach ``chat_udp_server_loop`` how to understand CoAP messages:

	:c:
    if (0 != (rc = coap_parse(&pkt, buf, n)))
        printf("Bad packet rc=%d\n", rc);

checks whether the packet we received is actually a valid CoAP packet.

    :c:
    else
    {
        size_t rsplen = sizeof(buf);
        coap_packet_t rsppkt;
        printf("content:\n");
        coap_dumpPacket(&pkt);
        coap_handle_req(&scratch_buf, &pkt, &rsppkt);

After the packet passes this test, it is passed to ``coap_handle_req()``. If the method and path of the request match one of the method-path combinations we specified in ``endpoints[]`` earlier on, the ``coap_endpoint_func handler`` provided along with them will be called automagically.

And that's it! We've now successfully received and processed a CoAP request.


### ``join``: change channels

**Goal:** Create ``join <channel name>`` command that changes the second segment of our resource path. Send chat messages to resources other than ``chat/default``
{: .alert .alert-info }  

Many chat applications have topic-specific channels. Our chat application can do this too: Up until now, we've all been sending our messages to ``chat/default/``. But when we change the resource to, say, ``chat/IoT/``, we can create a new channel on the fly (to discuss all things IoT, for example).

<!--- TODO: write *one* handler that outputs chat messages and a shell command that adds a new entry to endpoints[] that calls this handler for your new endpoint-->

<!--
## Tips

### If the board crashes, it will not tell you.
-->


