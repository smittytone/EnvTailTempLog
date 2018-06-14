// Environment Tail Data Log
// Copyright 2016-18, Tony Smith

// IMPORTS
#require "Rocky.class.nut:2.0.1"
#import "../Location/location.class.nut"


// CONSTANTS
// If you are NOT using Squinter or a similar tool, replace the #import statement below
// with the contents of the named file (envtemplog_ui.html)
const HTML_STRING = @"
#import "envtemplog_ui.html"
";


// GLOBALS
local api = null;
local locator = null;
local settings = null;
local newStart = false;
local deviceReady = false;
local debug = true;


// FUNCTIONS
function postReading(reading) {
    // Save it for presentation too
    settings.temp = format("%.2f", reading.temp);
    settings.humid = format("%.2f", reading.humid);
    local result = server.save(settings);
    if (result != 0) server.error("Could not back up data");
}

function parsePlaceData(data) {
    // Run through the raw place data returned by Google and find what area we're in
    foreach (item in data) {
        foreach (k, v in item) {
            // We're looking for the 'types' array
            if (k == "types") {
                // Got it, so look through the elements for 'neighborhood'
                foreach (entry in v) {
                    if (entry == "neighborhood") return item.formatted_address;
                }
            }
        }
    }

    // Iterate through the results table to find the admin area instead
    // This is because there is no 'neighborhood' entry
    foreach (item in data) {
        foreach (k, v in item) {
            // We're looking for the 'types' array
            if (k == "types") {
                // Got it, so look through the elements for 'dministrative_area_level_3'
                foreach (entry in v) {
                    if (entry == "administrative_area_level_3") return item.formatted_address;
                }
            }
        }
    }

    return "Unknown";
}

function reset() {
    // Wipe the data stored on the server
    server.save({});

    // Reset the settings to default values
    settings = {};
    settings.temp <- "TBD";
    settings.humid <- "TBD";
    settings.locale <- "";
    settings.location <- {};
    settings.location.lat <- 0.0;
    settings.location.lng <- 0.0;
    settings.location.loc <- "Unknown";
    settings.debug <- debug;
}


// START OF PROGRAM

#import "~/Dropbox/Programming/Imp/Codes/envtailtemplog.nut"
// To use, un-comment and complete the following line:
// locator = Location("<YOUR_GOOGLE_GEOLOCATION_API_KEY>");

// Instantiate objects
api = Rocky();

// Clear saved data on from the server if required
if (newStart) server.save({});

// Set up the current settings and preserved data
settings = {};
settings.temp <- "TBD";
settings.humid <- "TBD";
settings.locale <- "";
settings.location <- {};
settings.location.lat <- 0.0;
settings.location.lng <- 0.0;
settings.location.loc <- "Unknown";
settings.debug <- debug;

local backup = server.load();

if (backup.len() != 0) {
    settings = backup;
    if ("debug" in settings) debug = settings.debug;
} else {
    local result = server.save(settings);
    if (result != 0) server.error("Could not save application data");
}

// Set up the app's API
api.get("/", function(context) {
    // Root request: just return standard HTML string
    context.send(200, format(HTML_STRING, http.agenturl()));
});

api.get("/state", function(context) {
    // Request for data from /state endpoint
    context.send(200, { "temp"  : settings.temp,
                        "humid" : settings.humid,
                        "name"  : settings.locale,
                        "locale": settings.location.loc,
                        "debug" : debug });
});

api.post("/name", function(context) {
    // Sensor name string submission at the /name endpoint
    local data = http.jsondecode(context.req.rawbody);
    if ("name" in data) {
        if (data.name != "") {
            settings.locale = data.name;
            local parts = split(dweetName, "-");
            dweetName = parts[0] + "-" + settings.locale;
            if (debug) server.log("New Dweetname: " + dweetName);
            context.send(200, { "name" : settings.locale });
            local result = server.save(settings);
            if (result != 0) server.error("Could not save application data");
            return;
        }
    }

    context.send(200, "OK");
});

// POST at /debug updates the passed setting(s)
// passed to the endpoint:
// { "debug" : <true/false> }
api.post("/debug", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);
        if ("debug" in data) {
            debug = data.debug;
            server.log("Debug " + (debug ? "enabled" : "disabled"));
            device.send("env.tail.set.debug", debug);

            if ("debug" in settings) {
                settings.debug = debug;
            } else {
                settings.debug <- debug;
            }

            local result = server.save(settings);
            if (result != 0) server.error("Could not save application data");
        }
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }

    context.send(200, (debug ? "Debug on" : "Debug off"));
});

// GET to /clear zaps the settings
api.get("/clear", function(context) {
    context.send(200, "OK");
    reset();

    // Put back the location data
    local lcn = locator.getLocation();
    settings.location.lat = lcn.latitude;
    settings.location.lng = lcn.longitude;
    settings.location.loc = parsePlaceData(lcn.placeData);

    // Save the reset settings data on the server
    local result = server.save(settings);
    if (result != 0) server.error("Could not save application data");
});

// GET at /controller/info returns app data for Controller
api.get("/controller/info", function(context) {
    local info = { "appcode": APP_CODE,
                   "watchsupported": "false" };
    context.send(200, http.jsonencode(info));
});

// GET at /controller/state returns device status for Controller
api.get("/controller/state", function(context) {
    local data = device.isconnected() ? "1" : "0";
    context.send(200, data);
});

// Register the function to handle data messages from the device
device.on("env.tail.reading", postReading);

// Handle device readiness notification by determining device location
// NOTE only do this once per agent runtime as device restarts many times
device.on("env.tail.device.ready", function(dummy) {
    // First, set debug
    device.send("env.tail.set.debug", debug);

    // Now perform the rest of the set-up
    if (!deviceReady) {
        locator.locate(true, function() {
            deviceReady = true;

            // Get the location of the device
            local lcn = locator.getLocation();
            settings.location.lat = lcn.latitude;
            settings.location.lng = lcn.longitude;
            settings.location.loc = parsePlaceData(lcn.placeData);

            // Save the settings data on the server
            local result = server.save(settings);
            if (result != 0) server.error("Could not save application data");
        }.bindenv(this));
    }
}.bindenv(this));
