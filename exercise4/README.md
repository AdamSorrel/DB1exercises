# Wokwi exercise 4: Analog digital converter (ADC)

Open the link to the exercise on the Wokwi platform: [https://wokwi.com/projects/450597286732080129](https://wokwi.com/projects/450597286732080129).

In this exercise, you will be using a rotary potentiometer. That is a device that changes its resistance based on how you rotate its knob. A similar device is perhaps used as a volume button of your audio amplifier. 

<br>

## Connecting potentiometer

Find a potentiometer in Wokwi menu indicated by the blue + button that says "add a new part". 

<img src="./ex4Imgs/adcImage.png" alt="Wokwi analog digital converter">

<br>

You will see three ports on your potentiometer: 

- GND means **ground** and should be connected to the ground of your device (also called GND)
- SIG in the middle stands for **signal** and it should be connected one of your ADC pins (see bellow).
- VCC should be connected to your constant 3.3V pin (top left).

> :bulb: Not all pins of your device are able to convert analogue signal to digital. In Wokwi, all pins seem to have this capacity, but in your actual HUZZAH32, it is only pins labelled A1 - A5 (pins 25, 26, 39, 36 and 4) and pins D12, D13, D14, D27, D33, D15, D32 (pin 13, 12, 33, 15, 32 and 14). 
 <img src="./ex2imgs/HUZZAH32pinout.png" alt="HUZZAH32 pinout">

<br>

Once you have connected your potentiometer, it is time to start programming. 

<br>

## Device programming

You can start your program by importing all necessary functions.

```python
from machine import Pin, ADC
from utime import sleep
```

Next we continue to declarations of pins. This case requires only one pin of your choice, which is the one you connected the SIG pin of your potentiometer. 

We will use the **class** `ADC` which we imported above. This class accepts one argument, which is another class `Pin()` with single argument, which is your pin number. This will look as follows:

```python
adc1 = ADC(Pin(<num>))
# <num> should be replaced by the number of your chosen pin. 
```
### Establishing the attenuation coefficient

:warning: By default, the input voltage to the ADC pin can be between 0V and 1V **only**. If we need to measure values above that range, we need to implement attenuation. This we we can scale the voltage to be between 0-1.34V, 0-2V and 0-3.6V.
The following attenuation values are available:

| Code          | Attenuation value | Voltage Range [V] |  
| ------------- | ----------------- | ----------------- |
| ATTN_0DB      | 1/1               | 0 to 1            |   
| ATTN_2_5DB    | 1/1.34            | 0 to 1.34         |
| ATTN_6DB      | 1/2               | 0 to 2            |
| **ATTN_11DB** | **1/3.6**         | **0 to 3.6**      |

As you have perhaps guessed already, the last one is the one relevant to our voltage range. The following part of the code will therefore be:

```python
adc1.atten(ADC.ATTN_11DB) 
```
Here we are editing the internal parameter `atten` of the previously created class `adc1`. The value of the `ATTN_11DB` is saved in the `ADC` class constructor and we are retrieving it from there. In fact, the variable named `ATTN_11DB` only contains a single integer value. It is saved like this to make your code more understandable. You can check what value hides behind this variable by printing its value, if you'd like. 

### Setting up ADC sensitivity

We can select with what sensitivity we want to detect our voltage. This corresponds to the number of bits retrieved for each measurement. The possible values are as follows:

| Code          | Represented values | Possible decimal values   |  
| ------------- | ------------------ | ------------------------- |
| WIDTH_9BIT    | 0 - $2^{9}$        | 0 to 511                  |   
| WIDTH_10BIT   | 0 - $2^{10}$       | 0 to 1023                 |
| WIDTH_11BIT   | 0 - $2^{11}$       | 0 to 2047                 |
| WIDTH_12BIT   | 0 - $2^{12}$       | 0 to 4095                 |

This parameter is accepted by the internal parameter `width` in exactly the same manner as the attenuation coefficient.

### Reading values from ADC class

Now that we have constructed an `ADC` class instance, passed the appropriate pin to read from, set up its attenuation value to set up the correct voltage range and set up the precision with which we want to measure our values, we are ready to read the analogue voltage values on that pin. 

To do that, we need to call `adc1` class functions to read its value. We have several to choose from. We will choose `read_uv()` which returns values in micro volts (μV). 

## Final task

Construct an infinite while loop that reads voltage values from your `adc1` class using its `read_uv()` function every half a second. Calculate the value in V instead of the supplied μV and print the value throuth the serial port using the `print()` function. 

>:bulb: You can use an f-string formatting for prettiness sake. Just a reminder, the constructor is `f"string {code}"` where "string" will get printed literally and all code in curly brackets will get interpreted (e.g. values of variables will get printed). 