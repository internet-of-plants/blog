---

layout: post
title: Sensing the moisture of a plants soil
subtitle: How to setup Atmel SAM R21, ADC and SEN0114
cover_image: covers/plant_pot.jpg
authors:
- peter

---

# Prerequisite

- You have the appropriate hardware
    - Atmel board [SAM R21 Xplained Pro](http://www.atmel.com/Images/Atmel-42243-SAMR21-Xplained-Pro_User-Guide.pdf)
    - Moisture Sensor [SEN0114](http://www.dfrobot.com/index.php?route=product/product&product_id=599)
    - External USB/UART converter to see STDOUTs
    - Some Jumper Cables
- You have the appropriate software
    - RIOT OS
    - Pull request [Watrli plant node #4](https://github.com/watr-li/RIOT/pull/4)
- You know how to build and flash software to the board like described in [this blogpost](http://watr.li/samr21-dev-setup-ubuntu.html)

# This is how it works

The moisture sensor basically consists of two electrodes which should pass a current. These were tucked into the soil which is more ore less electrically conductive, depending on the moisture of the soil. A moister soil increases the conductivity and therefore decreases the resistance of the soil which leads to a higher current flow. On-sensor, a common collector circuit is modulated that results in a voltage variation at its output which is the sensors output pin. This value is sampled by the analog to digital converter (ADC) of the Atmel board. The ADC is used in a operation mode that compares the input signal by a reference voltage and then quantizes the the signal. The maximum sampled value is reached when the input signal has the same magnitude as the reference voltage. Besides of small voltage drops caused by the transistor circuit, the sensor should roughly reach this value under water. Setting the sampling width of the ADC to 12bit leads to a maximum value of 2^12 -1 = 4095 ("expected_val"). Assuming a linear correlation between the voltage at the sensor's output and the moisture, one can divide the range into three commensurate intervals to classify the moisture as dry, normal and wet.

## Configuring the ADC

In case of inadequacies inserted by the hardware, the sampled values can be corrected by the hardware. The correction BEZIEHT SICH AUF the offset value and the scaling. These values are set in the file "RIOT/boards/samd21-xpro/include/periph.conf" with the variables `SAMPLE_0_V_OFFSET` and `SAMPLE_REF_V`. To calibrate these values you need to know how to run the test application described in section _Running the test application_.

### Setting up the offset correction

For this test `SAMPLE_REF_V` needs to be initialized with 0. Connect a GND pin to the ADC pin `PA08` and run the test. The application will print values not `0`. We'll call this value "offset_val". This is the value to set for `SAMPLE_0_V_OFFSET`.

### Setting up the gain correction

For this test `SAMPLE_0_V_OFFSET` needs to be set like described above. Connect the 3V3 pin to the ADC pin `PA08` and run the test. The application will print values not `4095`. We'll call the measured value "measured_val". The general equation for the hardware correction abilities is:

`expected_val = (measured_val - offset_val) * gain_val`

Substituting the known values and solving the equation vor gain_val we get:

`gain_val = (expected_val) / (measured_val - offset_val)`

### Example

In my case, I measured the following values:

`offset_val = 90`

`measured_val = 3700`

which leaded to an offset correction value

`SAMPLE_0_V_OFFSET = offset_val = 90`

and

`gain_val = (4095) / (3700 - 90) = 1,13`

As this value will be written to 12 bit in the microcontrollers register, we need to get the binary representation without the comma and have to truncate the result after the 12 MSBs. [This](http://www.arndt-bruenner.de/mathe/scripts/Zahlensysteme.htm) website may be of help for conversions. In my case, the result lead to:

`SAMPLE_REF_V = 2355`

This will be automated somehow in the future.

## Setup

![](images/raspi/raspi-config2.png)

In concequence of pin conflicts on the board, the STDOUT device needed to be changed from `UART_0` to `UART_1`. This is why you need to connect an external USB/UART converter if you want to see the STDOUT prints on a terminal.

A schematic block diagram will follow soon. Please compare `RIOT/boards/samd21-xpro/include/periph.conf`to get the needed details. 

Here is just a quick checklist:

- Sensor supply to board pin `PA13`
- Sensor GND to board GND
- Sensor value to ADC pin `PA08`
- Board reference voltage to ADC reference input pin `PA04`
- Board UART_1_TX_PIN PA22 to external Converter UART_RX pin
- Board UART_1_RX_PIN PA23 to external Converter UART_TX pin


## Running the test application

You need to build the test application in `RIOT/tests/plant_node` PETERS PR and flash it to the board as described in [this blogpost](http://watr.li/samr21-dev-setup-ubuntu.html). Connecting to a terminal will show you the STDOUT which may help in testing. The sampled (moisture-)values are printed continuously. You can manipulate these values by connecting the sensor's spikes with your fingers, putting them into a glass of water or in you plant pot. Please also read the _Please note_ section.

# Please note

- When using the sensor in your plant pot, you should not set the soil under continuous voltage. Also you should not measure more often than "a couple of times" in an hour.
- This test uses timers. Be aware that RIOT timers in the current master may crash after an hour or so!