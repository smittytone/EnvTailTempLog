// Environment Tail Data Log
// Copyright 2016-18, Tony Smith

// IMPORTS
#require "Si702x.class.nut:1.0.0"
#import "../Location/location.class.nut"

// CONSTANTS
const SLEEP_TIME = 120;

// GLOBALS
local tail = null;
local led = null;
local locator = null;
local debug = true;

// FUNCTIONS
function processData(data) {
    if ("err" in data) {
        server.error(err);
    } else {
        // Create a Squirrel table to hold the data - handy if we
        // later want to package up other data from other sensors
        local sendData = {};

        // Add the temperature using Squirrel’s 'new key' operator
        sendData.temp <- data.temperature;
        sendData.humid <- data.humidity;

        // Send the packaged data to the agent
        local result = agent.send("env.tail.reading", sendData);

        if (result != 0) {
            // Flash the LED once to show we couldn't send the data
            result++;
            for (local i = 0 ; i < result ; i++) {
                flashLed();
            }
        } else {
            // Flash the LED once to show we've taken a reading -
            flashLed();
        }

        if (debug) {
            server.log("Temperature: " + format("%.2f", data.temperature) + "˚C");
            server.log("Humidity: " + format("%.2f", data.humidity) + "%");
        }

        // Set the imp to sleep for 30s once the reading has been taken
        // and the imp has gone idle
        imp.onidle(function() {
            if (debug) server.log("Device sleeping for " + SLEEP_TIME + " seconds");
            server.sleepfor(SLEEP_TIME);
        });
    }
}

function flashLed() {
    led.write(1);
    imp.sleep(0.5);
    led.write(0);
}

// START OF PROGRAM
// Load in generic boot message code
#include "../generic/bootmessage.nut"

// Instance Location
locator = Location();

// Instance the Si702x and save a reference in tailSensor
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tail = Si702x(hardware.i2c89, 0x80);

// Configure the LED (on pin 2) as digital out with 0 start state
led = hardware.pin2;
led.configure(DIGITAL_OUT, 0);

// Allow agent to set the 'debug' flag
agent.on("env.tail.set.debug", function(value) {
    debug = value;
});

// Signal readiness
agent.send("env.tail.device.ready", true);

// Take a temperature reading as soon as the device starts up
// Note: when the device wakes from sleep (caused by line 38)
// it runs its device code afresh - ie. it does a warm boot
tail.read(processData);
