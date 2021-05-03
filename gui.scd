// GUI

~vpn_sync.makeWindow = { |evt|
	var makeLabel, updateViews, skipJack, win;
	if( evt.window.notNil && { evt.window.isClosed.not }) { evt.window.close };
	evt.window = Window( evt.remoteName,
		Rect(127 + 50.rand, 294 + 50.rand, 324, 179)
	).front;
	evt.window.addFlowLayout;
	win = evt.window;
	evt.views = ();
	makeLabel = { |name, newLine = true|
		if( newLine == true ) { evt.window.asView.decorator.nextLine; };
		StaticText( evt.window, 100@20 ).string_( name ++ " " ).align_( \right );
	};
	makeLabel.( "enable", false );
	evt.views[ \send ] = Button( evt.window, 50@20 ).states_([
			["send", Color.black, Color.red.alpha_(2/3)],
			["send", Color.black, Color.green.alpha_(2/3)],
		])
		.action_({ |bt|
			switch( bt.value,
				1, { evt.send = true },
				0, { evt.send = false }
			)
		});
	evt.views[ \receive ] = Button( evt.window, 46@20 ).states_([
			["receive", Color.black, Color.red.alpha_(2/3)],
			["receive", Color.black, Color.green.alpha_(2/3)],
		])
		.action_({ |bt|
			switch( bt.value,
				1, { evt.receive = true },
				0, { evt.receive = false }
			)
		});
	evt.views[ \restart ] = Button( evt.window, 100@20 ).states_([
			["(re)start"]
		])
		.action_({ |bt|
		 	evt.makeOSCFuncs; // cmd-. to cancel
		});
	/*
	makeLabel.( "my ip", true );
	StaticText( evt.window, 72@20 ).string_( evt.ipRange.split($.)[..2].join($.) ++ "." );
	evt.views[ \myIP ] = NumberBox( evt.window, 24@20 ).clipLo_(1).clipHi_(255)
		.action_({ |tf|
			~vpn_sync.myID = tf.value;
		});
	Button( evt.window, 100@20 ).states_([
			["fetch"]
		])
		.action_({ |bt|
		 	evt.fetchMyID; // cmd-. to cancel
		});
	*/
	makeLabel.( "remote ip", true );
	StaticText( evt.window, 72@20 ).string_( evt.ipRange.split($.)[..2].join($.) ++ "." );
	evt.views[ \addr ] = NumberBox( evt.window, 24@20 ).clipLo_(1).clipHi_(255)
		.action_({ |tf|
			evt.makeRemoteAddr( tf.value );
		});
	makeLabel.( "latency" );
	evt.views[ \latency ] = NumberBox( evt.window, 100@20 )
		.action_({ |box| evt.latency = box.value; })
		.step_( 0.05 )
		.scroll_step_( 0.05 );
		//.value_( evt.latency );
	evt.views[ \latency_use ] = Button( evt.window, 100@20 ).states_([["use advised"]])
		.action_({ |bt|
			var lt;
			lt = evt.calcLatency;
			if( lt.notNil ) { evt.views.latency.valueAction = lt };
		});
	makeLabel.( "" );
	evt.views[ \port_default ] = Button( evt.window, 50@20 ).states_([["ping"]])
		.action_({ |bt| evt.ping });
	evt.views[ \ping_received ] = StaticText( evt.window, 46@20 );
	evt.views[ \reset] = Button( evt.window, 100@20 ).states_([["reset"]])
		.action_({ |bt|
			evt.resetMeasurements;
			evt.pingReplyReceived = nil;
		});
	makeLabel.( "avg. RT time:" );
	evt.views[ \rt_time ] = StaticText( evt.window, 50@20 );
	Button( evt.window, 46@20 ).states_([["plot"]])
		.action_({ evt.calcRT( true, true ) });
	makeLabel.( "advised latency:" );
	evt.views[ \advised_latency ] = StaticText( evt.window, 50@20 );
	Button( evt.window, 46@20 ).states_([["plot"]])
		.action_({ evt.calcLatency( true, true ) });
	evt.views[ \verbose ] = Button( evt.window, 100@20 ).states_([
			["verbose", Color.black, Color.red.alpha_(2/3)],
			["verbose", Color.black, Color.green.alpha_(2/3)],
		])
		.action_({ |bt|
			switch( bt.value,
				1, { evt.verbose = true },
				0, { evt.verbose = false }
			)
		});
	updateViews = {
		evt.views[ \send ].value = evt.send.binaryValue;
		evt.views[ \receive ].value = evt.receive.binaryValue;
		evt.views[ \verbose ].value = evt.verbose.binaryValue;
		if( evt.views[ \addr ].hasFocus.not ) {
			evt.views[ \addr ].value = evt.remoteAddr.ip.split($.).last.interpret;
		};
		//evt.views[ \port ].value = evt.remoteAddr.port;
		/*
		if( evt.views[ \myIP ].hasFocus.not ) {
			evt.views[ \myIP ].value = evt.myID;
		};
		*/
		evt.views[ \latency ].value = evt.latency;
		evt.views[ \ping_received ].background_(
			switch( evt.pingReplyReceived,
				true, { Color.green.alpha_(2/3) },
				false, { Color.red.alpha_(2/3) },
				{ Color.clear }
			)
		);
		evt.views[ \rt_time ].string = "%".format( evt.calcRT( false, false ) ? "-" );
		evt.views[ \advised_latency ].string = "%".format( evt.calcLatency( false, false ) ? "-" );
		//"updating views".postln;
	};
	updateViews.value;
	skipJack = SkipJack( updateViews, 0.5, { win.isClosed });
};

