---
layout: post
title: CoAP on RIOT
subtitle: implementing and testing with microcoap and copper
categories: CoAP
author: Lotte
date: 2015-02-10
---

In [one of our last posts](http://watr.li/what-is-coap.html), we explained how the [Constrained Application Protocol](http://coap.technology) enables us to exchange data between nodes in the Internet of Plants using a request/reply cycle similar to that of HTTP. 
To do this, we need both of our node types– plant nodes and display nodes– to be able to send, process and answer CoAP requests.

This post explains how to implement a simple CoAP server on our *plant nodes*, which run [RIOT](http://www.riot-os.org), using RIOTs [microcoap](https://github.com/1248/microcoap) package. 

Since no special modifications to the code are needed to get it to run on RIOT, this guide may also be useful to you if you're looking to run microcoap on linux or your Arduino.{: .alert .alert-info }

We'll also show you how to test your microcoap server with [Copper](https://addons.mozilla.org/de/firefox/addon/copper-270430/), using [marz](https://github.com/sgso/marz) to tunnel the requests to your RIOT instance.

## Implementing a simple microcoap server
This section will walk you through the implementation of a very simple microcoap server. In the end, you'll have a server which is able to answer ``GET`` requests to ``/foo/bar``, and (hopefully :) ) the knowledge how to extend this server at will. This guide is based on the code of [this example application](TODO add link as soon as it's in master). 

Please note that microcoap currently doesn't have a nice API to create requests on its own (i.e. without being triggered by a client). It can be done, though, but that's for another blog post.  {: .alert .alert-info }

### main.c
For an in-depth explanation of the structure of a RIOT application, please [see this RIOT wiki page](https://github.com/RIOT-OS/RIOT/wiki/Creating-your-first-RIOT-project){: .alert .alert-info }

### endpoints.c
As explained in our {% postlink 2015-02-18-what-is-coap previous post %}, a microcoap server answers requests which are directed at the *resource* of a certain *endpoint* (namely, the IP address of our server). Our server will thus have to define the resources which can be requested, and how to handle these requests.  

Probably a bit confusingly named, microcoap handles this with the help of an array called ``endpoints``.
This array should *not* contain information about any endpoints (i.e. IP and port pairs), but information about your resources.  
You will have to create a ``const coap_endpoint_t endpoints[]`` and fill it to match your desired endpoints and how they should be handled. Let's look at this step by step.

In ``endpoints.c``, you will find that the example application has created an array of ``coap_endpoint_t`` called ``endpoints``:

	:c:
	const coap_endpoint_t endpoints[] =
	{
    	{COAP_METHOD_GET, handle_get_response, &path, "ct=0"},
    	{(coap_method_t)0, NULL, NULL, NULL} /* marks the end of the endpoints array */
	};

Now, if we look at the ``coap.h`` file of [the microcoap code](https://github.com/1248/microcoap/blob/master/coap.h#L138), we can see that a ``coap_endpoint_t`` is defined as follows (comments added by me):

    :c:
    typedef struct
    {
        coap_method_t method;               /* (i.e. POST, PUT or GET) */
        coap_endpoint_func handler;         /* callback function which handles this 
                                             * type of endpoint (and calls 
                                             * coap_make_response() at some point) */
        const coap_endpoint_path_t *path;   /* path towards a resource (i.e. foo/bar/) */ 
        const char *core_attr;              /* the 'ct' attribute, as defined in RFC7252, section 7.2.1.:
                                             * "The Content-Format code "ct" attribute 
                                             * provides a hint about the 
                                             * Content-Formats this resource returns." 
                                             * (Section 12.3. lists possible ct values.) */
    } coap_endpoint_t;

This helps us understand the first entry of our ``endpoints[]``.  

- ``COAP_METHOD_GET`` specifies that this entry describes how to handle a ``GET`` request.
- ``handle_get_response`` is the function which should be called in case a suitable request has been received.
- ``&path`` is a pointer towards the path that specifies the resource which is handled by this entry. ``path`` is defined as  
		
		static const coap_endpoint_path_t path = {2, {"foo", "bar"}};		
a few lines up, so we know that this entry handles a path which contains two segments, namely ``/foo/bar``.

microcoap supports a maximum segment number of two out f the box. If you need more, you'll have to adjust ``MAX_SEGMENTS`` in ``coap.h``.{: .alert .alert-warning }

- ``"ct=0"`` Specifies the Content-Format, which is a hint on how to interpret the payload of the packet (if any). In this case, the content format is 0, which stands for ``text/plain``
 A list of possible Content-Format types can be found in [section 12.3 of the CoAP RFC](https://tools.ietf.org/html/rfc7252#section-12.3).

If our CoAP server receives a request which matches this definition, i.e. a ``GET`` request to ``/foo/bar/`` with the Content-Format set to ``0=text/plain``, the ``handle_get_response()`` function will be called, which handles the processing of this request and the creation of a response, if necessary. Let's look at this function in detail:

	:c:
	void create_response_payload(const uint8_t *buffer)
    {
        char *response = "1337";
        memcpy((void*)buffer, response, strlen(response));
    }

    /* The handler which handles the path /foo/bar */
    static int handle_get_response(coap_rw_buffer_t *scratch, const coap_packet_t *inpkt, coap_packet_t *outpkt, uint8_t id_hi, uint8_t id_lo)
    {
        DEBUG("[endpoints]  %s()\n",  __func__);
        create_response_payload(response);
        /* NOTE: COAP_RSPCODE_CONTENT only works in a packet answering a GET. */
        return coap_make_response(scratch, outpkt, response, strlen((char*)response),
                                  id_hi, id_lo, &inpkt->tok, COAP_RSPCODE_CONTENT, COAP_CONTENTTYPE_TEXT_PLAIN);
    }

Whenever a callback function that is defined in an ``coap_endpoint_t`` is called, it is provided with parameters.

- ``coap_rw_buffer_t *scratch`` TODO
- ``const coap_packet_t *inpkt`` A pointer to the packet which caused this callback to be called. This way, the callback function can examine its content and determine how it should react. 
- ``coap_packet_t *outpkt`` Is a pointer to the buffer into which a repsonse packet can be written. 
- ``uint8_t id_hi`` TODO
- ``uint8_t id_lo`` TODO

Because ``handle_get_response()`` handles a ``GET`` request, we want our ``handle_get_response()`` to react with a response. So we've whipped up a little function called ``create_response_payload()``, which creates the payload of our response. Then, we use ``coap_make_response()`` to TODO

As you can see, ``create_response_payload()`` is as simple as it gets in this example. In a real application, however, this might be where you'll read out sensor data which has been requested.

Note that microcoap will recognize the endpoints array by its name. This will **not** work if your array is called anything but ``endpoints``!{: .alert .alert-warning }

### The Makefile
Note: this part is only relevant if you use RIOT. {: .alert .alert-info }

Even though [the RIOT wiki](https://github.com/RIOT-OS/RIOT/wiki/Creating-your-first-RIOT-project) has a more in-depth explanation of RIOT Makefiles, there is one thing that you shouldn't overlook:  
Each RIOT Makefile specifies the board the application should be built for using the ``BOARD`` parameter. [In the example Makefile](TODO), you'll find the following line:

	BOARD ?= native

This means that your application will be built as a *native* applications. the application and the RIOT instance it is running on will run inside a thread on your Linux OS, which is great for testing and debugging. Once you're ready to flash your code to your actual board, substitute ``native`` with the name of your board (in our case ``smar21-xpro``) and [flash it](http://watr.li/samr21-dev-setup-ubuntu.html).

## Testing your microcoap server
Now that our microcoap server is up and running, we'll want to feed it requests and see if it behaves as expected. This section will guide you through the setup of a simple environment which lets you do this. (Despite the somewhat misleading terminology, this section is *not* about thorough, automated tests.)

### Setting up a test client
If you already have a CoAP client which you can use to send requests, that's great. In case you don't, there are two quick and easy solutions to this:
#### FF Copper
[Copper](https://addons.mozilla.org/de/firefox/addon/copper-270430/) is here to help: Simply install the plugin in your Firefox browser and enter 

	coap://<your microcoap server IP>:5683

into the browser. ( 5683 is the standard microcoap port.) Your browser window should show the following:

TODO insert image

If your microcoap server has an IPv6 address, you will have to put the address into square brackets{: .alert .alert-info }

### marz: feeding RIOT traffic from the outside
Note: this part is only relevant if you use RIOT. {: .alert .alert-info }
<!-- TODO: what about 6lowpan? -->

Because instances of RIOT's native port are just Linux threads, they lack a real, physical network. Native emulates this missing network through the use of tapbridges. This means that every RIOT native thread is attached to a tap device, which it assumes to be the network device through which all network traffic is sent and received. In order to get the CoAP requests we're sending with Copper through to our RIOT instance, we'll have to tunnel them into RIOT's emulated tap network. The following section will show you how to use [marz](https://github.com/sgso/marz) to accomplish this.


TODO