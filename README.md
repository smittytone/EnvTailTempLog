# EnvTailTempLog 1.5 #

A very simple Electric Imp-based environmental temperature/humidity sensor. It is built around the [imp001 card, ‘April’ breakout board](https://developer.electricimp.com/gettingstarted/devkits) and the Environment Sensor Tail (though this is no longer available to buy).

## Hardware ##

The imp001 slots into the April, the Environment Sensor Tail fits onto the April’s breakout connector pins. Plug it into a USB adaptor and you’re ready to begin. The complete hardware looks like this:

![Hardware](images/hardware.jpg)

## Software ##

EnvTailTempLog requires a free Electric Imp developer account. To find out more and sign up for an account, please see the [Electric Imp Getting Started Guide](https://developer.electricimp.com/gettingstarted). This will tell you everything you need to know to get your environmental temperature/humidity sensor online.

The agent and device code included in this repository will need to be pasted into Electric Imp impCentral.

## Location ##

This code makes use of the [Location](https://github.com/smittytone/Location) class. If you are not using a tool like [Squinter](https://smittytone.github.io/squinter/version2/index.html) to combine multiple source files before uploading the application to the Electric Imp impCloud, you will need to paste the [Location](https://github.com/smittytone/Location) class code into the EnvTailTempLog source (both device and agent code) in place of the relevant `#import` line.

## Control UI ##

Visit your sensor’s agent URL for a simple control interface.

## Licence ##

EnvTailTempLog is licensed under the terms and conditions of the [MIT Licence](./LICENSE).

Copyright 2016-18 Tony Smith