~vpn_sync.closeWindow = { |evt|
	if( evt.window.notNil && { evt.window.isClosed.not }) { evt.window.close };
};

//~vpn_sync.makeWindow;


~local_organ.makeWindow = { |evt|
	var makeLabel, updateViews, skipJack, win, fillMIDIOuts, fillMIDIIns;
	var bounds;
	if( evt.window.notNil && { evt.window.isClosed.not }) { 
		bounds = evt.window.bounds;
		evt.window.close;
	};
	evt.window = Window( 
		currentEnvironment.findKeyForValue( evt ),
		bounds ? Rect(600, 394, 324, 279)
	).front;
	evt.window.addFlowLayout;
	win = evt.window;
	evt.views = ();
	makeLabel = { |name, newLine = true, width = 100|
		if( newLine == true ) { evt.window.asView.decorator.nextLine; };
		StaticText( evt.window, width@20 ).string_( name ++ " " ).align_( \right );
	};
	makeLabel.( "My Name", true );
	evt.views[\myName] = TextField( win, 204@20 )
		.string_( ~vpn_sync.myName )
		.action_({ |tb|
			 ~vpn_sync.myName = tb.string;
		});
	makeLabel.( "MIDI In" );
	evt.views[\midiin] = PopUpMenu( win, 204@20 ).action_({ |pu|
			evt.midiInIndex = pu.value - 1;
		});
	makeLabel.( "Output mode" );
	evt.views[\mode] = PopUpMenu( win, 100@20 )
		.items_( [ 'MIDI', 'OSC' ] )
		.action_({ |pu| evt.outputMode = pu.item });
	evt.views[ \local ] = Button( evt.window, 100@20 ).states_([
			["local thru", Color.black, Color.red.alpha_(2/3)],
			["local thru", Color.black, Color.green.alpha_(2/3)],
		])
		.action_({ |bt|
			switch( bt.value,
				1, { evt.localMode = true },
				0, { evt.localMode = false }
			)
		});
	makeLabel.( "MIDI Out" );
	evt.views[\midiout] = PopUpMenu( win, 204@20 ).action_({ |pu|
			evt.midiOutIndex = pu.value;
			evt.setMIDIOut;
		});
	makeLabel.( "Manuals" );	
	evt.views[ \n_manuals ] = NumberBox( evt.window, 24@20 ).clipLo_(1).clipHi_(16)
		.action_({ |tf|
			evt.numManuals = tf.value.asInteger;
			evt.makeMIDIChannelsWindow( true );
		});
	Button( evt.window, 20@20 )
		.states_([["^"]])
		.action_({ 
			evt.views[ \n_manuals ].valueAction = evt.views[ \n_manuals ].value + 1;
		});
	Button( evt.window, 20@20 )
		.states_([["v"]])
		.action_({
			evt.views[ \n_manuals ].valueAction = evt.views[ \n_manuals ].value - 1;
		});
	evt.window.asView.decorator.shift(28,0);
	Button( evt.window, 100@20 )
		.states_([["MIDI Mapping"]])
		.action_({
			evt.makeMIDIChannelsWindow( );
		});
	makeLabel.( "" );
	evt.views[ \restart ] = Button( evt.window, 100@20 )
		.states_([["(re)start"]])
		.action_({ |bt|
			evt.start;

		});
	evt.views[ \restart ] = Button( evt.window, 100@20 )
		.states_([["refresh midi"]])
		.action_({ |bt|
			MIDIClient.init;
			evt.makeMIDIFuncs;
			evt.setMIDIOut;
			fillMIDIOuts.value;
			fillMIDIIns.value;
		});
	fillMIDIOuts = {
		evt.views[\midiout].items_( MIDIClient.destinations.collect({ |item|
			"% : %".format( item.device, item.name )
		}) )
	};
	fillMIDIIns = {
		evt.views[\midiin].items_( ["all"] ++ MIDIClient.sources.collect({ |item|
			"% : %".format( item.device, item.name )
		}) )
	};
	makeLabel.( "", true );
	makeLabel.( "My ip", true );
	StaticText( evt.window, 72@20 ).string_( ~vpn_sync.ipRange.split($.)[..2].join($.) ++ "." );
	evt.views[ \myIP ] = NumberBox( evt.window, 24@20 ).clipLo_(1).clipHi_(255)
		.action_({ |tf|
			~vpn_sync.myID = tf.value;
		});
	Button( evt.window, 100@20 ).states_([
			["fetch"]
		])
		.action_({ |bt|
		 	~vpn_sync.fetchMyID; // cmd-. to cancel
		});
	makeLabel.("Remotes");
	Button( evt.window, 100@20 )
		.states_([["send invites"]])
		.action_({
			~vpn_sync.sendInvites;
		});
	evt.views[ \accept ] = Button( evt.window, 100@20 )
		.states_([["accept (0)"]])
		.action_({
			~local_organ.acceptInvites;
			~local_organ.startRemotes;
			{ evt.makeWindow; }.defer(0.2);
		});
	evt.vpnSyncs.do({ |vpnSync, i|
		makeLabel.( (i+65).asAscii.asString );
		Button( evt.window, 208@20 )
			.states_([[ "%: %".format( vpnSync.remoteID, vpnSync.remoteName ) ]] )
			.action_({ vpnSync.makeWindow });
		Button( evt.window, 20@20 )
		.states_([["x", Color.red(0.5)]])
		.action_({
			vpnSync.endOSCFuncs;
			vpnSync.closeWindow;
			evt.removeVPNSync( vpnSync );
			//newRemote.makeOSCFuncs;
			evt.makeWindow;
		});
		Button( evt.window, 20@20 )
			.states_([["^"]])
			.action_({
				evt.vpnSyncs.remove( vpnSync );
				evt.vpnSyncs.insert( i-1, vpnSync );
				evt.makeWindow;
			})
			.visible_( i!=0 );
		Button( evt.window, 20@20 )
			.states_([["v"]])
			.action_({
				evt.vpnSyncs.remove( vpnSync );
				evt.vpnSyncs.insert( i+1, vpnSync );
				evt.makeWindow;
			})
			.visible_( i < (evt.vpnSyncs.size - 1) );
	});
	makeLabel.( "" );
	Button( evt.window, 20@20 )
		.states_([["+"]])
		.action_({
			var newRemote;
			newRemote = ().proto_( ~vpn_sync );
			newRemote.remoteName = "remote %".format( evt.vpnSyncs.size );
			evt.addVPNSync( newRemote );
			//newRemote.makeOSCFuncs;
			evt.makeWindow;
		});	
	makeLabel.( "note tracker" );
	evt.views[ \noteTracker ] = StaticText( evt.window, 100@20 );
	fillMIDIOuts.value;
	fillMIDIIns.value;
	updateViews = {
		evt.views[ \mode ].value = evt.views[ \mode ].items.indexOf( evt.outputMode );
		evt.views[ \local ].value =  evt.localMode.binaryValue;
		evt.views[\midiin].value = evt.midiInIndex + 1;
		evt.views[\midiout].value =
			MIDIClient.destinations.detectIndex({ |item| item.uid == evt.midiOut.uid });
		evt.views[\midiout].enabled_( evt.outputMode == 'MIDI'  );
		if( evt.views[ \myIP ].hasFocus.not ) {
			evt.views[ \myIP ].value = ~vpn_sync.myID;
		};
		if( evt.views[ \n_manuals ].hasFocus.not ) {
			evt.views[ \n_manuals ].value = evt.numManuals;
		};
		if( evt.invites.size > 0 ) {
			evt.views[ \accept ].visible_( true );
			evt.views[ \accept ].states_([["accept (%)".format( evt.invites.size ) ]]);
		} {
			evt.views[ \accept ].visible_( false );
		};
		evt.views[\noteTracker].string = "in: %\t out: %".format(
			evt.noteInTracker.activeNotes.size,
			evt.noteOutTracker.activeNotes.size,
		);
	};
	updateViews.value;
	skipJack = SkipJack( updateViews, 0.5, { win.isClosed });
};


