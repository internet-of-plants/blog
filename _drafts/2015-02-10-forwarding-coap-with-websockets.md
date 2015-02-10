---
layout: post
title: Forwarding CoAP messages with WebSockets
author: lucas
---

In (TODO link to previous californium post) we created a Play application that receives CoAP messages with the help of Eclipse Californium. Now that we are receiving CoAP messages inside of the Play framework actor system, we will explore one option to forward the information to the user, i.e. the browser that visits the Play-based website: the usage of WebSockets. For the Watr.li dashboard, we are going to use WebSockets to send "realtime" content updates to the browser whenever new humidity data is received from the {% postlink 2015-01-13-introduction plant nodes %} via CoAP.


# What are WebSockets?

In the traditional client-server model between a web browser and a web server, the server has no possiblity to send data to the client proactively. WebSockets aim to solve this problem by providing full-duplex, persistent connections from the web browser to the web server, discarding the need for updating websites through AJAX polling.



# Forwarding our CoAP payload through WebSockets

To establish WebSocket connections within Play we need to create an actor that will act as a middleman between the Play application and the browser, much like our Californium actor does between Play and the CoAP server. We will call this actor the WebSocket actor (quite imaginative!). What we want to achieve is the following: whenever a CoAP message is received, it is forwarded to all users (i.e. browsers) who are currently visiting the site, each of which has a corresponding instance of the WebSocket actor. 

In order to achieve that, our Californium server actor (CSA) has to know about all of these WebSocket actors such that it can forward the CoAP messages. We implement this by applying a variant of the observer pattern: the WebSocket actor (WSA) knows about the CSA because it can retrieve the reference through the `Global.getCaliforniumActor` method. So on creation of the WSA it can send a message to the CSA requesting that all CoAP messages should be forwarded to it. We called this message [`SendMeCoapMessages`](https://github.com/watr-li/play-californium/blob/master/app/actors/messages/SendMeCoapMessages.java) and it carries no extra data.

After the WSA has registered itself with the CSA, all subsequently recieved CoAP messages are forwarded to the registered WSAs. We even made a sequence diagram to illustrate the process!

![](images/play2-californium/sequence-diagram.png)

## Extending the Californium Server Actor

To implement this we first need to make our CSA react to the `SendMeCoapMessages` message by extending our `onReceive` method to look something like this:

    :java:
    // A list of actors that have
    // registered themselves to receive CoAP messages
    // Needs to be initialized in the constructor!
    private List<ActorRef> coapRecipients;

    public void onReceive(Object message) throws Exception {
      if(message instanceof ShutdownActor) {
        [...]
      } else if(message instanceof SendMeCoapMessages) {
        log.info("Adding actor to coap recipient list: {}", getSender());
        coapRecipients.add(getSender());

      } else if(message instanceof CoapMessageReceived) {
        // Forward received CoAP messages (from CaliforniumServer)
        // to all registered actors
        for(ActorRef actor : coapRecipients) {
            actor.tell(message, getSelf());
        }
      } 
      [...]
    }
{: .wide }

This handles `SendMeCoapMessages` by adding the sender of the message (our WSAs) to a list of `coapRecipients`. We then use this list in the block that handles the `CoapMessageReceived` messages by simply forwarding them to all actors in the recipient list.


## Implementing the WebSocket Actor

This part is mostly adopted from the [Play documentation](https://www.playframework.com/documentation/2.3.0/JavaWebSockets) as our WSA is not very fancy in its current state. We create an UntypedActor once again, this time with an actor reference that allows us to communicate with the browser ([full source](https://github.com/watr-li/play-californium/blob/master/app/actors/WebSocketActor.java)).

    :java:
    package actors;
    [...]
    public class WebSocketActor extends UntypedActor {
      LoggingAdapter log = Logging.getLogger(
        getContext().system(), this);

      // The actor that acts as proxy for the browser's
      // Web Socket. This is automatically created by Play
      private final ActorRef browser;
      [...]
    }

A static helper method allows us to create the required `Props` instance. `akka.actor.Props` are entities that carry the configuration for the creation of an actor.

    :java:
    public static Props props(ActorRef browser) {
      return Props.create(WebSocketActor.class, browser);
    }

This helper method is used when our WSA is created, which is explained in the upcoming section. The constructor then stores the reference to the browser and notifies the CSA that it would like to be sent CoAP messages:

    :java:
    public MyWebSocketActor(ActorRef browser) {
      this.browser = browser;
      global.Global.getCaliforniumActor().tell(
        new SendMeCoapMessages(), getSelf());
    }

Lastly we implement the `onReceive` method which simply forwards the payload of incoming `CoapMessageReceived` messages to the browser:

    :java:
    public void onReceive(Object message) throws Exception {
      if(message instanceof CoapMessageReceived) {
        CoapMessageReceived msg =
          (CoapMessageReceived) message;
        browser.tell(
          "Received via CoAP: " + msg.getMessage(),
          getSelf());

      } else {
        unhandled(message);
      }
    }


## Creating the WebSocket actor

Our WSA needs to be created when a new WebSocket connection is established. For this to work we need to create a route at which we can point our WebSocket from the client side, for example:

    ws://localhost:9000/coapWebsocket

To define this route we open the `conf/routes` file and add the following line:

    GET    /coapWebsocket    controllers.Application.websocketHandler()
{: .wide }


This instructs Play to forward HTTP GET requests to the `/coapWebsocket` URI to the `websocketHandler` method inside the application controller, which we will implement like this ([full source](https://github.com/watr-li/play-californium/blob/master/app/actors/WebSocketActor.java)):

    :java:
    public static WebSocket<String> websocketHandler() {
      return WebSocket.withActor(new Function<ActorRef, Props>() {
        public Props apply(ActorRef browser) throws Throwable {
          return WebSocketActor.props(browser);
        }
      });
    }
{: .wide }

TODO: explain

## Establishing the WebSocket connection

Lastly we need to establish a WebSocket connection from the browser to the Play application. We can do this by adding the following JavaScript to the `public/javascripts/hello.js` file, which should already exist within your application:

    :javascript:
    var ws = new WebSocket(
      "ws://" + window.location.host + "/websocket");

    ws.onmessage = function(message) {
      console.log(message);
      document.write("<p>" + message.data + "</p>");
    };


# Testing the setup with Eclipse Copper

Now that we've set everything up we might want to see if it actually works. An easy way to test our CoAP example resource TODO


