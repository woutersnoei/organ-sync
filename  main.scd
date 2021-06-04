/*
Hyperorgan MIDI / OSC sync over vpn (or om local network)
v0.2 draft
W. Snoei 2021

** run in SuperCollider on macOS **

To operate:

- check "My Name" field (this name will show up at the remote machines)
- set the MIDI In to your desired MIDI input (or leave it on "all")
- set the output mode to what your organ prefers (MIDI or OSC)
- if MIDI, set the MIDI Out to the port connected to your organ
- check if "my ip" is correct (press "fetch" or enter manually)
- press "(re)start" once
- press the "send invites" button
	- if the "accept (n)" button shows up, press it.
	- if the "accept (n)" button stays hidden, try "send invites" again
	- if the "accept (n)" button never shows up, something is not right:
		- perhaps the others aren't ready yet
		- perhaps your vpn connection doesn't function yet
		- perhaps something else
	(- the accept button will also show up if others sent you an invitation)
- after accepting the invitations, a list should appear with all the known organs on the network
- for each:
	- open the organ's (sub) window by pressing the button with its name
	- in that window, press "ping"
		- if red square next to "ping" doesn't become green:
			- ping again
			- press "(re)start", and ping again
			- if that doesn't do it, something else is wrong
	- if the rectangle next to "ping" is green:
		- press the "use advised" button for latency,
	- and we're off!

- if at some point something changes in the network configuration:
	- the remotes can be removed with their 'x' buttons
	- remove all remotes and repeat the invitation process, from checking "my ip" onwards
*/

(
// load all files in correct order
[
	"sync.scd", // engine for sending timed messages over (vpn) network
	"bo.scd", // the OSC implementation of the Orgelpark Baroque organ
	"note tracker.scd", // simple utility to track note on/off status
	"local organ.scd", // engine for the local organ
	"gui.scd", // a GUI interface
	"spoof midiOuts.scd", // for SuperCollider users; use in Pbind (for example)
].do({ |item|
	(thisProcess.nowExecutingPath.dirname +/+ item).load;
});

~local_organ.makeWindow;
)

/*
~local_organ.midiChannels = [ 0,1,2,3 ]; // pedals, manual 1, 2, 3; can also be set in gui

~bo.postOSC = false; // stops posting messages in OSC mode

~local_organ.makeMIDIOuts; // if you use spoof midiOuts, call this after every change of remotes
*/