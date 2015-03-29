---
layout: post
title: Workshop Guide
author: lotte
date: 2015-01-29
---

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

TODO: build & flash App (which one?)

## adding your own code

Now that you're familiar with RIOT, it's time to add your own code. 



### ``nick``: add shell command
nick command!

### ``say``: send chat msg

bonus: sting concat

### receive msgs

### ``join``: change channels

- each channel is a different endpoint
- write *one* handler that outputs chat messages and a shell command that adds a new entry to endpoints[] that calls this handler for your new endpoint

## Tips

### If the board crashes, it will not tell you.

### gdb
