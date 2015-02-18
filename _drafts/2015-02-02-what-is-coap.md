---
layout: post

title: Sending <i>small</i> packets
subtitle: "The non RFC-writers guide to CoAP"
cover_image: blog-cover.jpg

authors:
    - lotte
    - lucas

date: 2015-01-23
---

In order to transfer data in the Internet of Plants, nodes need to know the type of interaction and its exact target: Did my neighbor just ask me for a specific information, or did they send unsolicited information? If so, which resource is this query or information about? Etc etc.

We could have defined our own way of communicating this. We could have specified suitable JSONs of some sort, put them into protocol buffers and prayed that they wouldn't exceed the 81 bytes of payload the teeny-tiny [MTU](http://en.wikipedia.org/wiki/Maximum_transmission_unit) of IEEE 802.15.4 left us. We would probably have entered a world of pain.

Luckily, there is a better way of doing this: the [Constrained Application Protocol (CoAP)](http://coap.technology). It operates on the Application Layer and was designed to be a lightweight complement to HTTP. Because of this coupling, CoAP requests can be translated to HTTP requests and a subset of HTTP requests can be translated to CoAP. This is great for nodes that act as border routers (like our *display node*) and translate between IoT environments and the “big” internet.



# Endpoints and Resources

All entities participating in the CoAP protocol are called "endpoints". For our use case, these participants are the client and the server. 

**Note:** Other participants include intermediaries such as proxies which are not discussed here.
{: .alert .alert-info }

Each endpoint is uniquely identified by a the triplet `(IP, Port, Transport Layer Security)`, the latter two being optional. Every type of information a CoAP endpoint has to offer is called a *resource*. These resources are identified by a Unique Resource Identifier (URI), which resembles (but is completely unrelated to) a filesystem path. With endpoint information included, a CoAP URI might look something like this:

    coap://[fe80::c2ff:febc:139c]:1234/example/resource

# Request methods

When interacting with a CoAP resource, one of four "request methods" must be specified. The request method identifies the intent with which a resource is being accessed and each method has some inherent properties:

**Note:** A CoAP request is idempotent if you can invoke a request multiple times with the same effect. A request is safe if it does not change any state on the server.
{: .alert .alert-info }

<table class="table table-condensed wide">
    <thead>
        <tr>
            <th>Method</th>
            <th>Semantics</th>
            <th>Safe</th>
            <th>Idempotent</th>
            <th>Payload</th>
            <th>Return&nbsp;Codes</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>GET</td>
            <td><small>Retrieve the current state of a resource identified by the accessed URI.</small></td>
            <td class="text-center">✓</td>
            <td class="text-center">✓</td>
            <td class="text-center">𝗫</td>
            <td><small>2.03&nbsp;Valid, 2.05&nbsp;Content</small></td>
        </tr>
        <tr>
            <td>POST</td>
            <td><small>A generic indicator for the recipient that the enclosed message should be pro&shy;cessed, usually resulting in the creation of a new re&shy;source or the update of the target resource.</small></td>
            <td class="text-center">𝗫</td>
            <td class="text-center">𝗫</td>
            <td class="text-center">✓</td>
            <td><small>2.01&nbsp;Created, 2.02&nbsp;Deleted, 2.04&nbsp;Changed</small></td>
            
        </tr>
        <tr>
            <td>PUT</td>
            <td><small>Indicates that the target resource should be created or updated.</small></td>
            <td class="text-center">𝗫</td>
            <td class="text-center">𝗫</td>
            <td class="text-center">✓</td>
            <td><small>2.01&nbsp;Created, 2.04&nbsp;Changed</small></td>
        </tr>
        <tr>
            <td>DELETE</td>
            <td><small>Requests that the target resource should be deleted.</small></td>

            <td class="text-center">𝗫</td>
            <td class="text-center">✓</td>
            <td class="text-center">𝗫</td>
            <td><small>2.02&nbsp;Deleted</small></td>
            
        </tr>
    </tbody>
</table>

---

# Example

Let's say we have a CoAP client C and a CoAP server S. Suppose node C wanted to know about the humidity status of the plant node S is watching over. S has the IP `fe80::42` and runs a CoAP server which is listening on port `1234`.  

To retrieve the desired information, C may send the following request (request parameters are specified in `Parameter: Value`):

    GET coap://[fe80::42]:1234/plant/humidity
    Accept: 0

The `Accept` option indicates the desired response format. The value `0` stands for `text/plain` within the CoAP Content-Formats Registry ([see RFC7252 12.3.][rfc-12-3]).

S then answers with a `2.05 Content` response, which is similar to HTTP's `200 OK`, and the requested value the response's payload.

<!-- add picture -->

# Implementations

Some implementations of the CoAP protocol can be found at [http://coap.technology/impls.html](http://coap.technology/impls.html).

For watr.li, we chose to use Californium to handle all things CoAP on our Display nodes, since it provides a nicely architected high-level abstraction over the CoAP protocol, which is exactly what we desired for our relatively powerful display node running a Raspberry Pi (in comparison to the SAM R21 based plant nodes). Since Californium runs inside of the JVM it also integrates nicely with the [Play framework][play-framework] which we chose to implement our web interface.

On our plant nodes, we had the choice between [microcoap](https://github.com/1248/microcoap) and [libcoap](http://libcoap.sourceforge.net), as RIOT features both as an [external package](https://github.com/RIOT-OS/RIOT/tree/master/pkg). libcoap is a more monolithic effort which not only sets the CoAP headers and payload in place, but also takes care of dispatching them. microcoap, on the other hand, gives the user a blob of data which they can then dispatch however they see fit. This decreases complexity and removes the need for additional socket-handling threads. This is why we chose to use microcoap on our plant nodes. 

In our next series of posts, we will explain how to create, send and answer CoAP requests with both microcoap and Californium, so keep an eye out for updates!

[rfc-12-3]: https://tools.ietf.org/html/rfc7252#section-12.3
[play-framework]: https://www.playframework.com/
