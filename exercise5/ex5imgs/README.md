# Wokwi exercise 5: Pulse width modulation (PWM)

Open the link to the exercise on the Wokwi platform: [https://wokwi.com/projects/450672575785846785](https://wokwi.com/projects/450672575785846785).

This exercise is a throwback to working with a single LED, but this time we will make it a lot more sophisticated by adding PWM. The setup is very similar to the ADC exercise, so you will get only general information and you'll be left to figure out most of the coding yourselves. If you are unsure what to do, give yourself some time to think about it and check the previous exercise for inspiration. Ask your neighbour if you still cannot figure it out or call upon your TA. 

## Connecting LED

All you will need for this exercise is an LED and a resistor (don't forget that one!). You can use 1 K$\Omega$ resistor. Mind the LED polarity. 

> :bulb: It might be a good idea to first check your setup with a simple code to light your LED up to verify that everything is connected properly. You can reuse some code from before.

## Programming 

1. Import the `PWM` and `Pin` classes from the module `machine`.
2. Set up a pin of your choise as a `PWM` class pin. This class takes several arguments.
   1. Firstly a `Pin` clas which in this case needs only one argument which is the number of you pin. In the same way we have done for the `ADC` class constructor.
   2. You can supply additional arguments such as `freq` for frequency. Wokwi cannot really simulate the effect of frequency very well, so choose just 1 kHz for now. You will explore that more in depth in your assignment. 
   3. You can also supply a starting value of duty cycle with the argument `duty`. With the 1kHz frequency, your maximum duty cycle should be 1023. You can pick any value between that and zero.
   4. Don't forget to save your constructed `PWM` class into a variable. We will need this variable to edit its duty cycle further.  
3. Construct an infinite `while` loop and cycle between several duty cycles. You can change duty cycle yousing the parameter `duty` of the class variable you have constructed above. This is done analogously to how we changed the `atten` parameter of the `ADC` class in the previous exercise. 

## Expected outcome

You should see your LED changing brightness. In Wokwi, this animation has certain limitations, but you will see better when we work with HUZZAH32 device. 