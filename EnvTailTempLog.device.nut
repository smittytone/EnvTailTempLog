// Environment Tail Data Log
// Copyright 2020, Tony Smith

// IMPORTS
#require "Si702x.device.lib.nut:2.0.1"
#import "../Location/location.class.nut"


// CONSTANTS
const SLEEP_TIME = 60;


// GLOBALS
local tail = null;
local led = null;
local locator = null;
local debug = false;
local doFlash = true;


// FUNCTIONS
function processData(data) {
    if ("err" in data) {
        server.error(err);
    } else {
        // Got data, so connect and send it
        if (!server.isconnected()) server.connect();
        agent.send("env.tail.get.settings", true);

        // Create a Squirrel table to hold the data - handy if we
        // later want to package up other data from other sensors
        local sendData = {};

        // Add the temperature using Squirrel’s 'new key' operator
        sendData.temp <- data.temperature;
        sendData.humid <- data.humidity;

        // Send the packaged data to the agent
        local result = agent.send("env.tail.reading", sendData);

        if (result != 0) {
            // Flash the LED result times to show we couldn't send the data
            result++;
            for (local i = 0 ; i < result ; i++) flashLed();
        } else {
            // Flash the LED once to show we've taken a reading -
            if (doFlash) flashLed();
        }

        if (debug) {
            server.log("Temperature: " + format("%.2f", data.temperature) + "˚C");
            server.log("Humidity: " + format("%.2f", data.humidity) + "%");
        }

        // Set the imp to sleep for 30s once the reading has been taken
        // and the imp has gone idle
        imp.onidle(function() {
            if (debug) {
                server.log("Next reading in " + SLEEP_TIME + " seconds");
                server.log("EnvTailTempLog disconnecting...");
            }
            server.flush(30);
            server.disconnect();
            imp.wakeup(SLEEP_TIME, function() {
                tail.read(processData);
            });
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
#include "../generic-squirrel/bootmessage.nut"

// Instance Location
locator = Location();

// Instance the Si702x and save a reference in tailSensor
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tail = Si702x(hardware.i2c89, 0x80);

// Configure the LED (on pin 2) as digital out with 0 start state
led = hardware.pin2;
led.configure(DIGITAL_OUT, 0);

if ("nv" in getroottable()) {
    doFlash = nv.flash;
}

// Allow agent to set the 'debug' flag
// NOTE This is always called in response to the device's 'ready' message
agent.on("env.tail.start", function(value) {
    debug = value;
    tail.read(processData);
});

// Allow agent to set the 'debug' flag
agent.on("env.tail.set.debug", function(value) {
    debug = value;
});

// Allow agent to set the 'doFlash' flag
agent.on("env.tail.set.led", function(value) {
    doFlash = value;
    if (!("nv" in getroottable())) {
        nv <- { "flash": doFlash };
    } else {
        nv.flash = doFlash;
    }
});

if (!server.isconnected()) {
    // Take a temperature reading as soon as the device starts up,
    // provided we're not connected
    tail.read(processData);
} else {
    // Signal readiness to the agent (used for locating)
    agent.send("env.tail.device.ready", true);
}
