---

layout: post
title: Sensing the moisture of a plants soil
subtitle: How to setup Atmel SAM R21, ADC and SEN0114
cover_image: covers/plant_pot_cropped.jpg
authors:
- peter

---

# Prerequisite

- You have the appropriate hardware
    - Atmel board [SAM R21 Xplained Pro](http://www.atmel.com/Images/Atmel-42243-SAMR21-Xplained-Pro_User-Guide.pdf)
    - 
    - External USB/UART converter to see STDOUTs
    - Some Jumper Cables
- You have the appropriate software
    - RIOT OS
    - Pull request [Watrli plant node #4](https://github.com/watr-li/RIOT/pull/4)
- You know how to build and flash software to the board like described in [this blogpost](http://watr.li/samr21-dev-setup-ubuntu.html)

One of the last pieces of the Watr.li puzzle was to measure the humidity of a plant's soil with one of our monitoring nodes. How we connected our humidity sensor to the SAM R21 and sampled it's values is the topic of this post.

<!-- more -->

The humidity sensor basically consists of two electrodes which should pass a current. These are tucked into the soil whose humidity we want to measure. The soil becomes more electrically conductive the more humid it is, increasing the current flow. On the sensor, a common collector circuit then translates the change in current flow to a change in voltage at its output, which is the sensor's output pin.

We sample this value using the "analog to digital converter" (ADC) on the SAM R21 board. The ADC is used in an operation mode that compares the input signal to a reference voltage and then quantizes the signal. The maximum sampled value is reached when the input has the same magnitude as the reference voltage, 3.3V for our scenario. Ignoring small voltage drops caused by the transistor circuit, the sensor should roughly reach this maximum value when submerged in water. We used the ADC with a sampling width of 12-bit, leading to a maximum value of 2^12-1 = 4095.


# Calibrating the ADC

Ideally, the correlation between sampled voltage and value is as shown in the figure below, i.e. the "Gain" is 1 and the "Offset" is 0.

<img src="images/sensing-moisture/calibration.png">

(mention that this is the norm with cheap ADCs)
In our case, however the value never dropped below a certain minimum and the maximum value of 4095 (i.e. 3.3V) was never reached, even when the sensor was submerged in water. To account for these inaccuracies inserted by the hardware, we needed to calibrate the ADC to the components being used.

Unfortunately, it is currently not possible to calibrate the ADC without modifying the RIOT source tree, so that is what we will have to do. The relevant settings are stored in the `boards/samd21-xpro/include/periph.conf` file. The values we will need to tweak are `SAMPLE_0_V_OFFSET` (the offset) and `SAMPLE_REF_V` (the gain). Do determine these values we will need to run the test application located at TODO TODO TODO. Flashing and running a RIOT application is explained in TODO TODO TODO.

<!-- In case of inaccuries caused by the hardware, the sampled values can be corrected by the hardware. The correction BEZIEHT SICH AUF the offset value and the scaling. These values are set in the file "RIOT/boards/samd21-xpro/include/periph.conf" with the variables `SAMPLE_0_V_OFFSET` and `SAMPLE_REF_V`. To calibrate these values you need to know how to run the test application described in section _Running the test application_. -->

<!-- note that for all work with the adc, the 3V3 reference voltage has to be connected to PA04 -->



## Running the test application



The test application can be on GitHub. In any directory, first clone the [Watr.li RIOT fork](https://github.com/watr-li/RIOT) and check out the "watrli" branch and then get the adc_test node from the [Watr.li nodes repository](https://github.com/watr-li/nodes):

    git clone https://github.com/watr-li/RIOT.git &&
        cd RIOT &&
        git checkout watrli &&
        cd .. &&
        https://github.com/watr-li/nodes.git &&
        cd nodes/adc_test &&
        BOARD=samr21-xpro make


You need to build the test application in `RIOT/tests/plant_node` PETERS PR and flash it to the board as described in [this blogpost](http://watr.li/samr21-dev-setup-ubuntu.html). Connecting to a terminal will show you the STDOUT which may help in testing. The sampled (moisture-)values are printed continuously. You can manipulate these values by connecting the sensor's spikes with your fingers, putting them into a glass of water or in you plant pot. Please also read the _Please note_ section.


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

This resulting value is the one that we want to set the `SAMPLE_REF_V` parameter in our `periph.conf` to.

* `SAMPLE_0_V_OFFSET = 90`
* `SAMPLE_REF_V = 2314`




# Final setup

After calibrating the ADC, we can finally connect the sensor and get some humidity values! For the sensor, we've used a [SEN0114 Moisture Sensor](http://www.dfrobot.com/index.php?route=product/product&product_id=599) from dfrobot, which is connected to the board as follows:

<img src="images/sensing-moisture/sensor.png">

Due to pin conflicts on the board, the STDOUT device needed to be changed from `UART_0` to `UART_1`. This prevented us from seeing the debug output from the board when the sensor was connected. Aa a result, we needed to employ an additional USB/UART converter to see the standard output from the board, which we connected as illustrated below:

<img src="images/sensing-moisture/uart.png">




# Please note

- When using the sensor in your plant pot, you should not set the soil under continuous voltage. Also you should not measure more often than "a couple of times" in an hour.
- This test uses timers. Be aware that RIOT timers in the current master may crash after an hour or so!
