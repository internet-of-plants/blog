# Workshop Setup

## prerequisites
This guide assumes that you are familiar with the basics of the following:

- using a linux terminal
- the C programming language

However, first and foremost, we're here to learn and help each other. You don't have to know all the things in order to be able to participate. If you're unsure about anything, or feel that you'd like some help, please do not hesitate to ask the RIOT team. We know that it may be a lot to grasp at once, and we're happy to answer all questions, no matter how trivial they may seem to someone.

## development environment
RIOT requires you to install and, in one case, even compile some dependencies. We've prepared a Virtual Machine which is all set up and ready to go. You can find it [here](http://TODO), along with a binary of a VMWare test version in case you might need it.  
username: **riot**  
password: **riot**

In case you prefer to set everyting up yourself, you can follow [this guide](http://watr.li/samr21-dev-setup-ubuntu.html) up until (but not including) the section “Building a RIOT example application”.

RIOT does have experimental Windows support. If you'd prefer to use Windows as your host system, you can consult [this guide](https://github.com/RIOT-OS/RIOT/wiki/Build-RIOT-on-Windows-OS), but it doesn't cover how to flash an application. However, a word of warning: you probably know much more about your Windows machine than we do, and we might not be able to help you in case you run into trouble.

### tip: ssh & sshfs for your VM
While our VM has a GUI, this can be annoyingly slow. Alternatively, you can use sshfs to mount your VM's home directory as if it were a regular directory on your host system:

	sshfs riot@ip.of.your.vm:/home/riot some_directory/

(get your VM's IP by launching the Terminal application and entering ``ifconfig eth0``)

You can then ssh onto your VM and run all make, flash etc commands from your host system's terminal:

	ssh riot@ip.of.your.vm:/home/riot

## Getting started with RIOT
Now that you're well-prepared, let's get you started! The goal of this section is to show you how to build and flash a RIOT application. 

### Building a RIOT app

	TODO: fetch (special) RIOT repo
	TODO: fetch base app
	cd TODO
	make

### Running it in native mode
You can run and test an application on your own computer with the ``native`` mode. The network is emulated through tun/tap devices which are connected through a tapbridge. This bridge has to be created beforehand:

	RIOT/cpu/native/tapsetup.sh create
	
Now you can start your RIOT application. When doing so, you'll need to specify which tap device it should listen on:

	sudo ./bin/native/TODO.elf tap0

In a new terminal, start another RIOT, this time listening on ``tap1``:

	sudo ./bin/native/TODO.elf tap1

Type help to see all commands available in the RIOT shell.
Use the ``say`` command in one RIOT shell to send a string to the other. If it arrives, you're ready to go!

### Flashing it to the SAMR21
Attach your SAMR21 board via microUSB and make 
You'll need two terminals for this: one for flashing and one to view the debug output.  

### Setting up the output terminal

In this terminal we start a [pyterm](http://pyterm.sourceforge.net/) instance, a serial port terminal emulator written in Python, listening to the output of the board:

    :bash:
    export BOARD=samr21-xpro &&
        make term

This should result in the following being printed, after which pyterm waits for output from the board:

    INFO # Connect to serial port /dev/ttyACM0
    Welcome to pyterm!
    Type '/exit' to exit.


### Running the flash command

Now we can switch to the other terminal window in which we will invoke the commands to flash the application onto the board:

    :bash:
    export BOARD=samr21-xpro &&
        make flash

The CMSIS-DAP interface for flashing and debugging [is quite slow](http://sourceforge.net/p/openocd/mailman/message/32496519/) (should be around 2KiB/s). So when flashing, you might need to wait a little longer. You can also apply an [OpenOCD patch](http://openocd.zylin.com/#/c/2356/) that increases flashing speed by 50-100%.
{: .alert .alert-warning }

`make flash` flashes and subsequently resets the board, causing the application to run. For our hello world example it should result in the following output being shown in the terminal window in which `make term` was executed:

    INFO # kernel_init(): This is RIOT! (Version: 2014.12-285-gfe295)
    INFO # kernel_init(): jumping into first task...
    INFO # Hello World!
    INFO # You are running RIOT on a(n) samr21-xpro board.
    INFO # This board features a(n) samd21 MCU.
{: .wide }

## adding your own code

Now that you're familiar with RIOT, it's time to add your own code. At the end of this tutorial, you'll have built a distributed chat application which lets you communicate with the other workshop participants. All chat messages will be sent over CoAP, and the resource the CoAP messages are targeting determines the chat channel you're in.

### ``nick``: add your own shell command
**Goal:** Create a shell command ``nick <nickname>`` which lets you set your nickname. {: .alert .alert-info }

RIOT has a rudimentary shell implementation which can be extended with your own commands. To do this, you'll have to extend the ``shell_commands[]`` array with your own ``shell_command_t``, which is defined as follows:

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

Re-build your application with ``make`` and try your new shell command by executing the binary:

	sudo ./bin/native/chat.elf tap0


### ``say``: send chat messages
**Goal:** Create a shell command ``say <message>`` which sends a chat message. The message should be in the payload of a CoAP PUT request directed at the resource ``chat/default/``. The message should be prepended with your nick. {: .alert .alert-info }

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

The payload of the PUT request is our chat message. In order to make it identifiable, make sure to prepend it with your nickname, like so:

	"my_nick: hello"

Once you've created your payload, you can use ``int coap_ext_build_PUT(uint8_t *buf, size_t *buflen, char *payload, coap_endpoint_path_t *path)`` to build your put request.  
Now, you can use ``chat_udp_send()`` to send the content of ``buf``.

(For the sake of simplicity, all messages are sent to the link-local all nodes multicast address by ``chat_udp_send()``.)

If you want to send messages wich contain spaces, the shell will recognize each word as a single argument, so you can have different values for ``argc`` and ``argv``. Bonus points for concatenating them!{: .alert .alert-info }

### receive messages
**Goal:** Receive CoAP chat messages, parse and output them.{: .alert .alert-info }

The base application contains a ``chat_udp_server_loop()`` which receives plain UDP mssages. However, our chat messages aren't plain text anymore, they're CoAP packets now. So instead of just printing the contents of ``buffer_main``, you'll need to handle these packets properly.

TODO shorten http://watr.li/microcoap-and-ff-copper.html and add 

### ``join``: change channels
**Goal:** Create ``join <channel name>`` command that changes the second segment of our resource path. Send chat messages to resources other than ``chat/default``{: .alert .alert-info }  

Many chat applications have topic-specific channels. Our chat application can do this too: Up until now, we've all been sending our messages to ``chat/default/``. But when we change the resource to, say, ``chat/IoT/``, we can create a new channel on the fly (to discuss all things IoT, for example).

- TODO: write *one* handler that outputs chat messages and a shell command that adds a new entry to endpoints[] that calls this handler for your new endpoint

## Tips

### If the board crashes, it will not tell you.

### gdb