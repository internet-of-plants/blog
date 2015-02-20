---
layout: post
title: Raspi/Californium/Play2
author: lucas
---

On our Raspberry Pi web interface we want to display the data from all our plant nodes in "realtime" (in double-quotes because, well, we're talking about websites). In this post we will be introducing our technology stack that will be running on the Raspberry Pi and explain step by step how all the piece fit and can be made to work together. 


<!-- more -->

![](images/play2-californium/architecture.png)

The graphic shows an abstract overview of our setup. On the bottom left we have one of our plant nodes which communicates with the [Eclipse Californium](https://www.eclipse.org/californium/) Server via the CoAP protocol, both of which have been introduced {% postlink 2015-02-18-what-is-coap here %}. To develop the web interface we have chosen the [Play framework](https://playframework.com/) because it runs inside the JVM and thus integrates well with Californium. The communication between the Californium Server and the web application is established through an [Akka](http://akka.io/) Actor, which is the conventional solution for asynchronous communication within Play. Lastly, the user's browser communicates with the Play application server using HTTP as well as the WebSocket protocol for "realtime" updates. Communication between actors is highlighted in red. No protocol is mentioned because no serialization of the messages is necessary, since the subsystems operate inside the same Java Virtual Machine, thus making it possible to simply pass Java objects around.




# Creating a Play application

In order to create a new Play application, Java has to be installed on your system. Please follow the guide on [playframework.com](https://playframework.com/documentation/2.3.x/Installing) on how to install the Play framework itself. After the installation you're ready to create a new Play app. Since this article does not intend to be an introduction to the Play framework, only the necessary steps are shown here. For more details check out the framework's [getting started guide](https://playframework.com/documentation/2.3.x/Home).

**Note:** While Play offers the option for development in Scala, this blopost relies entirely on an implementation written in Java, in the the hope that a Java implementation reaches a wider audience. Most parts should be easily interchangeable with Scala code, however.
{: .alert .alert-info }

To create a new Play application based on the Java template, run the following in your console after installing Play:

    activator new play-californium play-java

This will create a new directory `play-californium` in the current directory, to which we can switch and execute `./activator run`. This will start a webserver at port 9000, so navigating to `http://localhost:9000` should display the Play welcome message. 

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

In order to send messages to the resource we still need to define a handler for one of the CoAP methods (GET, POST, PUT and DELETE). We don't use GET (as the Californium HelloWorld example does) because {% postlink 2015-02-18-what-is-coap it cannot have a payload %}.

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



# Testing locally

Now let's test what we've built. In the Play project's root directory, launch `./activator run` (if it isn't still running) and navigate to `http://localhost:9000`. This will initialize the Californium server and the actors, thus allowing us to receive CoAP messages.

To test that functionality we'll be using [Eclipse Copper][eclipse-copper], a Firefox plugin that adds `coap://` URI support. After installing Copper and the server, we should be able to navigate to `coap://localhost:5683/` and see the following screen:

<img src="images/play2-californium/copper-screenshot.png">

We can see that Copper used the CoAP resouce discovery mechanism to list all the available resources that our server provides, which is just `helloWorld`. We can can proceed by clicking on that resource, entering something in the "Outgoing" textfield in the center of the screen and then click on the PUT icon at the top (we use the PUT method because that is how we have defined our resource handler). The expected result is that whatever you've entered into the "Outgoing" field now pops up in the console where you've started the Play application:

    [INFO] [02/20/2015 17:12:08] [...] Received CoAP message: 'Success!'
{: .wide .lol }



# Deploying the application to the Raspberry Pi

The last step we'll have to take is to get our application deployed to Raspberry. This is relatively simple if you've set it up according to our previous post, "{% postlink 2015-02-13-setting-up-a-border-router %}", because Java comes pre-installed on recent releases of Raspbian. 

To prepare our deployment we run `./activator stage`. This will bundle the application inside the `target/universal/stage` directory relative to the project's root. All we have to do then is rsync said directory to the Raspberry and run the application by changing into the `stage` directory on the Raspberry and running:

    :bash:
    JAVA_OPTS="-Xmx64M -Xms16M -XX:PermSize=24M -XX:MaxPermSize=64M" \
        ./bin/play-californium
{: .wide }

**Note:** If you're deploying to a device that has e.g. Java 7 installed, but you built the application with Java 8, running it on the target will fail. To circumvent this, add the following to your `build.sbt` if necessary: `javacOptions ++= Seq("-source", "1.7", "-target", "1.7")`. This sets the Java compiler's target version to Java 7.
{: .alert .alert-warning }

This starts the Play application, which might take quite a while to spin up since the Raspberry isn't the fastest of devices. The `JAVA_OPTS` that we're passing limits the amount of memory the JVM uses. If Play has started successfully, it will display the following messags:

    [info] play - Listening for HTTP on /0.0.0.0:9000

After that you should be able to test the Californium Server inside Play just as you've done locally, by entering the IP of your Raspberry into Firefox with the `coap://` protocol prefix.

An upcoming post will explain how to forward the CoAP messages to the user's browser through WebSockets and how to process CoAP messages and update a web interface in "realtime" based on the received data.




[eclipse-copper]: https://addons.mozilla.org/en-US/firefox/addon/copper-270430/
