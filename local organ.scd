// the local_organ is part of the "vpn_sync" bundle
/*
~local_organ patches the incoming messages of a vpn_sync instance to a MIDI or OSC output, and at the same time pathes *all* local MIDI inputs back to the sync engine. When 'localMode' is enabled it will also patch local incoming MIDI directly to the specified MIDI or OSC outputs.

** warning: if you have IAC MIDI bus(es) setup on your system, make sure not to set 'localMode' to true when the midi output is set to one of these. This will create a MIDI feedback loop (and probably freeze your machine) **
*/

~local_organ = ~local_organ ? ();

~local_organ.safeMode = false;

~local_organ.outputMode = \OSC; // sinua OSC messages for Baroque Organ orgelpark

~local_organ.localMode = false; // only play incoming vpn notes, not local midi-in notes.

/*
~remote = ().proto_( ~vpn_sync );
~local_organ.outputMode = \MIDI;
~local_organ.localMode = true;
*/

~local_organ.midiChannels = [ 0,1,2,3 ]; // pedals, manual 1, 2, 3 (nil = off)

~local_organ.midiOutIndex = 0;

~local_organ.midiInIndex = -1;

~local_organ.preventFeedback = false; // only needed if the manual(s) of the local organ are used as input

~local_organ.auxOSCMIDIChannels = []; //last manuals of OSC will instead send to this MIDI channel


~local_organ[ \numManuals ] = { |evt| evt.midiChannels.size };

~local_organ.numManuals_ = { |evt, n = 4|
	case { evt.numManuals > n } {
		evt.midiChannels = evt.midiChannels[ .. n-1 ];
	} { evt.numManuals < n } {
		evt.midiChannels = evt.midiChannels.addAll( (evt.midiChannels.last ? -1) + (1.. n-evt.numManuals) );
	};
};

// remote channel mapping
~local_organ.remoteChannelMap = Order(); // an Order with nested Orders for custom midi mappings
~local_organ.remoteDeviceMap = Order(); // an Order with nested Orders for custom device mappings

~local_organ.remote_set_midi_channel = { |evt, remoteIndex = 0, manualIndex = 0, midiChannel = 0|
	// midichannel can be 0-15, 'any' or 'off'
	// nil means default channel (manual # == midi channel)
	if( evt.remoteChannelMap[ remoteIndex ].isNil ) {
		evt.remoteChannelMap[ remoteIndex ] = Order();
	};
	if( manualIndex == midiChannel ) {
		evt.remoteChannelMap[ remoteIndex ][ manualIndex ] = nil;
	} {
		evt.remoteChannelMap[ remoteIndex ][ manualIndex ] = midiChannel;
	};
};

~local_organ.remote_get_midi_channel = { |evt, remoteIndex = 0, manualIndex = 0|
	if( evt.remoteChannelMap[ remoteIndex ].notNil ) {
		evt.remoteChannelMap[ remoteIndex ][ manualIndex ] ? manualIndex;
	} {
		manualIndex;
	};
};

~local_organ.remote_get_midi_device = { |evt, remoteIndex = 0, manualIndex = 0|
	if( evt.remoteDeviceMap[ remoteIndex ].notNil ) {
		evt.remoteDeviceMap[ remoteIndex ][ manualIndex ]
	} {
		nil;
	};
};

~local_organ.remote_set_midi_device = { |evt, remoteIndex = 0, manualIndex = 0, deviceIndex|
	if( evt.remoteDeviceMap[ remoteIndex ].isNil ) {
		evt.remoteDeviceMap[ remoteIndex ] = Order();
	};
	evt.remoteDeviceMap[ remoteIndex ][ manualIndex ] = deviceIndex;
};

~local_organ.remote_get_manuals = { |evt, remoteIndex = 0, midiChannel = 0, deviceIndex = 0|
	var manuals, n;
	case { evt.remoteChannelMap[ remoteIndex ].isNil or: { evt.remoteChannelMap[ remoteIndex ].isNil } } {
		manuals = [midiChannel];
	} {
		manuals = evt.remoteChannelMap[ remoteIndex ].select({ |item|
			[ midiChannel, 'any' ].includes( item );
		}).indices;
		if( evt.remoteChannelMap[ remoteIndex ][ midiChannel ].isNil ) {
			manuals = manuals.add( midiChannel );
		};
	};
	n = evt.remote_numManuals( remoteIndex );
	manuals = manuals.select({ |item| item < n; });
	if( evt.remoteDeviceMap[ remoteIndex ].notNil ) {
		manuals = manuals.select({ |item|
			evt.remoteDeviceMap[ remoteIndex ][ item ].isNil or: {
				evt.remoteDeviceMap[ remoteIndex ][ item ] == deviceIndex
			}
		});
	};
	manuals;
};

