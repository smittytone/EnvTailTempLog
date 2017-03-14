// Environment Tail Data Log 1.1
// Copyright 2016-17, Tony Smith

#require "Dweetio.class.nut:1.0.1"
#require "Rocky.class.nut:2.0.0"

// CONSTANTS
const HTML_STRING = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<html>
    <head>
        <title>Environment Data</title>
        <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css'>
        <link href='//fonts.googleapis.com/css?family=Oswald' rel='stylesheet'>
        <link href='//fonts.googleapis.com/css?family=Abel' rel='stylesheet'>
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
            <div class='container' style='border: 2px solid white'>
                <h2 class='text-center'>Environment Data</h2>
                <div class='current-status'>
                    <h4 class='temp-status' align='center'>Current Temperature: <span></span>&deg;C</h4>
                    <h4 class='humid-status' align='center'>Current Humidity: <span></span> per cent</h4>
                    <h4 class='locale-status' align='center'>Sensor Location: <span></span></h4>
                    <p class='timestamp' align='center'>&nbsp;<br>Last reading: <span></span></p>
                </div>
                <br>
                <div class='controls' align='center'>
                    <form id='name-form'>
                        <div class='update-button' >
                            <p>Update Location Name <input id='location'></input>
                            <button style='color:dimGrey;font-family:Abel' type='submit' id='location-button'>Set Location</button></p>
                        </div>
                        <div class='debug-checkbox' style='color:white;font-family:Abel'>
                            <small><input type='checkbox' name='debug' id='debug' value='debug'> Debug Mode</small>
                        </div>
                    </form>
                </div>
                <br>
                <p align='center'><small>From: %s<br>Chart data at <a href='%s' target='_blank'>freeboard.io</a><br>&nbsp;</small></p>
                <hr>
                <p class='text-center' style='font-family:Oswald'><small>Weather Monitor copyright &copy; Tony Smith, 2014-17</small><br>&nbsp;<br><img src='https://dl.dropboxusercontent.com/u/3470182/rassilon.png' width='32' height='32'></p>
            </div>
        </div>

        <script src='https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js'></script>
        <script>
            var agenturl = '%s';

            getState(updateReadout);

            $('.update-button button').on('click', getStateInput);
            $('input:checkbox[name=debug]').click(setdebug);

            function getStateInput(e){
                e.preventDefault();
                var place = document.getElementById('location').value;
                setLocation(place);
                $('#name-form').trigger('reset');
            }

            function updateReadout(data) {
                $('.temp-status span').text(data.temp);
                $('.humid-status span').text(data.humid);
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

            function setLocation(place) {
                $.ajax({
                    url : agenturl + '/location',
                    type: 'POST',
                    data: JSON.stringify({ 'location' : place }),
                    success : function(response) {
                        if ('locale' in response) {
                            $('.locale-status span').text(response.locale);
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

// FUNCTIONS
function postReading(reading) {
    // Dweet the sensor data
    dweeter.dweet(dweetName, reading, function(response) {
        if (response.statuscode != 200) {
            if (debug) server.error("Could not Dweet data at " + time() + " (Code: " + response.statuscode + ")");
        }
    });

    // Save it for presentation too
    savedData.temp = format("%.2f", reading.temp);
	savedData.humid = format("%.2f", reading.humid);
	local result = server.save(savedData);
	if (result != 0) server.error("Could not back up data");

	// Inform registered displays
	if (savedData.displays.len() > 0) {
		local body = { "temp" : savedData.temp };
		body = http.jsonencode(body);
		foreach (display in savedData.displays) {
			local req = http.post(display + "/data", { "content-type" : "application/json" }, body);
			req.sendasync(function(response) {
				if (response.statuscode == 200) {
					if (debug) server.log("Device " + response.body + " ACKs receipt of data");
				}
			});
		}
	}
}

// GLOBALS
local dweeter = null;
local api = null;
local savedData = null;

local dweetName = "";
local freeboardLink = "";

local newstart = false;
local debug = true;

// START OF PROGRAM

// To use, un-comment and complete the following line:
// dweetName = "<YOUR_DWEET_DEVICE_NAME>";
// freeboardLink = "<YOUR_FREEBOARD_IO_URL>";

// And comment out the following line:
#import "../../../Dropbox/Programming/Imp/Codes/envtailtemplog.nut"

// Instantiate objects
dweeter = DweetIO();
api = Rocky();

// Set up the app's API
api.get("/", function(context) {
	// Root request: just return standard HTML string
	local url = http.agenturl();
	context.send(200, format(HTML_STRING, url, freeboardLink, url));
});

api.get("/state", function(context) {
	// Request for data from /state endpoint
	context.send(200, { "temp" : savedData.temp, "humid" : savedData.humid, "locale" : savedData.locale, "debug" : debug });
});

api.post("/location", function(context) {
	// Sensor location string submission at the /location endpoint
	local data = http.jsondecode(context.req.rawbody);
	if ("location" in data) {
		if (data.location != "") {
			savedData.locale = data.location;
			local parts = split(dweetName, "-");
			dweetName = parts[0] + "-" + savedData.locale;
			context.send(200, { locale = savedData.locale });
			local result = server.save(savedData);
			if (result != 0) server.error("Could not back up data");
			return;
		}
	}

	context.send(200, "OK");
});

api.post("/display", function(context) {
	// Register a display unit
	local data = http.jsondecode(context.req.rawbody);
	if ("id" in data) {
		server.log("Registering ID: " + data.id);
		if (data.id != "") {
			local gotFlag = false;
			foreach (item in savedData.displays) {
				if (item == data.id) {
					gotFlag = true;
					break;
				}
			}

			if (!gotFlag) {
				// This is a new display, so add it to the list
				savedData.displays.append(id);
			}

			context.send(200, { "id" : data.id });
			local result = server.save(savedData);
			if (result != 0) server.error("Could not back up data");
			return;
		}
	}
});

api.put("/display", function(context) {
	// Register a display unit
	local data = http.jsondecode(context.req.rawbody);
	if ("id" in data) {
		if (data.id != "") {
			local gotFlag = false;
			foreach (index, item in savedData.displays) {
				if (item == data.id) {
					// This is an existing display, so remove it from the list
					savedData.displays.remove(index);
				}
			}

			context.send(200, { "id" : data.id });
			local result = server.save(savedData);
			if (result != 0) server.error("Could not back up data");
			return;
		}
	}
});

api.get("/display", function(context) {
	// Return a list of registered displays
	context.send(200, format(HTML_STRING, http.agenturl(), freeboardLink, http.agenturl()));
});

// POST at /debug updates the passed setting(s)
// passed to the endpoint:
// { "debug" : <true/false> }
api.post("/debug", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);
        if ("debug" in data) {
            debug = data.debug;
            if (debug) {
                server.log("Debug enabled");
            } else {
                server.log("Debug disabled");
            }

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
if (newstart) server.save({});

// Set up the backup data
savedData = {};
savedData.temp <- "TBD";
savedData.humid <- "TBD";
savedData.locale <- "Unknown";
savedData.displays <- [];

local backup = server.load();
if (backup.len() != 0) {
	savedData = backup;
	dweetName = dweetName + "-" + savedData.locale;
} else {
	local result = server.save(savedData);
	if (result != 0) server.error("Could not back up data");
}

// Register the function to handle data messages from the device
device.on("env.tail.reading", postReading);
