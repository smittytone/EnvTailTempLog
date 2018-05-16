// Environment Tail Data Log
// Copyright 2016-18, Tony Smith

// IMPORTS
#require "Dweetio.class.nut:1.0.1"
#require "Rocky.class.nut:2.0.1"
#import "../Location/location.class.nut"

// CONSTANTS
const HTML_STRING = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<html>
    <head>
        <title>Environment Data</title>
        <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css'>
        <link href='https://fonts.googleapis.com/css?family=Open+Sans+Condensed:300' rel='stylesheet'>
        <link rel='apple-touch-icon' href='https://smittytone.github.io/images/ati-tsensor.png'>
        <link rel='shortcut icon' href='https://smittytone.github.io/images/ico-tsensor.ico' />
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
            .uicontent {border: 2px solid white}
            .container {padding: 20px}

            body {background-color: #3366cc}
            p {color: white; font-family: Open Sans Condensed, sans-serif; font-size: 16px}
            p.colophon {font-family: Open Sans Condensed, sans-serif; font-size: 13px}
            p.input {color: black}
            h2 {color: #99ccff; font-family: Open Sans Condensed, sans-serif; font-weight:bold}
            h4 {color: white; font-family: Open Sans Condensed, sans-serif}
            td {color: white; font-family: Open Sans Condensed, sans-serif}
            a:link {color: white; font-family: Open Sans Condensed, sans-serif; text-decoration: underline}
            a:visited {color: #cccccc; font-family: Open Sans Condensed, sans-serif; text-decoration: underline;}
            a:hover {color: black; font-family: Open Sans Condensed, sans-serif}
            a:active {color: black; font-family: Open Sans Condensed, sans-serif}

            @media only screen and (max-width: 640px) {
                .container {padding: 5px}
                .uicontent {border: 0px}
            }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='uicontent' align='center'>
                <h2 class='name-status' align='center'>Environment Data <span></span></h2>
                <div class='current-status-area'>
                    <h4 class='temp-status' align='center'>Current Temperature: <span></span>&deg;C</h4>
                    <h4 class='humid-status' align='center'>Current Humidity: <span></span> per cent</h4>
                    <h4 class='locale-status' align='center'>Sensor Location: <span></span></h4>
                    <p class='timestamp' align='center'>&nbsp;<br>Last reading: <span></span></p>
                    <p align='center'>Contemporary chart data at <a href='%s' target='_blank'>freeboard.io</a></p>
                </div>
                <br>
                <div class='controls-area' align='center'>
                    <form id='name-form'>
                        <div class='update-button'>
                            <p>Update Sensor Name <input id='location' style='color:black'></input>
                            <button style='color:dimGrey;font-family:Open Sans Condensed,sans-serif' type='submit' id='location-button'>Set Name</button></p>
                        </div>
                        <div class='debug-checkbox' style='color:white;font-family:Open Sans Condensed'>
                            <small><input type='checkbox' name='debug' id='debug' value='debug'> Debug Mode</small>
                        </div>
                    </form>
                </div>
                <hr>
                <p class='colophon' align='center'>Environment Data &copy; Tony Smith, 2014-17<br>&nbsp;<br><a href='https://github.com/smittytone/EnvTailTempLog'><img src='https://smittytone.github.io/images/rassilon.png' width='32' height='32'></a></p>
            </div>
        </div>

        <script src='https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js'></script>
        <script>
            var agenturl = '%s';

            getState(updateReadout);

            $('.update-button button').click(getStateInput);
            $('#debug').click(setdebug);

            function getStateInput(e){
                e.preventDefault();
                var place = document.getElementById('location').value;
                setName(place);
                $('#name-form').trigger('reset');
            }

            function updateReadout(data) {
                $('.temp-status span').text(data.temp);
                $('.humid-status span').text(data.humid);
                $('.locale-status span').text(data.locale);

                if (data.name === '') {
                    $('.name-status span').text('');
                } else {
                    $('.name-status span').text('(' + data.name + ')');
                }

                var date = new Date();
                $('.timestamp span').text(date.toTimeString());

                document.getElementById('debug').checked = data.debug;

                setTimeout(function() {
                    getState(updateReadout);
                }, 120000);
            }

            function getState(callback) {
                $.ajax({
                    url : agenturl + '/state',
                    type: 'GET',
                    success : function(response) {
                        if (callback) {
                            callback(response);
                        }
                    }
                });
            }

            function setName(name) {
                // Set the sensor name
                $.ajax({
                    url : agenturl + '/name',
                    type: 'POST',
                    data: JSON.stringify({ 'name' : name }),
                    success : function(response) {
                        if ('name' in response) {
                            $('.name-status span').text(response.name);
                        }
                    }
                });
            }

            function setdebug() {
                // Tell the device to enter or leave debug mode
                $.ajax({
                    url : agenturl + '/debug',
                    type: 'POST',
                    data: JSON.stringify({ 'debug' : document.getElementById('debug').checked })
                });
            }

        </script>
    </body>
</html>";

// GLOBALS
local dweeter = null;
local api = null;
local locator = null;
local settings = null;
local dweetName = "";
local freeboardLink = "";
local newStart = false;
local deviceReady = false;
local debug = true;

// FUNCTIONS
function postReading(reading) {
    // Dweet the sensor data
    dweeter.dweet(dweetName, reading, function(response) {
        if (response.statuscode != 200) {
            if (debug) server.error("Could not Dweet data at " + time() + " (Code: " + response.statuscode + ")");
        } else {
            if (debug) server.log("Dweeted data for " + dweetName);
        }
    });

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
// dweetName = "<YOUR_DWEET_DEVICE_NAME>";
// freeboardLink = "<YOUR_FREEBOARD_IO_URL>";
// locator = Location("<YOUR_GOOGLE_GEOLOCATION_API_KEY>");

// Instantiate objects
dweeter = DweetIO();
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
    dweetName = dweetName + "-" + settings.locale;
} else {
    local result = server.save(settings);
    if (result != 0) server.error("Could not save application data");
}

// Set up the app's API
api.get("/", function(context) {
    // Root request: just return standard HTML string
    context.send(200, format(HTML_STRING, freeboardLink, http.agenturl()));
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
