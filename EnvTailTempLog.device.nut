// Environment Tail Data Log
// Copyright 2016-18, Tony Smith

// IMPORTS
#import "../Location/location.class.nut"


// CLASSES

// Class Constants
// Commands
const SI702X_RESET          = "\xFE";
const SI702X_MEASURE_RH     = "\xF5";
const SI702X_MEASURE_TEMP   = "\xF3";
const SI702X_READ_PREV_TEMP = "\xE0";

// Additional constants
const SI702X_RH_MULT        = 0.0019073486328;  // ------------------------------------------------
const SI702X_RH_ADD         = -6;               // These values are used in the conversion equation
const SI702X_TEMP_MULT      = 0.0026812744141;  // from the Si702x datasheet
const SI702X_TEMP_ADD       = -46.85;           // ------------------------------------------------
const SI702X_TIMEOUT_MS     = 100;

class Si702x {

    static VERSION          = "2.0.0";

    _i2c  = null;
    _addr = null;

    // Constructor
    // Parameters:
    //      _i2c:     hardware i2c bus, must pre-configured
    //      _addr:    device address (optional)
    // Returns: (None)
    constructor(i2c, addr = 0x80) {
        _i2c  = i2c;
        _addr = addr;
    }

    // Resets the sensor to default settings
    function init() {
        _i2c.write(_addr, SI702X_RESET);
    }

    // Polls the sensor for the result of a previously-initiated measurement
    // (gives up after TIMEOUT milliseconds)
    function _pollForResult(startTime, callback) {
        local result = _i2c.read(_addr, "", 2);
        if (result) {
            callback(result);
        } else if (hardware.millis() - startTime < SI702X_TIMEOUT_MS) {
            imp.wakeup(0, function() {
                _pollForResult(startTime, callback);
            }.bindenv(this));
        } else {
            // Timeout
            callback(null);
        }
    }

    // Starts a relative humidity measurement
    function _readRH(callback = null) {
        _i2c.write(_addr, SI702X_MEASURE_RH);
        local startTime = hardware.millis();
        if (callback == null) {
            local result = _i2c.read(_addr, "", 2);
            while (result == null && hardware.millis() - startTime < SI702X_TIMEOUT_MS) {
                result = _i2c.read(_addr, "", 2);
            }
            return result;
        } else {
            _pollForResult(startTime, callback);
        }
    }

    // Reads and returns the temperature value from the previous humidity measurement
    function _readTempFromPrev() {
        local rawTemp = _i2c.read(_addr, SI702X_READ_PREV_TEMP, 2);
        if (rawTemp) {
            return SI702X_TEMP_MULT * ((rawTemp[0] << 8) + rawTemp[1]) + SI702X_TEMP_ADD;
        } else {
            server.log("Si702x i2c read error: " + _i2c.readerror());
            return null;
        }
    }

    // Initiates a relative humidity measurement,
    // then passes the humidity and temperature readings as a table to the user-supplied callback, if it exists
    // or returns them to the caller, if it doesn't
    function read(callback = null) {
        if (callback == null) {
            local rawHumidity = _readRH();
            local temp = _readTempFromPrev();
            if (rawHumidity == null || temp == null) {
                return {"err": "error reading temperature", "temperature": null, "humidity": null};
            }
            local humidity = SI702X_RH_MULT * ((rawHumidity[0] << 8) + rawHumidity[1]) + SI702X_RH_ADD;
            return {"temperature": temp, "humidity": humidity};
        } else {
            // Measure and read the humidity first
            _readRH(function(rawHumidity) {
                // If it failed, return an error
                if (rawHumidity == null) {
                    callback({"err": "reading timed out", "temperature": null, "humidity": null});
                    return;
                }

                // Convert raw humidity value to relative humidity in percent, clamping the value to 0-100%
                local humidity = SI702X_RH_MULT * ((rawHumidity[0] << 8) + rawHumidity[1]) + SI702X_RH_ADD;
                if (humidity < 0) { 
                    humidity = 0.0; 
                } else if (humidity > 100) { 
                    humidity = 100.0; 
                }

                // Read the temperature reading from the humidity measurement
                local temp = _readTempFromPrev();
                if (temp == null) {
                    callback({"err": "error reading temperature", "temperature": null, "humidity": null});
                    return;
                }
                
                // And pass it all to the user's callback
                callback({"temperature": temp, "humidity": humidity});
            }.bindenv(this));
        }
    }
}


// CONSTANTS
const SLEEP_TIME = 60;


// GLOBALS
local tail = null;
local led = null;
local locator = null;
local debug = false;


// FUNCTIONS
function processData(data) {
    if ("err" in data) {
        server.error(err);
    } else {
        // Got data, so connect and send it
        if (!server.isconnected()) server.connect();
        
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
            flashLed();
        }

        if (debug) {
            server.log("Temperature: " + format("%.2f", data.temperature) + "˚C");
            server.log("Humidity: " + format("%.2f", data.humidity) + "%");
        }

        // Set the imp to sleep for 30s once the reading has been taken
        // and the imp has gone idle
        imp.onidle(function() {
            if (debug) server.log("Next reading in " + SLEEP_TIME + " seconds");
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
// NOTE This is always called in response to the device's 'ready' message
agent.on("env.tail.set.debug", function(value) {
    debug = value;
    tail.read(processData);
});

if (!server.isconnected()) {
    // Take a temperature reading as soon as the device starts up,
    // provided we're not connected
    tail.read(processData);
} else {
    // Signal readiness to the agent (used for locating)
    agent.send("env.tail.device.ready", true);
}