~local_organ.remote_numManuals = { |evt, index = 0|
	evt.vpnSyncs[index] !? { |x| (x.remote_extraArgs ? [4])[0].asInteger };
};

~local_organ[ \midiChannels_ ] = { |evt, newMIDIChannels|
	var numManuals;
	evt[ \midiChannels ] = newMIDIChannels ? evt[ \midiChannels ];
	numManuals = evt.numManuals;
	~vpn_sync.extraArgs = [numManuals];
	//evt.vpnSyncs.do({ |vpnSync| vpnSync.extraArgs = [numManuals] });
};

~local_organ.midiChannels = ~local_organ.midiChannels; // update once to set ~vpn_sync.extraArgs

~local_organ.setMIDIOut = { |evt, spoof = false|
	if( spoof.not && { MIDIClient.destinations.size > 0 }) {
		evt.midiOut = MIDIOut(
			evt.midiOutIndex.min( MIDIClient.destinations.size-1 )
		).latency_(0);
	} {
		evt.midiOut = ( // create spoof MIDIOut with warnings if no MIDI device detected
			\noteOn: { |evt ...args| "noteOn %: no MIDI device detected\n".postf( args ) },
			\control: { |evt ...args| "control %: no MIDI device detected\n".postf( args ) },
			\sysex: { |evt ...args| "sysex %: no MIDI device detected\n".postf( args ) }
		);
	};
};

~local_organ.getUIDIndex = { |evt, uid|
	MIDIClient.sources.detectIndex({ |item| item.uid == uid });
};

~local_organ.midiInCheckUID = { |evt, uid|
	if( evt.midiInIndex < 0 ) {
		true
	} {
		MIDIClient.sources[ evt.midiInIndex ] !? { |x| x.uid == uid } ? false;
	};
};

~local_organ.noteInTrackers = Order();
~local_organ.noteOutTracker = ().proto_( ~note_tracker );
~local_organ.messageSendTracker = ();
~local_organ.messageReceiveTracker = ();
~local_organ.feedbackTracker = ().proto_( ~midi_feedback_filter );

~local_organ.noteInTrackerAddNote = { |evt, chan, nn, velo, uid|
	if( evt.noteInTrackers[ uid ].isNil ) {
		 evt.noteInTrackers[ uid ] = ().proto_( ~note_tracker );
	};
	evt.noteInTrackers[ uid ].addNote( chan, nn, velo );
};

~local_organ.noteInTrackerActiveNotes = { |evt|
	var notes = [];
	evt.noteInTrackers.do({ |item, uid|
		item.activeNotes.do({ |note|
			notes = notes.add( note.add( uid ) );
		});
	});
	notes;
};

~local_organ.noteInTrackerActiveNotesFor = { |evt, which = 0|
	var notesFor = [];
	evt.noteInTrackerActiveNotes.do({ |note|
		evt.remote_get_manuals( which, note[0].asInteger, evt.getUIDIndex( note[3] ) ).do({ |manual|
				notesFor = notesFor.add( [ manual ].addAll( note[1..] ) );
			});
	});
	notesFor;
};

~local_organ.sendLocalNote = { |evt, manual = 0, nn = 64, velo = 127| // nn can be Array
	var chan, auxChan;
	chan = evt.midiChannels[ manual ];
	switch( evt.outputMode,
		\OSC, {
			auxChan = evt.auxOSCMIDIChannels[ manual - evt.numManuals + (evt.auxOSCMIDIChannels.size) ];
			if( auxChan.postln.notNil ) {
				if( nn.isArray ) {
					nn.do({ |nx|
						evt.midiOut.noteOn( auxChan, nx, velo );
					});
				} {
					evt.midiOut.noteOn( auxChan, nn, velo );
				};
			} {
				~bo.note( manual, nil, nn, velo );
			};
		},
		\MIDI, {
			if( chan.notNil ) {
				if( nn.isArray ) {
					nn.do({ |nx|
						evt.midiOut.noteOn( chan, nx, velo );
					});
				} {
					evt.midiOut.noteOn( chan, nn, velo );
				};
			};
		}
	);
	if( chan.notNil && { evt.preventFeedback } ) {
		evt.feedbackTracker.addNote( manual, nn, velo );
	};
	evt.noteOutTracker.addNote( manual, nn, velo );
};

