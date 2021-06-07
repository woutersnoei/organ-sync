~local_organ.makeMIDIOuts = { |evt, replace = false|
	// creates spoof MIDI out objects per organ (can call noteOn and noteOff)
	// to be used in Pbind (for example)
	// access via:
	//  ~local_organ.m; // midi out for local organ (also in OSC mode)
	//  ~local_organ.rm; // array of midiOuts for remotes
	// - midi channel = manual # (P = channel 0)
	// - will give warning if playing non-existing manual
	// - the rm midiOuts have internal note trackers, to enable 'allNotesOff'
	var env, makeM, rmCopy;
	env = currentEnvironment;
	makeM = { |vpnSync, i|
		var m, numManuals;
		m = ();
		m.numManuals = evt.remote_numManuals(i);
		m.vpnSync = vpnSync;
		m.noteTracker = ().proto_(~note_tracker);
		m.index = i;
		m.noteOn = { |mm, chan = 0, note=60, veloc=64|
			if( chan < mm.numManuals ) {
				env.use({
					evt.sendRemoteNote( chan, note, veloc, m.index );
				});
				mm.noteTracker.addNote( chan, note, veloc );
			} {
				"tried to play note on non-existing manual (%) of remote %\n".postf( 
					chan, (i+65).asAscii
				);
			};
			mm;
		};
		m.noteOff = { |mm, chan = 0, note=60, veloc=64|
			if( chan < mm.numManuals ) {
				env.use({
					evt.sendRemoteNote( chan, note, 0, m.index );
				});
				mm.noteTracker.addNote( chan, note, 0 );
			} {
				"tried to end note on non-existing manual (%) of remote %\n".postf( 
					chan, (i+65).asAscii
				);
			};
			mm;
		};
		m.allNotesOff = { |mm|
			mm.noteTracker.activeNotes.do({ |note|
				mm.noteOff( note[0], note[1] );
			});
			mm;
		};
		m;
	};
	if( replace or: {evt.rm.isNil}) {
		evt.rm = evt.vpnSyncs.collect({ |vpnSync, i| makeM.( vpnSync, i ) });
	} {
		rmCopy = evt.rm;
		evt.rm = evt.vpnSyncs.collect({ |vpnSync, i|
			var m;
			if( (m = rmCopy.detect({ |item| item.vpnSync === vpnSync })).notNil ) {
				m.index_( i ).numManuals_( evt.remote_numManuals(i) );
			} {
				m = makeM.( vpnSync, i );
			};
			m;
		});
	};
	if( replace or: { evt.m.isNil }) {	
		evt.m = (
			numManuals: evt.numManuals,
			noteOn: { |mm, chan=0, note=60, veloc=64|
				if( chan < mm.numManuals ) {
					env.use({ evt.sendLocalNote( chan, note, veloc ); });
				} {
					"tried to play note on non-existing manual of local\n".postf();
				};
				mm;
			},
			noteOff: { |mm, chan=0, note=60, veloc=64|
				if( chan < mm.numManuals ) {
					env.use({ evt.sendLocalNote( chan, note, 0 ); });
				} {
					"tried to play note on non-existing manual of local\n".postf();
				};
				mm;
			},
			allNotesOff: { |mm|
				env.use({ evt.localEndActiveNotes; });
				mm;
			},
		);
	} {
		evt.m.numManuals = evt.numManuals;
	};
};

~local_organ.midiOuts = { |evt| [ evt.m ].addAll( evt.rm ) };

~local_organ.makeMIDIOuts; // call again after adding/removing remote

/*
~local_organ.rm[0].noteOn(0,64,127); // send note to first remote
~local_organ.rm[0].allNotesOff; // convenience method

~local_organ.m.noteOn(0,64,127); // send note to local organ
~local_organ.m.allNotesOff;

(
// pedal sweep
a = Pbind(
	\type, \midi,
	\chan, 0,
	\midiout, ~local_organ.m, // local organ, ~local_organ.rm[0] for first remote
	\midinote, Pseq( (43..54), 1 ),
	\legato, 2,
	\dur, 0.05
).play;
)
*/

