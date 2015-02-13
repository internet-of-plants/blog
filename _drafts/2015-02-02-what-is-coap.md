---
layout: post

title: One does not fit all
subtitle: "The non RFC-writers guide to CoAP"
cover_image: blog-cover.jpg

author: lotte

date: 2015-01-23
---

<!-- 
Ich würd gern ne kleine Einführung zu CoAP haben, auf die wir dann bei CoAP-HOWTOs verweisen könenn.. daher diese Datei. 
-->


In order to transfer data in the Internet of Plants, nodes need to know the type of interaction and its exact target: Did my neighbor just ask me for a specific information, or did they send unsolicited information? If so, which resource is this query or information about? Etc etc.

We could have defined our own way of communicating this. We could have specified suitable JSONs of some sort, put them into protocol buffers and prayed that they wouldn't exceed the 81 bytes of payload the teeny-tiny [MTU](http://en.wikipedia.org/wiki/Maximum_transmission_unit) of IEEE 802.15.4 left us. We would probably have entered a world of pain.

Luckily, there is a better way of doing this: the [Constrained Application Protocol (CoAP)](http://coap.technology). It operates on the Application Layer and was designed to be a lightweight complement to HTTP. Because of this coupling, CoAP requests can be translated to HTTP requests and a subset of HTTP requests can be translated to CoAP. This is great for nodes that act as border routers (like our *display node*) and translate between IoT environments and the “big” internet.

## How it works
<!--picture of server & client?-->
CoAP relies on request/response pairs, just like HTTP. 

- stateless
- 


## Endpoints

## Basic request methods

CoAP supports ``PUT``, ``POST``, ``GET`` and ``DELETE`` as defined in HTTP:
All are idempotent (multiple calls will always yield the same result) except for ``POST``, and ``GET`` is safe (GETs will never change state on the server).

## Implementations

All implementations of the CoAP protocol can be found at [http://coap.technology/impls.html](http://coap.technology/impls.html).
It is usually assumed that IoT devices are able to do relatively few things on their own. This is why most CoAP libraries for embedded systems, such as microcoap for Arduino or libcoap for contiki (TODO: verify!) only offer the ability to create a CoAP server which can answer requests, but not a client or server which can initiate requests on its own. but with Embedded OSes getting more sophisticated and energy-savy, this may change soon.