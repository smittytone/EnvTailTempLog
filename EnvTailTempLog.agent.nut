// Environment Tail Data Log
// Copyright 2016-17, Tony Smith

#require "Dweetio.class.nut:1.0.1"
#require "Rocky.class.nut:2.0.0"

#import "../Location/location.class.nut"

// CONSTANTS
const HTML_STRING = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<html>
    <head>
        <title>Environment Data</title>
        <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css'>
        <link href='https://fonts.googleapis.com/css?family=Oswald' rel='stylesheet'>
        <link href='https://fonts.googleapis.com/css?family=Abel' rel='stylesheet'>
        <link rel='apple-touch-icon' href='https://smittytone.github.io/images/ati-tsensor.png'>
        <link rel='shortcut icon' href='https://smittytone.github.io/images/ico-tsensor.ico' />
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
            body {background-color: #3366cc}
            p {color: white; font-family: Abel}
            h2 {color: #99ccff; font-family: Abel; font-weight:bold}
            h4 {color: white; font-family: Abel}
            td {color: white; font-family: Abel}
            a:link {color: white; font-family: Abel}
            a:visited {color: #cccccc; font-family: Abel}
            a:hover {color: black; font-family: Abel}
            a:active {color: black; font-family: Abel}
        </style>
    </head>
    <body>
        <div class='container' style='padding: 20px'>
            <div style='border: 2px solid white'>
                <h2 class='text-center'>Environment Data <span></span></h2>
                <div class='current-status'>
                    <h4 class='temp-status' align='center'>Current Temperature: <span></span>&deg;C</h4>
                    <h4 class='humid-status' align='center'>Current Humidity: <span></span> per cent</h4>
                    <h4 class='name-status' align='center'>Sensor Name: <span></span></h4>
                    <h4 class='locale-status' align='center'>Sensor Location: <span></span></h4>
                    <p class='timestamp' align='center'>&nbsp;<br>Last reading: <span></span></p>
                    <p align='center'>Contemporary chart data at <a href='%s' target='_blank'>freeboard.io</a></p>
                </div>
                <br>
                <div class='controls' align='center'>
                    <form id='name-form'>
                        <div class='update-button'>
                            Update Sensor Name <input id='location'></input>
                            <button style='color:dimGrey;font-family:Abel' type='submit' id='location-button'>Set Name</button>
                        </div>
                        <div class='debug-checkbox' style='color:white;font-family:Abel'>
                            <small><input type='checkbox' name='debug' id='debug' value='debug'> Debug Mode</small>
                        </div>
                    </form>
                </div>
                <hr>
                <p class='text-center' style='font-family:Oswald'><small>Environment Data &copy; Tony Smith, 2014-17</small><br>&nbsp;<br><a href='https://github.com/smittytone/EnvTailTempLog'><img src='https://smittytone.github.io/images/rassilon.png' width='32' height='32'></a></p>
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
                setLocation(place);
                $('#name-form').trigger('reset');
            }

            function updateReadout(data) {
                $('.text-center span').text(data.vers);
                $('.temp-status span').text(data.temp);
                $('.humid-status span').text(data.humid);
                $('.name-status span').text(data.name);
                $('.locale-status span').text(data.locale);

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
local savedData = null;
local dweetName = "";
local freeboardLink = "";
local appName = "EnvTempLog";
local appVersion = "1.2";
local newStart = false;
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
    savedData.temp = format("%.2f", reading.temp);
    savedData.humid = format("%.2f", reading.humid);
    local result = server.save(savedData);
    if (result != 0) server.error("Could not back up data");
}

function reset() {
    server.save({});
    savedData = {};
    savedData.temp <- "TBD";
    savedData.humid <- "TBD";
    savedData.locale <- "Unknown";
    savedData.location <- {};
    savedData.location.lat <- 0.0;
    savedData.location.lng <- 0.0;
    savedData.location.loc <- "Unknown";
}

// START OF PROGRAM

// To use, un-comment and complete the following line:
// dweetName = "<YOUR_DWEET_DEVICE_NAME>";
// freeboardLink = "<YOUR_FREEBOARD_IO_URL>";
// locator = Location("<YOUR_GOOGLE_GEOLOCATION_API_KEY>");

#import "../../../Dropbox/Programming/Imp/Codes/envtailtemplog.nut"

// Instantiate objects
dweeter = DweetIO();
api = Rocky();

// Set up the app's API
api.get("/", function(context) {
    // Root request: just return standard HTML string
    context.send(200, format(HTML_STRING, freeboardLink, http.agenturl()));
});

api.get("/state", function(context) {
    // Request for data from /state endpoint
    context.send(200, { "temp"  : savedData.temp,
                        "humid" : savedData.humid,
                        "name"  : savedData.locale,
                        "locale": savedDate.location.place,
                        "debug" : debug,
                        "vers"  : appVersion });
});

api.post("/name", function(context) {
    // Sensor name string submission at the /name endpoint
    local data = http.jsondecode(context.req.rawbody);
    if ("name" in data) {
        if (data.name != "") {
            savedData.locale = data.name;
            local parts = split(dweetName, "-");
            dweetName = parts[0] + "-" + savedData.locale;
            if (debug) server.log("New Dweetname: " + dweetName);
            context.send(200, { "name" : savedData.locale });
            local result = server.save(savedData);
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
        }
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }

    context.send(200, (debug ? "Debug on" : "Debug off"));
});


// Clear save data if required
if (newStart) server.save({});

// Set up the current data
savedData = {};
savedData.temp <- "TBD";
savedData.humid <- "TBD";
savedData.locale <- "Unknown";
savedData.location.lat <- 0.0;
savedData.location.lng <- 0.0;
savedData.location.loc <- "Unknown";

local backup = server.load();

if (backup.len() != 0) {
    savedData = backup;
    dweetName = dweetName + "-" + savedData.locale;
} else {
    local result = server.save(savedData);
    if (result != 0) server.error("Could not save application data");
}

// Register the function to handle data messages from the device
device.on("env.tail.reading", postReading);

// Handle device readiness notification by determining device location
device.on("env.tail.device.ready", function(dummy) {
    locator.locate(function() {
        local lcn = locator.getLocation();
        savedData.location.lat = lcn.lat;
        savedData.location.lng = lcn.long;
        savedData.location.loc = lcn.place;
        
        local result = server.save(savedData);
        if (result != 0) server.error("Could not save application data");
    }.bindenv(this););
}.bindenv(this););
