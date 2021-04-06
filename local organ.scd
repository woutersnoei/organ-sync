// the local_organ is part of the "vpn_sync" bundle
/*
~local_organ patches the incoming messages of a vpn_sync instance to a MIDI or OSC output, and at the same time pathes *all* local MIDI inputs back to the sync engine. When 'localMode' is enabled it will also patch local incoming MIDI directly to the specified MIDI or OSC outputs.

** warning: if you have IAC MIDI bus(es) setup on your system, make sure not to set 'localMode' to true when the midi output is set to one of these. This will create a MIDI feedback loop (and probably freeze your machine) **
*/

~local_organ = ~local_organ ? ();

~local_organ.outputMode = \OSC; // sinua OSC messages for Baroque Organ orgelpark

~local_organ.localMode = false; // only play incoming vpn notes, not local midi-in notes.

/*
~remote = ().proto_( ~vpn_sync );
~local_organ.outputMode = \MIDI;
~local_organ.localMode = true;
*/

~local_organ.midiChannels = [ 0,1,2,3 ]; // pedals, manual 1, 2, 3

~local_organ.midiOutIndex = 0;

~local_organ.midiInIndex = -1;

~local_organ.setMIDIOut = { |evt|
	evt.midiOut = MIDIOut(
		evt.midiOutIndex.min( MIDIClient.destinations.size-1 )
	).latency_(0);
};

~local_organ.midiInCheckUID = { |evt, uid|
	if( evt.midiInIndex < 0 ) {
		true
	} {
		MIDIClient.sources[ evt.midiInIndex ] !? { |x| x.uid == uid } ? false;
	};
};

~local_organ.noteInTracker = ().proto_( ~note_tracker );
~local_organ.noteOutTracker = ().proto_( ~note_tracker );

~local_organ.sendLocalNote = { |evt, manual = 0, nn = 64, velo = 127|
	switch( evt.outputMode,
		\OSC, {
			~bo.note( manual, nil, nn, velo );
		},
		\MIDI, {
			evt.midiOut.noteOn( evt.midiChannels[ manual ], nn, velo );
		}
	);
	evt.noteOutTracker.addNote( manual, nn, velo );
};

~local_organ.sendRemoteNote = { |evt, manual = 0, nn = 64, velo = 127, which = \all|
	evt.sendRemote( evt.makeRemoteNote( manual, nn, velo ), which );
};

~local_organ.makeRemoteNote = { |evt, manual = 0, nn = 64, velo = 127|
	[ "note", manual, nn, velo ]
};

~local_organ.sendRemote = { |evt, msg, which = \all|
	case { which === \all } {
	} {
		evt.vpnSyncs.do({ |vpn_sync|
			vpn_sync.sendMsg( *msg );
		});
	} { which.isNumber } {
		evt.vpnSyncs.wrapAt( which ).sendMsg( *msg );
	};
};

~local_organ.recvInvite = { |evt, from, to, name|
	evt.invites = evt.invites.add( [from, to, name] );
};

~local_organ.acceptInvites = { |evt|
	evt.invites.do({ |invite|
		evt.addRemote( invite[0], invite[2] );
		if( ~vpn_sync.myID != invite[1]) {
			 ~vpn_sync.myID = invite[1];
			 "changed my ip to: % (based on invite(s))\n".postf( invite[1] );
		};
	});
	evt.invites = [];
};

~local_organ.setRecvInviteAction = { |evt|
	~vpn_sync[ \recvInviteAction ] = { |from, to, name|
		evt.recvInvite( from, to, name );
	};
};

~local_organ.addVPNSync = { |evt, vpnSync|
	if( vpnSync.notNil and: (evt.vpnSyncs.isNil or: { evt.vpnSyncs.includes( vpnSync ).not })) {
		evt.vpnSyncs = evt.vpnSyncs.add( vpnSync );
	};
	evt.updateVPNActions;
};

~local_organ.addRemote = { |evt, id = 39, name|
	var vpnSync;
	id = id.asInteger;
	if( evt.vpnSyncs.isNil or: { evt.vpnSyncs.any({ |x| x.remoteID == id }).not }) {
		vpnSync = ().proto_( ~vpn_sync );
		vpnSync.remoteID_( id );
		vpnSync.remoteName = name ?? { "remote %".format( evt.vpnSyncs.size ); };
		evt.vpnSyncs = evt.vpnSyncs.add( vpnSync );
		evt.updateVPNActions;
	} {
		"remote id % already added\n".postf( id );
	};
};

~local_organ.removeVPNSync = { |evt, vpnSync|
	if( vpnSync.notNil and: (evt.vpnSyncs.isNil or: { evt.vpnSyncs.includes( vpnSync ) })) {
		evt.vpnSyncs.remove( vpnSync );
	};
	evt.updateVPNActions;
};

~local_organ.doVPNAction = { |evt ...args|
	switch( args[0].asSymbol,
		\note, { evt.sendLocalNote( *args[1..] ) },
		// add more options (registers etc.) later
	);
};

~local_organ.updateVPNActions = { |evt|
	evt.vpnSyncs.do({ |vpnSync|
		vpnSync.action = { |msg| evt.doVPNAction( *msg ) };
	});
};

~local_organ.makeMIDIFuncs = { |evt|
	MIDIIn.connectAll;
	evt.midiFuncs.do(_.free);
	evt.midiFuncs = [
		MIDIFunc.noteOn({ |vel, num, chan, uid|
			if( evt.midiInCheckUID( uid ) ) {
				if( evt.localMode == true ) {
					evt.sendLocalNote( chan, num, vel );
				};
				evt.sendRemoteNote( chan, num, vel );
				evt.noteInTracker.addNote( chan, num, vel );
			}
		}),
		MIDIFunc.noteOff({ |vel, num, chan, uid|
			if( evt.midiInCheckUID( uid ) ) {
				if( evt.localMode == true ) {
					evt.sendLocalNote( chan, num, 0 );
				};
				evt.sendRemoteNote( chan, num, 0 );
				evt.noteInTracker.addNote( chan, num, 0 );
			};
		})
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



