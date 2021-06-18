/*
// little script to auto-accept any invites coming in, and also ping any
// remote that hasn't been pinged yet
// usage:

~auto_accept.start( 15 ); // check every 15 seconds (defaut)

~auto_accept.end; // stop checking

// running the code below will also call ~auto_accept.start
*/

~auto_accept = ~auto_accept ? ();

(
~auto_accept.acceptIfAny = {
	if( ~local_organ.invites.size > 0 ) {
		~local_organ.acceptInvites;
		~local_organ.startRemotes;
		{ ~local_organ.makeWindow; }.defer(0.2);
	};
};
);

(
~auto_accept.pingIfNeeded = { |evt, waitTime = 0|
	{
		waitTime.wait;
		~local_organ.vpnSyncs.do({ |item|
			var lt;
			if( item.pingReplyReceived != true ) {
				item.ping;
				2.wait;
				lt = item.calcLatency;
				if( lt.notNil ) { item.latency = lt; };
			};
		});
	}.fork( AppClock );
};
);

~auto_accept.start = { |evt, interval = 15|
	evt.end;
	evt.task = SkipJack({ 
		"checking invitations".postln;
		evt.acceptIfAny;
		evt.pingIfNeeded( 1 );
	}, interval);
};

~auto_accept.end = { |evt|
	evt.task.stop;
	evt.task = nil;
};

~auto_accept.start;

/*
~auto_accept.end;
*/