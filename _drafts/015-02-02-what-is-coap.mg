---
layout: post

title: One does not fit all
subtitle: "What is CoAP?"
cover_image: blog-cover.jpg

author: lotte

date: 2015-01-23
---

<!-- 
Ich würd gern ne kleine Einführung zu CoAP haben, auf die wir dann bei CoAP-HOWTOs verweisen könenn.. daher diese Datei. 
-->


In order to transfer data in the Internet of Plants, nodes need to know the type of interaction and its exact target: Did my neighbor just ask me for a specific information, or did they send unsolicited information? If so, which resource is this information about? Etc etc.

Now, we could have defined our own way of communicating this. We could have specified suitable JSONs of some sort, put them into protocol buffers and prayed that thy wouldn't exceed the 81 bytes of payload the teeny-tiny [MTU](http://en.wikipedia.org/wiki/Maximum_transmission_unit) of IEEE 802.15.4
 left us. We would probably have been in for a world of pain.

Enter the [Constrained Application Protocol (CoAP)](http://coap.technology). It operates on the Application Layer and does exactly what we need. It was designed to be a lightweight alternative to HTTP