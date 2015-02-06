---
layout: post
title: Raspi/Californium/Play2
author: lucas
---

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



# Setup

Uebersichtsbild in dem klar wird dass Californium mit Play2 auf dem Raspi laeuft und ueber CoAP mit den nodes redet.

Eventuell auch kurz warum wir californium/play2 benutzen.


# Creating a new Play application

* Play2 (activator) has to be installed first!
* This article does not intend to be an introduction to play 2 (link to [play2 getting started](https://playframework.com/documentation/2.3.x/Home))
* Rough steps to get Californium into Play2 and receive/send messages.
* We're going to use Java because it will be more familiar to a wider audience, but Play-scala should work just the same

.

    activator new play-californium play-java

This creates a new directory `play-californium` with a minimal Play2 template. You can start the application by running `./activator run`, which will create a site that is browseable through `http://localhost:9000`.


# Adding Eclipse Californium

To add Californium as a dependency to the Play application, we include the following in the `build.sbt` file in the project's root directory:

    libraryDependencies += "org.eclipse.californium" % "californium-core" % "1.0.0-M3" 

Note that the statement has to be surrounded by newlines. This is a convention of the Scala Build Tool (SBT) which is used by Play. After adding said line and re-running `./activator`, the dependency should now be included in the project.

If 1.0.0-M3 should not be the [current release](https://oss.sonatype.org/#nexus-search;gav~org.eclipse.californium~californium-core~~~) of `californium-core` then you will have to update the last segment of the above dependency to match the current version designation.




# Starting a Californium Server

Background jobs in Play are executed through so-called "Actors", which are lightweight concurrent entities which process messages asynchronously. We will use such an actor to handle creation and graceful shutdown of our Californium CoAP server. Additionally it will handle communication between the CoAP server and the Play application.

Actors in Play (which uses the Akka framework) have a single abstract method `void receive(Object message)` that needs to be implemented and is invoked whenever the actor receives a message. The following code is shortened for better readability of the article. Please refer to [GitHub](https://github.com/watr-li/play-californium/blob/master/app/californium/CaliforniumServerActor.java) for the full source. There are several types of actors, but we will be working with the simplest, the `UntypedActor`:

    :java:
    public class CaliforniumServerActor extends UntypedActor {
      CaliforniumServer server;
      [...]
    }

The `server` variable will hold a reference to the instantiated Californium server, which is initialized in the constructor. The implementation of said server is presented in the next section.

    :java:
    public CaliforniumServerActor() {
      super();
      server = CaliforniumServer.initialize(getSelf());
    }

We pass a reference to the actor (of type `ActorRef`) as a parameter to the server so that the Californium server will be able to send messages to the Play application. Now that the server is initialized, only the `onReceive` method remains to be implemented:
    
    :java:
    public void onReceive(Object message) throws Exception {
      TODO: Code
    }
{: .wide }

TODO: explain the receive stuff

Now that we've created our actor we need to initialize it when the Play application starts. This is done by defining a [Global object](https://www.playframework.com/documentation/2.3.x/ScalaGlobal) which handles global settings and startup routines in Play. For that, we create a `Global.java` inside the `app/` directory, adding the following content:

    :java:
    import play.*;
    public class Global extends GlobalSettings {

        private ActorRef californiumActor;

        public void onStart(Application app) {
          californiumActor = Akka.system().actorOf(
            Props.create(CaliforniumServerActor.class)
          );
        }

        public void onStop(Application app) {
          californiumActor.tell(new ShutdownActor(), null);
        }

        public ActorRef getCaliforniumActor() {
          return californiumActor;
        }
    }
{: .wide }

TODO: Explain the `ShutdownActor` thing.

To start the actor we need to define it first, though. 


# Example Californium Server

For this guide we have slightly modified the official [Californium Hello World Server](https://github.com/eclipse/californium/blob/master/cf-helloworld-server/src/main/java/org/eclipse/californium/examples/HelloWorldServer.java). The following section highlights our modifications. For the full class please refer to [GitHub](https://github.com/watr-li/play-californium/blob/master/app/californium/CaliforniumServer.java).

Just as in the Hello World example, our server class inherits from `CoapServer`:

    :java:
    public class CaliforniumServer extends CoapServer {
        ActorRef serverActor;
        [...]
    }

Instead of a static `main(String[] args)` method we use a static method that initializes the server, passing a reference to our server actor from the previous section, and returns the resulting instance:

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

Then comes the constructor which registers our example CoAP example resource:
        
    :java:
    public CaliforniumServer(ActorRef serverActor) throws SocketException {
      this.serverActor = serverActor;
      add(new HelloWorldResource());
    }
{: .wide }

Lastly we define said resource as an inner class of the `CaliforniumServer`. The constructor of the `CoapResource` takes the resource name as a parameter, which in this case is `helloWorld`. In order to send messages to the resource we still need to define a handler for one of the CoAP methods (GET, POST, PUT and DELETE). We don't use GET (as the Californium HelloWorld example does) because it cannot have a payload.

    :java:
    class HelloWorldResource extends CoapResource {

      public HelloWorldResource() {
        super("helloWorld");
        getAttributes().setTitle("Hello-World Resource");
      }

      public void handlePUT(CoapExchange exchange) {
        serverActor.tell("Received put message " 
          + exchange.getRequestText(), null);
        exchange.respond(ResponseCode.CHANGED);
        changed(); // notify all observers
      }
    }
{: .wide }

In the `handlePUT` method we notify the server actor that a message has been received and respond with the `CHANGED` response code which indicates that the request was successful but did not result in the creation of a new resource. TODO: Perhaps use POST?












# Deploying (to the Raspi)

Mention 

    javacOptions ++= Seq("-source", "1.7", "-target", "1.7")
{: .wide }