~local_organ.makeMIDIChannelsWindow = { |evt, ifOpen = false|
	var makeLabel, updateViews, skipJack, win, fillMIDIOuts, fillMIDIIns;
	var bounds, wasOpen = false;
	if( evt.midiChannelsWindow.notNil && { evt.midiChannelsWindow.isClosed.not }) { 
		bounds = evt.midiChannelsWindow.bounds;
		evt.midiChannelsWindow.close;
		wasOpen = true;
	};
	if( ifOpen.not or: { wasOpen && ifOpen }) {	
		evt.midiChannelsWindow = Window( "% MIDI Channels"
			.format( currentEnvironment.findKeyForValue( evt ) ),
				bounds ? Rect(783, 458, 500, 300)
		).front;
		evt.midiChannelsWindow.addFlowLayout;
		win = evt.midiChannelsWindow;
		makeLabel = { |name, newLine = true, width = 100|
			if( newLine == true ) { win.asView.decorator.nextLine; };
			StaticText( win, width@20 ).string_( name ++ " " ).align_( \right );
		};
		makeLabel.("");
		StaticText( win, 100@20 ).string_( "MIDI Channel" );
		evt.numManuals.collect({ |i|
			var vws;
			if( i == 0 ) {
				makeLabel.( "Pedals" );
			} {
				makeLabel.( "Manual %".format( i.asInteger ) );
			};
			vws = 16.collect({ |ch|
				var name;
				name = (ch+1).asInteger.asString;
				Button( win, 20@20 )
					.states_([[ name ],[ name, Color.black, Color.green ]])
					.value_( (evt.midiChannels[i] == ch).binaryValue )
					.action_({ |bt|
						evt.midiChannels[i] = ch;
						vws.do({ |vw,ii|
							vw.value = (ch==ii).binaryValue
						});
					});
			});
		});
	};
};



/*
~local_organ.makeWindow;

~local_organ.makeMIDIChannelsWindow( false );

~local_organ.makeMIDIChannelsWindow( true );
*/