~local_organ.sendLocalCC = { |evt, chan = 0, cc = 0, val = 64|
	switch( evt.outputMode,
		\OSC, {
			switch( cc.asInteger,
				// mimicks Orgelpark MIDI to OSC max patch
				1, {
					~bo.tremolo( 'ow', nil, val.linexp(0,127,0.005,12) );
				},
				2, {
					~bo.tremolo( 'ow', val.inclusivelyBetween(1,126), nil, val / 127 );
				},
				3, {
					~bo.tremolo( 'hw', nil, val.linexp(0,127,0.005,12) );
				},
				4, {
					~bo.tremolo( 'hw', val.inclusivelyBetween(1,126), nil, val / 127 );
				},
				5, {
					~bo.motorSpeed( val / 127 );
				},
				6, {
					~bo.crescendo( val / 127 );
				},
				7, {
					~bo.swell( val / 127 );
				}
			);
		},
		\MIDI, {
			evt.midiOut.control( chan, cc, val );
		}
	);
};

~local_organ.sendLocalSysEx = { |evt, packet|
	switch( evt.outputMode,
		\OSC, {
			"OSC: sysex not supported".postln;
		},
		\MIDI, {
			evt.midiOut.sysex( packet );
		}
	);
};

~local_organ.localEndActiveNotes = { |evt| // ends currently tracked notes on local organ
	evt.noteOutTracker.activeNotes.do({ |note|
		evt.sendLocalNote( note[0], note[1], 0 );
	});
};

~local_organ.localEndAllNotes = { |evt| // "panic"
	evt.numManuals.do({ |manual|
		evt.sendLocalNote( manual, (1..127), 0 );
	});
};

~local_organ.remoteEndActiveNotes = { |evt| // ends all remote notes based on midi input
	evt.noteInTrackerActiveNotes.do({ |note|
		evt.sendMappedRemoteNote( note[0], note[1], 0, note[3] );
		evt.noteInTrackerAddNote( note[0], note[1], 0, note[3] );
	});
};

~local_organ.sendMappedRemoteNote = { |evt, midiChannel = 0, nn = 64, velo = 127, uid = 0, index|
	index = index ?? { evt.getUIDIndex( uid ); };
	evt.vpnSyncs.do({ |vpnSync, i|
		var manuals;
		manuals = evt.remote_get_manuals( i, midiChannel.asInteger, index );
		manuals.do({ |manual|
			evt.sendRemoteNote( manual, nn, velo, i )
		});
	});
};

~local_organ.sendRemoteNote = { |evt, manual = 0, nn = 64, velo = 127, which = \all|
	evt.sendRemote( evt.makeRemoteNote( manual, nn, velo ), which );
	if( evt.safeMode == true && { velo == 0 }) { // safe mode
		evt.sendRemote( evt.makeRemoteNote( manual, nn, velo ), which );
	};
};

~local_organ.makeRemoteNote = { |evt, manual = 0, nn = 64, velo = 127|
	[ "note", manual, nn, velo ]
};

~local_organ.sendRemoteCC = { |evt, chan = 0, cc = 0, val = 64, which = \all|
	evt.sendRemote( evt.makeRemoteCC( chan, cc, val ), which );
};

~local_organ.makeRemoteCC = { |evt, chan = 0, cc = 0, val = 64|
	[ "cc", chan, cc, val ]
};

~local_organ.sendRemoteSysEx = { |evt, packet, which = \all|
	evt.sendRemote( evt.makeRemoteSysEx( packet ), which );
};

~local_organ.makeRemoteSysEx = { |evt, packet|
	[ "sysex", packet ]
};


~local_organ.sendRemote = { |evt, msg, which = \all|
	var res;
	case { which === \all } {
		res = evt.vpnSyncs.do({ |vpn_sync|
			evt.messageSendTracker[ vpn_sync ] = Process.elapsedTime;
			vpn_sync.sendMsg( *msg );
		});
	} { which.isNumber } {
		res = evt.vpnSyncs.wrapAt( which );
		evt.messageSendTracker[ res ] = Process.elapsedTime;
		res.sendMsg( *msg );
		res;
	} { which.isKindOf( String ) } {
		res = evt.vpnSyncs.select({ |item| item.remoteName.find( which ).notNil }).do({ |vpn_sync|
			evt.messageSendTracker[ vpn_sync ] = Process.elapsedTime;
			vpn_sync.sendMsg( *msg );
		})
	} { which.isArray } { // allow nested operation
		res = which.do({ |item|
			evt.sendRemote( msg, item );
		})
	};
	res;
};

~local_organ.recvInvite = { |evt, from, to, name, numManuals|
	evt.invites = evt.invites.add( [from, to, name, numManuals] );
};

~local_organ.acceptInvites = { |evt|
	evt.invites.do({ |invite|
		evt.addRemote( invite[0], invite[2], invite[3] );
		if( ~vpn_sync.myID != invite[1]) {
			 ~vpn_sync.myID = invite[1];
			 "changed my ip to: % (based on invite(s))\n".postf( invite[1] );
		};
	});
	evt.invites = [];
};

