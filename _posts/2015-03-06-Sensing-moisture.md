---
layout: post
title: Sensing the humidity of a plant's soil
subtitle: Setting up the sensor with the SAM R21
cover_image: covers/plant_pot_cropped.jpg
authors:
- peter
- lucas
date: 2015-03-23

---

One of the last pieces of the watr.li puzzle was to measure the humidity of a plant's soil with one of our monitoring nodes. How we connected our humidity sensor to the SAM R21 and sampled its values is the topic of this post.

<!-- more -->

The humidity sensor basically consists of two electrodes which should pass a current. These are tucked into the soil whose humidity we want to measure. The soil becomes more electrically conductive the more humid it is, increasing the current flow. On the sensor, a common collector circuit then translates the change in current flow to a change in voltage at its output, which is the sensor's output pin.

We sample this value using the "analog to digital converter" (ADC) on the SAM R21 board. The ADC is used in an operation mode that compares the input signal to a reference voltage and then quantizes the signal. The maximum sampled value is reached when the input has the same magnitude as the reference voltage, 3.3V for our scenario. Ignoring small voltage drops caused by the transistor circuit, the sensor should roughly reach this maximum value when submerged in water. We used the ADC with a sampling width of 12-bit, leading to a maximum value of 2^12-1 = 4095.


# Calibrating the ADC

Ideally, the correlation between sampled voltage and value is as shown in the figure below, i.e. the "Gain" is 1 and the "Offset" is 0.

<img src="images/sensing-moisture/calibration.png">

In our case, however the value never dropped below a certain minimum and the maximum value of 4095 (i.e. 3.3V) was never reached, even when the sensor was submerged in water. This is a common issue with cheap ADC components, which is why they include hardware capabilites to compensate these inaccuracies. This compensation has to be calibrated, though.

Unfortunately, it is currently not possible to calibrate the ADC without modifying the RIOT source tree, so that is what we will have to do. The relevant settings are stored in the `boards/samd21-xpro/include/periph_conf` file. The values we will need to tweak are `SAMPLE_0_V_OFFSET` (the offset) and `SAMPLE_REF_V` (the gain). Do determine these values we will need to run the ADC test application, as explained in the upcoming section.



## Running the test application

The test application can be found on GitHub. In any directory, first clone the [Watr.li RIOT fork](https://github.com/watr-li/RIOT) and check out the "watrli" branch and then get the adc_test node from the [Watr.li nodes repository](https://github.com/watr-li/nodes):

    git clone https://github.com/watr-li/RIOT.git &&
        cd RIOT &&
        git checkout watrli &&
        cd .. &&
        https://github.com/watr-li/nodes.git &&
        cd nodes/adc_test &&
        BOARD=samr21-xpro make


## Setting up the offset correction

In this test we will identify the offset, i.e. the minimum value the ADC can return with our setup. For this, `SAMPLE_REF_V` needs to be initialized with 0 and `ADC_0_CORRECTION_EN` has to be disabled, i.e. set to 0 too. Connect a GND pin to the ADC pin `PA06` and a the 3.3V (the reference voltage) to the `PA04` pin. Now run the test. The application will print values larger than `0`. We'll call this value "offset_value". This is the value to set for `SAMPLE_0_V_OFFSET`.

<img src="images/sensing-moisture/offset-calibration.png">


## Setting up the gain correction

This time we try to discover the maximum value the ADC measures when the reference voltage is supplied. For this test `SAMPLE_0_V_OFFSET` needs to be set as described above and `SAMPLE_REF_V` has to be set to 2048. Connect the 3.3V pin to the ADC pin `PA06` and run the test and to the `PA04` pin. The application should print values smaller than `4095`. We'll call this value the "measured_value".

<img src="images/sensing-moisture/gain-calibration.png">


## Calculating the gain

The general equation for the ADC hardware correction abilities is:

    expected_value = (measured_value - offset_value) * gain_value
{: .wide }

Substituting the known values and solving the equation for gain_value we get:

    gain_value = (expected_value) / (measured_value - offset_value)
{: .wide }

In my case, I measured the following values:

* For the `expected_value` we'll use 4095 since that is the maximum value the ADC can return with 12-bit resolution. 
* `offset_value = 90`
* `measured_value = 3700`

The gain value thus becomes

    gain_value = (4095) / (3700 - 90) ≈ 1.13

To set the microcontroller to the correct 12-bit gain value, we will need a truncated [binary fixed-point](http://www.cs.uwm.edu/~cs151/Bacon/Lecture/HTML/ch03s07.html) representation ([this site](http://www.exploringbinary.com/binary-converter/) lets you convert back and forth between the formats):

<p>
    1.13<sub>10</sub> = 1.0010000101000111101...<sub>2</sub>
    <br>
    1.13<sub>10</sub> ≈ 1.00100001010<sub>2</sub> (truncated)
</p>

We then remove the decimal point in the truncated binary representation and convert the resulting binary number back to the decimal system:

<p>
    100100001010<sub>2</sub> = 2314<sub>10</sub>
</p>

This resulting value is the one that we want to set the `SAMPLE_REF_V` parameter in our `periph_conf` to.

* `SAMPLE_0_V_OFFSET = 90`
* `SAMPLE_REF_V = 2314`




# Final setup

After calibrating the ADC, we can finally connect the sensor! As the sensor, we've used a [SEN0114 Moisture Sensor](http://www.dfrobot.com/index.php?route=product/product&product_id=599) from dfrobot, which is connected to the board as follows:

<img src="images/sensing-moisture/sensor.png">

Unfortunately, the ADC conflicts with the default STDOUT device (`UART_0`) on the SAM R21 board, which is piped through the EDBG USB port. To be able to see the debug output from the RIOT application nonetheless, we had to change the output to `UART_1`. Since `UART_1` does not have a USB interface, we needed an additional USB/UART converter, which had to be connected as illustrated below:

<img src="images/sensing-moisture/uart.png">

Now that everything is set up and connected, we can finally get some humidity values by running the ADC test application once more!

**Note:** When using the sensor in your plant pot, you should not set the soil under continuous voltage as this might damage the plant. Also you should not measure more often than "a couple of times" in an hour.
{: .alert .alert-warning }
