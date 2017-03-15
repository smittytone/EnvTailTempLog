// Environment Tail Data Log
// Copyright 2016-17, Tony Smith

#require "Si702x.class.nut:1.0.0"

// CONSTANTS
const SLEEP_TIME = 120;

// GLOBALS
local tail = null;
local led = null;
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
        agent.send("env.tail.reading", sendData);

        // Flash the LED to show we've taken a reading
        flashLed();

        if (debug) {
            server.log("Temperature: " + format("%.2f", data.temperature) + "˚C");
            server.log("Humidity: " + format("%.2f", data.humidity) + "%");
        }
    }
}

function flashLed() {
    led.write(1);
    imp.sleep(0.5);
    led.write(0);
}

// START OF PROGRAM

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

// Set the imp to wake in 'SLEEP_TIME' seconds and
// set the idle function to sleep the device
imp.wakeup(SLEEP_TIME, function() {
    tail.read(processData);
    imp.onidle(function() {
        server.sleepfor(SLEEP_TIME);
    });
});

// Take a temperature reading as soon as the device starts up
// Note: when the device wakes from sleep (caused by line 38)
// it runs its device code afresh - ie. it does a warm boot
tail.read(processData);
