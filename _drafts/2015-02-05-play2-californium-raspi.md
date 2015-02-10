---
layout: post
title: Raspi/Californium/Play2
author: lucas
---

On our Raspberry Pi web interface we want to display the data from all our plant nodes in "realtime" (whatever that even means for websites). In this post we will be introducing our technology stack that will be running on the Raspberry Pi and explain step by step how all the piece fit and can be made to work together. 

<!-- more -->

![](images/play2-californium/architecture.png)

The graphic shows an abstract overview of our setup. On the bottom left we have one of our plant nodes which communicates with the [Eclipse Californium](https://www.eclipse.org/californium/) Server (TODO why cf?) via the CoAP protocol. To develop the web interface we have chosen the [Play framework](https://playframework.com/) (TODO why?). The communication between the Californium Server and the web application is established through an [Akka](http://akka.io/) Actor, which is the conventional solution for asynchronous communication within Play. Lastly, the user's browser communicates with the Play application server using HTTP as well as the WebSocket protocol for "realtime" updates. Communication between actors is highlighted in red. No protocol is mentioned because no serialization of the messages is necessary, since the subsystems operate inside the same Java Virtual Machine, thus making it possible to simply pass Java objects around.




# Creating a Play application

In order to create a new Play application, Java has to be installed on your system. Please follow the guide on [playframework.com](https://playframework.com/documentation/2.3.x/Installing) on how to install the Play framework itself. After the installation you're ready to create a new Play app. Since this article does not intend to be an introduction to the Play framework, only the necessary steps are shown here. For more details check out the framework's [getting started guide](https://playframework.com/documentation/2.3.x/Home).

**Note:** While Play offers the option for development in Scala, this blopost relies entirely on an implementation written in Java, in the the hope that a Java implementation reaches a wider audience. Most parts should be easily interchangeable with Scala code, however.
{: .alert .alert-info }

To create a new Play application based on the Java template, run the following in your console after installing Play:

    activator new play-californium play-java

This will create a new directory `play-californium` in the current directory, to which we can switch an execute `./activator run`. This will start a webserver at port 9000, so navigating to `http://localhost:9000` should display the Play welcome message. 

**Note:** Play automatically detects changes in the project directory after each request to the webserver, so it is not necessary to restart it after source code changes.
{: .alert .alert-info }


# Adding Eclipse Californium

Now that we have a very basic Play application set up we want to add Californium as a dependency. To do this, we include the following line in the `build.sbt` file within the project's root directory:

    libraryDependencies += "org.eclipse.californium" % "californium-core" % "1.0.0-M3" 

**Note:** The above statement has to be surrounded by newlines or an error will be thrown. This is a convention of the Scala Build Tool (SBT) which is used by Play.
{: .alert .alert-warning }

After adding said line and re-running `./activator`, the dependency should now be included in the project. If 1.0.0-M3 should not be the [current release](https://oss.sonatype.org/#nexus-search;gav~org.eclipse.californium~californium-core~~~) of `californium-core` then you will have to update the last segment of the above dependency to match the current version designation.


# Starting a Californium Server

Background jobs in Play are executed through so-called "Actors", which are lightweight concurrent entities which process messages asynchronously ([docs.akka.io](http://doc.akka.io/docs/akka/snapshot/general/actor-systems.html#actor-systems) provides a much more detailed explanation). We will use such an actor to handle creation and graceful shutdown of our Californium CoAP server. Additionally it will handle communication between the CoAP server and the rest of the Play application.

## The Californium Server Actor

Actors in Play (which uses the Akka framework) have a single abstract method `void receive(Object message)` that needs to be implemented and is invoked whenever the actor receives a message. The following code is shortened for better readability of the article. Please refer to [GitHub](https://github.com/watr-li/play-californium/blob/master/app/actors/CaliforniumServerActor.java) for the full source:

    :java:
    package actors;
    [...]
    public class CaliforniumServerActor extends UntypedActor {
      LoggingAdapter log = Logging.getLogger(getContext().system(), this);
      CaliforniumServer server;
      [...]
    }

There are several types of actors, but we will be working with the simplest, the `UntypedActor`. The `server` variable will hold a reference to the instantiated Californium server, which is initialized in the constructor. The implementation of said server is presented in the next section.

    :java:
    public CaliforniumServerActor() {
      super();
      server = CaliforniumServer.initialize(getSelf());
    }

Here we pass a reference to the actor, obtained by calling `getSelf` and of type `ActorRef`, as a parameter to the Californium initialization routine. We do this so that the Californium server will be able to send messages to the Californium actor and thus to the Play application.

Now that the server is initialized, only the `onReceive` method remains to be implemented. This method defines which types of messages an actor can react to. The message is passed as an `Object` parameter, so it is possible to simply send strings as messages to the actor. It is preferable to send Java objects though, since these can be extended with additional data attributes when necessary. For example, for our server actor we will implement two messages, `CoapMessageReceived` and `ShutdownActor`. These messages are simple Java objects which store data to be transmitted in the message. The implementation for our two messages looks like this:

    :java:
    // app/actors/messages/CoapMessageReceived.java
    package actors.messages;
    public class CoapMessageReceived {
      private String message;
    
      public CoapMessageReceived(String message) {
        this.message = message;
      } 

      public String getMessage() {
        return message;
      }
    }

    // app/actors/messages/ShutdownActor.java
    package actors.messages;
    public class ShutdownActor {}

In our `onReceive` method we can now check which type of message we have received using `instanceof`. If the received message contains actual data we can then cast it to the correct type and call the defined getter methods, like so:
    
    :java:
    public void onReceive(Object message) throws Exception {

      if(message instanceof CoapMessageReceived) {
        CoapMessageReceived msg = (CoapMessageReceived) message;
        log.info("Received a message via CoAP: {}", msg.getMessage());

      } else if(message instanceof ShutdownActor) {
        log.info("Graceful shutdown");
        server.stop();
        getSelf().tell(akka.actor.PoisonPill.getInstance(), getSelf());

      } else {
        log.info("Unhandled message: {}", message);
        unhandled(message);
      }
    }
{: .wide }

One thing to note is the `ShutdownActor` case. In it, we first call `server.stop()` to shutdown the Californium server. In the following line we send a `PoisonPill` message to the current actor. This is a message provided by the Akka actor framework which instructs the actor to process all messages remaining in its inbox and then shut itself down.



## Starting the actor 

Now that we've created our actor we need to initialize it when the Play application starts. This is done by defining a [Global object](https://www.playframework.com/documentation/2.3.x/ScalaGlobal) which handles global settings and startup routines in Play. For that, we create a `Global.java` inside the `app/global/` directory (which we have to create), adding the following content:

    :java:
    package global;
    [...]
    public class Global extends GlobalSettings {

        private static ActorRef californiumActor;

        public void onStart(Application app) {
          californiumActor = Akka.system().actorOf(
            Props.create(CaliforniumServerActor.class)
          );
        }

        public void onStop(Application app) {
          californiumActor.tell(new ShutdownActor(), null);
        }

        public static ActorRef getCaliforniumActor() {
          return californiumActor;
        }
    }
{: .wide }

In the `onStart` method we create an instance of our Californium Server Actor and store the reference for later access. In `onStop` we send it a `ShutdownActor` message to gracefully shutdown the Californium server as well as itself. For a more in-depth explanation of how the Play integration of Akka works please refer to the [Play documentation](https://www.playframework.com/documentation/2.3.x/JavaAkka).

Normally Play expects the Global object to reside inside the `app/` directory. Unfortuntately Java does not allow access to classes in the root namespace from other packages, which we will need later in order to obtain a reference to the server actor through the `getCaliforniumActor` getter. To work around this limitation we have to put the Global object in the `global` package (any name works though) and tell Play where to find it. We do this by adding the following line to the `conf/application.conf`:

    application.global=global.Global


# Example Californium Server

For this guide we have slightly modified the official [Californium Hello World Server](https://github.com/eclipse/californium/blob/master/cf-helloworld-server/src/main/java/org/eclipse/californium/examples/HelloWorldServer.java). The following section highlights our modifications. For the full class please refer to [GitHub](https://github.com/watr-li/play-californium/blob/master/app/californium/CaliforniumServer.java).

Just as in the Hello World example, our server class inherits from `CoapServer`:

    :java:
    // app/californium/CaliforniumServer.java
    public class CaliforniumServer extends CoapServer {
        ActorRef serverActor;
        [...]
    }

Instead of a static `main(String[] args)` method we use a static method that initializes the server, passing a reference to our server actor from the previous section, and returning the resulting instance:

    :java:
    public static CaliforniumServer initialize(ActorRef serverActor) {
      CaliforniumServer server = null;
      try {
        server = new CaliforniumServer(serverActor);
        server.start();
      } catch (SocketException e) {
        logger.error("Failed to initialize server: " + e.getMessage());
      }
      return server;
    }
{: .wide }

Then comes the constructor which registers our example CoAP resource and stores the reference to the server actor so that we can later send messages to it:
        
    :java:
    public CaliforniumServer(ActorRef serverActor)
      throws SocketException {

      this.serverActor = serverActor;
      add(new HelloWorldResource());
    }
{: .wide }

Lastly we define said resource as an inner class of the `CaliforniumServer`. The constructor of the `CoapResource` takes the resource name as a parameter, which in this case is `helloWorld`.

In order to send messages to the resource we still need to define a handler for one of the CoAP methods (GET, POST, PUT and DELETE). We don't use GET (as the Californium HelloWorld example does) because it cannot have a payload.

    :java:
    class HelloWorldResource extends CoapResource {

      public HelloWorldResource() {
        super("helloWorld");
        getAttributes().setTitle("Hello-World Resource");
      }

      public void handlePUT(CoapExchange exchange) {
        serverActor.tell(
          new CoapMessageReceived(exchange.getRequestText()), null);
        exchange.respond(ResponseCode.CHANGED);
      }
    }
{: .wide }

In the `handlePUT` method we notify the server actor that a message has been received through a `CoapMessageReceived` instance containing the message's paylod. The second parameter of `tell` is the sending actor. Since we're not in an actor context and do not need to receive a response from the actor, we can simply pass null. Lastly we respond with the `CHANGED` response code which indicates that the request was successful but did not result in the creation of a new resource. 


# Bonus: Forwarding CoAP through WebSockets

Now that we are receiving CoAP messages inside of the Play framework actor system, we can explore one way to forward them to the user, i.e. the browser that visits the Play-based website. For the Watr.li dashboard, we are going to use WebSockets to send updates to the browser through a persistent connection to the server, so this section explains the usage of WebSockets.

To establish WebSocket connections within Play we need to create an actor that will act as a middleman between the Play application and the browser, much like our Californium actor does between Play and the CoAP server. We will call this actor the WebSocket actor (quite imaginative!). What we want to achieve is the following: whenever a CoAP message is received, it is forwarded to all users (i.e. browsers) who are currently visiting the site, each of which has a corresponding instance of the WebSocket actor. 

In order to achieve that, our Californium server actor (CSA) has to know about all of these WebSocket actors such that it can forward the CoAP messages. We implement this by applying a variant of the observer pattern: the WebSocket actor (WSA) knows about the CSA because it can retrieve the reference through the `Global.getCaliforniumActor` method. So on creation of the WSA it can send a message to the CSA requesting that all CoAP messages should be forwarded to it. We called this message [`SendMeCoapMessages`](https://github.com/watr-li/play-californium/blob/master/app/actors/messages/SendMeCoapMessages.java) and it carries no extra data.

After the WSA has registered itself with the CSA, all subsequently recieved CoAP messages are forwarded to the registered WSAs. We even made a sequence diagram to illustrate the process!

![](images/play2-californium/sequence-diagram.png)

## Extending the Californium Server Actor

To do this we first need to make our CSA react to the `SendMeCoapMessages` message by extending our `onReceive` method to look something like this:

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

    GET    /coapWebsocket    controllers.Application.coapWebsocketHandler()

This instructs Play to forward HTTP GET requests to the `/coapWebsocket` URI to the `coapWebsocketHandler` method inside the application controller, which we will implement like this ([full source](https://github.com/watr-li/play-californium/blob/master/app/actors/WebSocketActor.java)):

    :java:
    public static WebSocket<String> coapWebsocketHandler() {
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









# Misc 

* The raspberry serves both as coap client/server as well as webserver for the watr-li management dashboard (manages nodes)
* Dashboard (play app) is started, which then starts the coap client/server
* background job is an actor started in the play's object Global 
* deploying application to the raspi: `./activator stage` then rsync to raspi and start with low memory settings
* sqlite because easy and low memory footprint

TODO: connect the stuff to usb0
TODO: how to test web-interface locally

In build.sbt before building add (if openjdk7 is used and you have Java 8):

    javacOptions ++= Seq("-source", "1.7", "-target", "1.7")

First

    ./activator stage # on the build system

Then rsync `target/universe/stage` to raspi. Then run

    JAVA_OPTS="-Xmx64M -Xms16M -XX:PermSize=24M -XX:MaxPermSize=64M" ../bin/iop-dashboard

Woohooo!











# Deploying (to the Raspi)

Mention 

    javacOptions ++= Seq("-source", "1.7", "-target", "1.7")
{: .wide }