~local_organ.setRecvInviteAction = { |evt|
	~vpn_sync[ \recvInviteAction ] = { |from, to, name, numManuals|
		evt.recvInvite( from, to, name, numManuals );
	};
};

~local_organ.addVPNSync = { |evt, vpnSync|
	if( vpnSync.notNil and: (evt.vpnSyncs.isNil or: { evt.vpnSyncs.includes( vpnSync ).not })) {
		evt.vpnSyncs = evt.vpnSyncs.add( vpnSync );
	};
	evt.updateVPNActions;
};

~local_organ.addRemote = { |evt, id = 39, name, numManuals = 4|
	var vpnSync;
	id = id.asInteger;
	vpnSync = evt.vpnSyncs.detect({ |x| x.remoteID == id });
	if( vpnSync.isNil ) {
		vpnSync = ().proto_( ~vpn_sync );
		vpnSync.remoteID_( id );
		//vpnSync.extraArgs = [ evt.numManuals ];
		evt.vpnSyncs = evt.vpnSyncs.add( vpnSync );
	} {
		"remote id % already added, updating name and specs\n".postf( id );
	};
	vpnSync.remote_extraArgs_( [ numManuals ] );
	vpnSync.remoteName = name ?? { "remote %".format( evt.vpnSyncs.size ); };
	evt.updateVPNActions;
};

~local_organ.removeVPNSync = { |evt, vpnSync|
	if( vpnSync.notNil and: (evt.vpnSyncs.isNil or: { evt.vpnSyncs.includes( vpnSync ) })) {
		evt.vpnSyncs.remove( vpnSync );
	};
	evt.updateVPNActions;
};

~local_organ.vpnActions = (
	\note: { |evt ...args| evt.sendLocalNote( *args[1..] ) },
	\cc: { |evt ...args| evt.sendLocalCC( *args[1..] ) },
	\sysex: { |evt ...args| evt.sendLocalSysEx( args[1] ) },
);

~local_organ.doVPNAction = { |evt ...args|
	evt.vpnActions[ args[0].asSymbol ].value( evt, *args );
};

~local_organ.updateVPNActions = { |evt|
	evt.vpnSyncs.do({ |vpnSync|
		vpnSync.action = { |msg|
			evt.messageReceiveTracker[ vpnSync ] = Process.elapsedTime;
			evt.doVPNAction( *msg );
		};
	});
	evt.makeMIDIOuts;
};

~local_organ.makeMIDIFuncs = { |evt|
	MIDIIn.connectAll;
	evt.midiFuncs.do(_.free);
	evt.midiFuncs = [
		MIDIFunc.noteOn({ |vel, num, chan, uid|
			if( evt.midiInCheckUID( uid ) ) {
				if( evt.preventFeedback.not or: { evt.feedbackTracker.filter( chan, num, vel ) } ) {
					if( evt.localMode == true ) {
						evt.sendLocalNote( chan, num, vel );
					};
					evt.sendMappedRemoteNote( chan, num, vel, uid );
					evt.noteInTrackerAddNote( chan, num, vel, uid );
				};
			}
		}),
		MIDIFunc.noteOff({ |vel, num, chan, uid|
			if( evt.midiInCheckUID( uid ) ) {
				if( evt.preventFeedback.not or: { evt.feedbackTracker.filter( chan, num, 0 ) } ) {
					if( evt.localMode == true ) {
						evt.sendLocalNote( chan, num, 0 );
					};
					evt.sendMappedRemoteNote( chan, num, 0, uid );
					evt.noteInTrackerAddNote( chan, num, 0, uid );
				};
			};
		}),
		MIDIFunc.cc({ |val, num, chan, uid|
			if( evt.midiInCheckUID( uid ) ) {
				if( evt.localMode == true ) {
					evt.sendLocalCC( chan, num, val );
				};
				evt.sendRemoteCC( chan, num, val );
				//evt.sendMappedRemoteNote( chan, num, 0, uid );
			};
		}),
		MIDIFunc.sysex({ |packet, uid|
			if( evt.midiInCheckUID( uid ) ) {
				if( evt.localMode == true ) {
					evt.sendLocalSysEx( packet );
				};
				evt.sendRemoteSysEx( packet );
				//evt.sendMappedRemoteNote( chan, num, 0, uid );
			};
		}),
	];
};

~local_organ.start = { |evt|
	~local_organ.setRecvInviteAction;
	~vpn_sync.makeRecvInviteFuncs;
	~local_organ.makeMIDIFuncs;
	~local_organ.setMIDIOut;
};

~local_organ.startRemotes = { |evt|
	evt.vpnSyncs.do(_.makeOSCFuncs);
};

//~local_organ.addVPNSync( ~remote );

/*
~local_organ.makeMIDIFuncs;

~local_organ.setMIDIOut;
*/

~local_organ.start;



