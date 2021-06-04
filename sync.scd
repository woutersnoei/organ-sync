(
// proto Event ~vpn_sync
// back and forth basic communication between two computers

/*
latency sets the latency for *incoming* messages. If the latency is too low, "late" messages will be displayed in the post window. The latency is a combination of the difference between the clocks on both systems and the time it takes for a message to travel over the network. It can be negative too, if the clock of the sending machine is ahead of that of the receiving one.The engine constantly checks what the departure and arrival times of the incoming messages is and makes an educated guess as to what the latency setting should be. Hit the "use advised" button in the GUI to use it. The arrival time of messages can vary due to network clutter etc., so the latency advice takes the highest value of the latest 1000 messages arriving. It can happen that the advice changes during a session, as network speeds may vary. A "late" message will still be executed, but may not have a correct timing.

In the address field, specify the ip address of the remote machine. The engine expects a copy of this program to be running on the remote machine as well, and there with the ip address of this machine specified.

A series of "ping" messages can be used to check connections, and also determine latency settings.
*/

~vpn_sync = ~vpn_sync ? ();

~vpn_sync.myID = 40;

~vpn_sync.myName = "scutil --get LocalHostName".unixCmdGetStdOut.select(_ != $\n );

~vpn_sync.extraArgs = [];

~vpn_sync.fetchMyID = { |evt|
	var res;
	res = "ifconfig ppp0".unixCmdGetStdOut;
	if( res.size > 0 ) {
		res = res.split( $\n );
		res = res.detect({ |item| item.find( "\tinet ").notNil });
		if( res.notNil ) {
			res = res.split( $ )[1].split($.).last.interpret;
			if( res.isKindOf( Number ) ) {
				~vpn_sync.myID = res;
			};
		} {
			"could not find my IP, inet line not found".postln;
		};
	} {
		"could not fetch my IP, VPN not active?".postln;
	};
};

~vpn_sync.ipRange = "192.168.100.%"; // johnty's vpn
~vpn_sync.recvPort = 8123; // a port

~vpn_sync.makeRemoteAddr = { |evt, id = 39|
	evt.remoteAddr = NetAddr( evt.ipRange.format( id.asInteger ), evt.recvPort );
};

~vpn_sync[ \remoteID ] = { |evt|
	evt.remoteAddr.ip.split( $. ).last.interpret.asInteger;
};

~vpn_sync.remoteID_ = { |evt, id|
	evt.remoteAddr = NetAddr( evt.ipRange.format( id.asInteger ), evt.recvPort );
};

~vpn_sync.makeRemoteAddr( 39 );

~vpn_sync.latency = -0.25;

~vpn_sync.send = true;
~vpn_sync.receive = true;

~vpn_sync.verbose = false;

~vpn_sync.action = { |msg|
	"%: %\n".postf( thisThread.seconds, msg ); // post message for testing
	//~fwdAddr.sendMsg( *msg );
};

~vpn_sync.doAction = { |evt, msg|
	evt[ \action ].value( msg );
};

~vpn_sync.addClockOffset = { |evt, amt|
	evt.maxLatency = (evt.maxLatency ? -inf).max(amt);
	evt.minLatency = (evt.minLatency ? inf).min(amt);
	evt.clockOffsetArray = (evt.clockOffsetArray ? []).addFirst( amt );
	if( evt.clockOffsetArray.size > (2**14) ) { evt.clockOffsetArray.pop };
};

~vpn_sync.resetMeasurements = { |evt|
	evt.pingRTTimeArray = [];
	evt.maxLatency = -inf;
	evt.minLatency = inf;
	evt.clockOffsetArray = [];
};

~vpn_sync.calcLatency = { |evt, plot = false, post = true|
	if( plot ) { evt.clockOffsetArray !? _.plot };
	if( evt.maxLatency.notNil && (evt.maxLatency != -inf) ) {
		if( post ) {
				"clock offset: %s to %s\nadvised latency: %s\n".postf(
				evt.minLatency.asStringPrec(2),
				evt.maxLatency.asStringPrec(2),
				(evt.maxLatency + 0.01).roundUp(0.05)
			);
		};
		 (evt.maxLatency + 0.01).roundUp(0.05);
	};
};

~vpn_sync.addPingRTTime = { |evt, amt|
	evt.pingRTTimeArray  = (evt.pingRTTimeArray ? []).addFirst( amt );
	if( evt.pingRTTimeArray .size > 1024 ) { evt.pingRTTimeArray.pop };
};

~vpn_sync.calcRT = { |evt, plot = false, post = true|
	if( evt.pingRTTimeArray.size > 0 ) {
		if( plot ) { evt.pingRTTimeArray.plot };
		if( post ) {
			"return trip time: %s to %s (avg: %s)\n".postf(
				evt.pingRTTimeArray.minItem.asStringPrec(2),
				evt.pingRTTimeArray.maxItem.asStringPrec(2),
				evt.pingRTTimeArray.mean.asStringPrec(2)
			);
		};
		evt.pingRTTimeArray.mean.asStringPrec(2)
	};
};

~vpn_sync.makeOSCFuncs = { |evt|
	thisProcess.openUDPPort( evt.recvPort );

	evt.oscFunc.free;
	evt.oscFunc = OSCFunc( { |msg, time, addr|
		var delta;
		if(  evt.receive == true && { evt.remoteID == msg[1].asInteger } ) {			delta = time - thisThread.seconds;
			evt.addClockOffset( delta.neg );
			delta = delta + evt.latency;
			if( delta < 0 ) {
				"late: %, %\n".postf( delta, msg );
			} {
				if( evt.verbose == true ) {
					"msg received: %, %\n".postf( delta, msg );
				};
			};
			SystemClock.sched( delta.max(0), { evt.doAction( msg[2..] ); });
		};
	}, "/vpn_sync" );

	evt.pingFunc.free;
	evt.pingFunc = OSCFunc( { |msg, time, addr|
		var delta;
		if( evt.remoteID == msg[1].asInteger ) {
			delta = time - thisThread.seconds;
			evt.addClockOffset( delta.neg );
			if( msg[2] == \reply ) {
				evt.addPingRTTime( thisThread.seconds - msg[3] );
				evt.pingReplyReceived = true;
				if( evt.verbose == true ) {
					"ping reply received: %, %, %\n".postf( delta, addr.cs, msg );
				};
			} {
				if( evt.verbose == true ) {
					"ping received: %, %, %\n".postf( delta, addr.cs, msg );
				};
				evt.remoteAddr.sendBundle( 0, [ "/vpn_ping", evt.myID, "reply" ] ++ msg[2..] );
			};
		};
	}, "/vpn_ping" );
};

~vpn_sync.sendInvites = { |evt, range = #[0,255]|
	(range[0]..range[1]).do({ |id|
		var addr;
		if( id != evt.myID ) {
			addr = NetAddr( evt.ipRange.format( id ), evt.recvPort );
			addr.sendMsg( "/vpn_invite", evt.myID, id, evt.myName, *evt.extraArgs );
		};
	});
};

~vpn_sync.makeRecvInviteFuncs = { |evt|
	thisProcess.openUDPPort( evt.recvPort );

	evt.recvInviteFunc.free;
	evt.recvInviteFunc = OSCFunc( { |msg, time, addr|
		if( msg[1].isNumber ) {
			~vpn_sync.doRecvInviteAction( msg[1].asInteger, msg[2].asInteger, msg[3], *msg[4..] ); // from, to, name, extraArgs
			NetAddr( evt.ipRange.format( msg[1].asInteger ), evt.recvPort ).sendMsg( "/vpn_invite", "reply", msg[2], msg[1], evt.myName, *evt.extraArgs );
		} {
			~vpn_sync.doRecvInviteAction( msg[2].asInteger, msg[3].asInteger, msg[4], *msg[5..] ); // from, to, name
		};
	}, "/vpn_invite" );
};

~vpn_sync.doRecvInviteAction = { |evt, from, to, name ...extraArgs| // from: sender, to: me, name: of sender
	evt[ \recvInviteAction ].value( from, to, name, *extraArgs );
};

~vpn_sync.endOSCFuncs = { |evt|
	evt.oscFunc.free; evt.oscFunc = nil;
	evt.pingFunc.free; evt.pingFunc = nil;
};

~vpn_sync.sendMsg = { |evt ...msg|
	if( evt.send == true ) {
		if( evt.verbose ) { 
			"msg sent to %:% : %\n".postf( 
				evt.remoteAddr.ip,
				evt.remoteAddr.port,
				[ "/vpn_sync", evt.myID ] ++ msg
			); 
		};
		evt.remoteAddr.sendBundle( 0, [ "/vpn_sync", evt.myID ] ++ msg );	};
};

~vpn_sync.sendOnePing = { |evt|
	evt.remoteAddr.sendBundle( 0, [ "/vpn_ping", evt.myID, thisThread.seconds ] );
};

~vpn_sync.ping = { |evt|
	evt.pingReplyReceived = false;
	{
		128.do({ evt.sendOnePing; 0.01.wait; });
		if( evt.verbose == true ) { "sent 128 ping messages".postln; };
	}.fork;
};
)

/*

SCTextView
~remote = ().proto_( ~vpn_sync );

~remote.remoteAddr = NetAddr("192.168.5.10", 57120);
~remote.remoteAddr = NetAddr("192.168.5.99", 57120);
~remote.makeOSCFuncs; // cmd-. to cancel

~remote.makeWindow;
~remote.latency = 0.2
~homesync.resetMeasurements;

~remote.makeRemoteAddr(39);
~remote.send = true;

~remote.action = { "hello".postln };
~homesync.doAction

~homesync.minLatency;
~vpn_sync.minLatency;

~vpn_sync.makeOSCFuncs; // cmd-. to cancel

~remote.pingReplyReceived = true;

~vpn_sync.resetMeasurements;

~vpn_sync.ping;

~vpn_sync.calcLatency( true );

~vpn_sync.calcRT( true );
*/
