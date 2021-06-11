Organ Sync
===============================================================================
An engine and toolset for the Hyperorgan project, enabling multiple pipe-organs to play together over the Internet.

Organ sync is a program that runs in SuperCollider, designed for routing a MIDI input (for example, a keyboard or organ manual) to organs on one or more remote locations. At the same time a return routing is created for users at the remote locations to play on the local organ. The software should run at each location, and shares messages via a dedicated (hardware) VPN server (at the time of writing located in Vancouver).

In it's current form the program can only play and receive notes on specific manuals. Registration, swells, Setzer changes, air control etc. are not yet supported (but will be at some point). 

Organ Sync offers the user options to route specific MIDI channels to specific organs, or play all at the same time. There is also functionality to generate notes from within SuperCollider, for those who are at home in this software. Additionally, there is a Max For Live plugin for Ableton Live, providing the ability to send notes to the network straight from there (provided that the SuperCollider patch is also running). As the program accepts any MIDI input, it is also possible to send MIDI from other applications (on macos for example via the IAC MIDI bus, or with MAX using the "from Max" virtual MIDI ports). There can be multiple MIDI input devices at the same time, with the option of per-device routing. 

Support for the Sinua OSC system, as currently seen for example on the Utopa organ at Het Orgelpark in Amsterdam (NL), is built-in. Using the 'local thru' feature this program can also function as a MIDI interface for such an organ (be it only for playing notes, not registers etc.). For this connection to work properly the organ must either be on the same network as the internet connection (not recommended), or the computer needs to have two network interfaces (one to the organ, one to the internet), which in practice means two Ethernet connections.

## System Requirements ##

 - a pipe organ supporting MIDI or the Sinua OSC system
 - a computer with MIDI interface and wired internet connection (mac/linux/windows)
 - a VPN server, or connection to the current Hyperorgan VPN server (details can be obtained via the author of this software)
 - an installed copy of [SuperCollider](https://supercollider.github.io/) 3.5 or higher

## Installation ##

1) Go to https://github.com/woutersnoei/organ-sync, download code as zip

or 

2) Clone with git: ‘git clone git://github.com/woutersnoei/organ-sync.git’

## Git Repo ##

[github](https://github.com/woutersnoei/organ-sync)

## Starting up ##

- start up SuperCollider
- in SuperCollider, open the ' main.scd' file of this library
- select all and hit shift-enter, or choose Language -> Evaluate File (in recent versions of SuperCollider)

## Basic Usage ##

The program has a graphic interface, and it is generally recommended to use that (although all functionality can also be driven via SuperCollider code).

The main window is named "local_organ". This opens up when the progam is started. It features a list of settings and buttons, more or less in order of what needs to be set and checked to run:
- My Name: the name of your machine/system, as shown to the other users. The program will try to obtain the current system name and fill it in here, but that will only work on macOS. Users can type in any desired system name (be sure it is informative to others) and press enter to set it.
- MIDI In: from this drop down menu users can select a specific MIDI input to which the program should listen. Default option is "all" (self-explanatory). There is also an "off" option, in case the user doesn't want to use MIDI input (for example when generating notes from within SuperCollider)
- Output Mode: OSC or MIDI. If your organ supports MIDI, select MIDI here.
- Output Mode; local thru: enable this if you want to play the local organ yourself from the same midi device. Warning: if this is used with an IAC-bus as output or an organ that sends back the notes it receives, be sure to enable the "prevent feedback" option in the MIDI Mapping window first.
- MIDI Out: this menu is only available in MIDI mode (not OSC), and defines to which MIDI interface the local organ is connected
- Manuals: enter here the number of manuals (including pedals) that your local organ has. This information will be shared with the other participants.
- MIDI Mapping: this will open a second window where the MIDI channel mapping of the local organ can be set. By default the MIDI channels count from 1 to the number of manuals, starting with the pedals. It is also possible to switch off MIDI for certain manuals here, if you don't want others on the network to play them.
- (re)start: if things are not behaving as expected, or cmd-. was (accidentally) hit, press the (re)start button.
- refresh midi: if MIDI devices were dis-/connected use this button to make the program aware of that.

- My ip: the program needs to know it's current IP address on the VPN server to be able to work. This may change every time you (re)connect to the VPN. There is a convenient 'fetch' button, which works on macOS (and possibly also on linux). On other platforms you will need to find out and enter yourself. The address space is assumed to be 192.168.100.nn, as used by the global Hyperorgan Network VPN server. If you are using a differently setup VPN this can be changed in the code file: sync.scd (~vpn_sync.ipRange = ...).
- Remotes; send invites: when everyone on the network has setup the above settings it is time to send invites. Typically everyone on the network would do so, to be sure every organ is connected to every other. The invite system will send a message to every possible ip on the network, containing information about your own ip, name and number of manuals. If such a message is received by another participant, it will automatically reply with a return invite with the same information for that organ. If an invite is received, the 'accept' button will appear, stating the number of invites received. Pressing this button will accept the invitations and add them to your list of remotes. During this process it is wise to have some kind of (chat) contact with all participants to know if everyone is sending and has received invites to all available organs. It's okay to send invites multiple times, as doubles will be detected. If a user has dis/reconnected from the VPN and his/her IP address changed, you will need to delete their current remote from the list and send/get a new invitation. If (mainly for test purposes) you want to manually add a remote, it can be done with the '+' button.

... TO BE CONTINUED ...

## Acknowledgments ##
Organ Sync was developed by Wouter Snoei, with help of Johnty Wang
