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

## getting started with RIOT
Now that you're well-prepared, let's get you started! The goal of this section is to show you how to build and flash a RIOT application. 

TODO: 
- build app
- runin native (TODO: libc6-dev-i386 installed on VM?)
- flash App (which one?) 

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
**Goal:** Create a shell command ``send <message>`` which sends a chat message. The message should be in the payload of a CoAP PUT request directed at the resource ``chat/default/``.{: .alert .alert-info }

Now that you can set your nick name, let's send some chat messages!
Again, we'll need to add a ``send <message>`` command to the shell. 
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


Once you've set your path, you can use ``int coap_ext_build_PUT(uint8_t *buf, size_t *buflen, char *payload, coap_endpoint_path_t *path)`` to build your put request.  
Now, you can use ``chat_udp_send()`` to send the content of ``buf``.

(For the sake of simplicity, all messages are sent to the link-local all nodes multicast address by ``chat_udp_send()``.)

If you want to send messages wich contain spaces, the shell will recognize each word as a single argument, so you can have different values for ``argc`` and ``argv``. Bonus points for concatenating them!{: .alert .alert-info }

### receive msgs

### ``join``: change channels

- each channel is a different endpoint
- write *one* handler that outputs chat messages and a shell command that adds a new entry to endpoints[] that calls this handler for your new endpoint

## Tips

### If the board crashes, it will not tell you.

### gdb