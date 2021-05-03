~note_tracker = ~note_tracker ? ();

~note_tracker.addNote = { |evt, chan, num, vel|
	if( evt.notes.isNil ) { evt.resetNotes }; // create note lib
	evt.notes[ chan ][ num ] = vel;
};

~note_tracker.resetNotes = { |evt|
	 evt.notes = { Order() }!16;
};

~note_tracker.activeNotes = { |evt|
	var active;
	evt.notes.do({ |item, chan|
		item.do({ |vel, num| if( vel > 0 ) { active = active.add( [ chan, num, vel ] ) } });
	});
	active;
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