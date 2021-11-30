~note_tracker = ~note_tracker ? ();

~note_tracker.mode = \loose; // or \strict

/*
~note_tracker.mode = \strict;
*/

~note_tracker.addNote = { |evt, chan, num, vel|
	if( evt.notes.isNil ) { evt.resetNotes }; // create note lib
	if( num.isArray ) {
		num.do({ |nx|
			evt.addNote( chan, nx, vel );
		})
	} {
		if( evt.mode === \loose ) {
			evt.notes[ chan ][ num ] = vel;
		} {	
			if( vel == 0 ) { vel = -1 } { vel = 1 };
			evt.notes[ chan ][ num ] = ((evt.notes[ chan ][ num ] ? 0) + vel).max(0);
		};
	}
};

~note_tracker.resetNotes = { |evt|
	 evt.notes = { Order() }!16;
};

~note_tracker.activeNotes = { |evt|
	var active;
	evt.notes.do({ |item, chan|
		if( evt.mode === \loose ) {
			item.do({ |vel, num| if( vel > 0 ) { active = active.add( [ chan, num, vel ] ) } });
		} {
			item.do({ |n, num|
				if( n > 0 ) { 
					n.do({
						active = active.add( [ chan, num, 127 ] ) 
					});
				} 
		});
		}
	});
	active;
};

~midi_feedback_filter = ~midi_feedback_filter ? ();

~midi_feedback_filter.addNote = { |evt, chan, num, vel|
	if( evt.notes.isNil ) { evt.resetNotes }; // create note lib
	if( num.isArray ) {
		num.do({ |nx|
			evt.addNote( chan, nx, vel );
		})
	} {
		evt.notes = evt.notes.add( [chan.asInteger, num.asInteger, vel.asInteger > 0] );
	};
};

~midi_feedback_filter.resetNotes = { |evt|
	 evt.notes = [];
};

~midi_feedback_filter.filter = { |evt, chan, num, vel|
	var index;
	index = (evt.notes ? []).detectIndex({ |item| item == [ chan.asInteger, num.asInteger, vel.asInteger > 0 ] });
	if( index.notNil ) {
		evt.notes.removeAt( index );
		false;
	} {
		true;
	};
};

/*

~nt = ().proto_( ~note_tracker );

~nt.addNote( 0, 67, 127 );

~nt.notes[0].do({ |item, i| if( item > 0 ) { [ i, item ].postln } });

{ 10000.do{ ~nt.activeNotes.size } }.bench
{ 10000.do{ ~nt.countNotes } }.bench

~note_tracker.resetNotes

~nt.notes.collect({ |item| item.count( _ > 0 ) ? 0 }).sum;


.count( _ > 0 )
~nt[ \addNote ]
*/