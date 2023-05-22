(

// ------------ Setup environment ------------
/*
This file holds an implementation of the OSC format of the SINUA system of the Baroque Organ at Orgelpark, Amsterdam
Functions are included to play notes and to change registers, and the engine keeps track internally which registers are set to be able to send optimized messages for those.

~bo.postOSC = false;
*/

~bo = ~bo ? (); // functions in an Event always have the environment as first argument

~bo.addr = NetAddr.new("192.168.0.1", 1803);
~bo.chanOffset = 0;
~bo.noteOffset = 0; // note 69 == A440

~bo.checkNotes = false;
~bo.postOSC = true;

~bo.fake = false;

~bo.numManuals = 4;
~bo.numLayers = 4;

~bo.regDict = { nil ! ~bo.numLayers } ! ~bo.numManuals;

~bo.noteDict = { nil ! ~bo.numLayers } ! ~bo.numManuals;

~bo.setRegDict = { |evt, regDict|
	regDict.do({ |item, manual|
		item.do({ |regs, layer|
			evt.reg( manual, layer+1, regs );
		});
	});
};

~bo.chanLayer = { // this returns the general OSC address
	arg evt, chan, layer;
	var layerPart = if (layer.notNil, { "/L" ++ layer }, { "" });
	if( chan.notNil ) {
		"/M" ++ (chan + evt.chanOffset) ++ layerPart
	} {
		layerPart
	}
};

//~bo.minForce = 1/127;
~bo.minForce = 1/1000;

~bo.note = {
	arg evt, chan, layer, notes, val, duration;
	var force;
	var msg, regs, range;
	if( layer.isNil ) {
		layer = (chan.asFloat.frac.round(0.1) * 10).asInteger;
		if( layer == 0 ) { layer = nil };
	};
	chan = chan.asInteger;
	case { val == 0 } {
		force = 0;
	} { val < 0 } {
		force = val.abs / 127; // unscaled
	} {
		force = (((val ? 127) / 127) * (evt.quneo !? _.veloScale ? 1))
			.max( evt.minForce );
	};
	if( notes.size == 0 ) { notes = [ notes ] };
	notes = notes.collect(_.asInteger);
	msg = [ evt.chanLayer(chan, layer) ++ "/V", force ] ++ (notes + evt.noteOffset);
	if( evt.postOSC ) { msg.postcs };
	if( evt.checkNotes && { layer.notNil } ) {
		regs = evt.regDict[ chan ][ layer-1 ];
		if( regs.size > 0 ) {
			regs.asArray.do({ |reg|
				var item;
				item = evt.regRanges[ reg ];
				if( item.notNil ) {
					item = item - evt.noteOffset;
					notes.do({ |note|
						if( (note < item[0]) or: (note > item[1]) ) {
							"note M% L% %; out of range for register %\n".postf( chan, layer, note, reg )
						} {
							evt.noteCount = (evt.noteCount ? 0) + 1;
						};
					});
				};
			});
		} {
			"note M% L% %; no registers on\n".postf( chan, layer, notes );
		};
	};
	evt.addr.sendMsg(*msg);
	if( duration.notNil ) {
		{
			duration.wait;
			evt.note( chan, layer, notes, 0 );
		}.fork;
	};
	if( evt.fake == true ) {
		evt.fakeOrgan.startNote( chan, layer, notes, force * 127, duration );
	};
};

~bo.allNotesOff = {
	arg evt, chan, layer;
	if( chan.notNil ) {
		if( layer.notNil ) {
			evt.note( chan, layer, (..127), 0 );
		} {
			evt.numLayers.do({ |layer|
				evt.note( chan, layer+1, (..127), 0 );
			});
		};
	} {
		evt.numManuals.do({ |item|
			evt.numLayers.do({ |layer|
				evt.note( item, layer+1, (..127), 0 );
			});
		});
	};
};

~bo.midinote = { // send notes to all layers at once
	arg evt, chan, notes, val;
	evt.note(chan, nil, notes, val);
};

~bo.reg = { // set absolute registers, or relative if clear is false
	arg evt, chan, layer, regs, clear = true;
	var msg, current;
	regs = regs ? [];
	if(regs.isArray.not, { regs = [regs] });
	//if (clear, { regs = [0] ++ regs });
	msg = [ evt.chanLayer(chan, layer) ++ "/S" ] ++ if( clear ) { [0] ++ regs } { regs };
	if( evt.postOSC ) { msg.postcs };
	if( clear ) {
		evt.regDict[ chan ][ layer-1 ] = regs !? _.sort; evt.changed( \regDict, chan, layer )
	} {
		current = evt.regDict[ chan ][ layer-1 ].as(Set);
		regs.asArray.do({ |item|
			if( item.isNegative ) {
				current.remove( item.abs )
			} {
				current.add( item );
			};
		});
		evt.regDict[ chan ][ layer-1 ] = current.asArray.sort;
		evt.changed( \regDict, chan, layer )
	};
	evt.addr.sendMsg(*msg);
};

~bo.regAdd = { // set relative registers (a negative number meaning remove register)
	arg evt, chan, layer, regs;
	evt.reg(chan, layer, regs, false);
};

~bo.regClear = { |evt, chan, layer|
	evt.reg( chan, layer );
};

~bo.sendSetting = { |evt, chan, layer, which ...args|
	var msg;
	msg = [ evt.chanLayer(chan, layer) +/+ which ] ++ args;
	if( evt.postOSC == true ) { msg.postcs };
	evt.addr.sendMsg(*msg);
};

~bo.delay = { // switching delay on or off (when on is false)
	arg evt, chan, layer, amount, on = true;
	var onOff = if(on, { '"on"' }, { '"off"' });
	evt.addr.sendMsg(
		evt.chanLayer(chan, layer) ++
		"/delay",
		amount.asString +
		onOff
	);
};

~bo.delayOff = {
	arg evt, chan, layer;
	evt.delay(chan, layer, 0, false);
};

~bo.transpose = {
	arg evt, chan, layer, semitones;
	evt.addr.sendMsg(
		evt.chanLayer(chan, layer) ++
		"/transpose",
		semitones
	);
};

~bo.tremolo = { |evt, which = 'ow', on, speed, width| // speed as number; seconds
	var command = "/TremOW", list;
	case { which.asString.toLower.includes( $h ) } {
		command = "/TremHW";
	} { which.isNumber } {
		command = [ "/TremOW", "/TremHW" ][ which ] ? command;
	};
	if( speed.isNumber ) {
		if( speed < 0.245 ) {
			speed = "%ms".format( (speed * 1000).asInteger )
		} {
			speed = "%bpm".format( ( 60 / speed ).asInteger );
		};
	};
	if( on.isKindOf( Boolean ) ) {
		on = if( on ) { "on" } { "off" };
	};
	list = [ on !? _.asString, width, speed ].select(_.notNil);
	if( list.size > 0 ) {
		if( evt.postOSC == true ) { ([ command ] ++ list).postcs };
		evt.addr.sendMsg( *[ command ] ++ list );
	};
};

~bo.createLayer = { |evt, manual = 3|
	var msg;
	msg = "/M%/createLayer".format( manual );
	if( evt.postOSC == true ) { [ msg ].postcs };
	evt.addr.sendMsg( msg );
};

~bo.motorSpeedValue = 1;

~bo.motorSpeed = { |evt, amount = 1.0|
	if( evt.postOSC == true ) { [  "/SP0", amount.asFloat ].postcs };
	evt.motorSpeedValue = amount;
	~bo.addr.sendMsg( "/SP0", amount.asFloat );
};

~bo.motorSpeedInc = { |evt, amount = 0.1|
	evt.motorSpeedValue = (evt.motorSpeedValue + amount).clip(0,1);
		if( evt.postOSC == true ) { [  "/SP0", evt.motorSpeedValue.asFloat ].postcs };
	~bo.addr.sendMsg( "/SP0", evt.motorSpeedValue.asFloat );
};

~bo.crescendoValue = 0; // crescendo pedal

~bo.crescendo = { |evt, amount = 0.0|
	if( evt.postOSC == true ) { [  "/SP1", amount.asFloat ].postcs };
	evt.crescendoValue = amount;
	~bo.addr.sendMsg( "/SP1", amount.asFloat );
};

~bo.swellValue = 0; // sauer swell box

~bo.swell = { |evt, amount = 0.0|
	if( evt.postOSC == true ) { [  "/SP2", amount.asFloat ].postcs };
	evt.swellValue = amount;
	~bo.addr.sendMsg( "/SP2", amount.asFloat );
};

(
~bo.regTransps = (
);

[   16, 8, 8, 8, 4, 4, 2, \f2, \f5, \f3, \f4, 16, 8,
	8, 8, 8, 4, 4, 3, 2, 2, '8/5', '3/2', 1, 'f4', 8,
	16, 16, 12, 8, 16, 8, 4
].do({ |item, i|
	~bo.regTransps[ item ] = (~bo.regTransps[ item ] ? [])  ++ (i+36);
});

~bo.getTranspositionRaw = { |evt, reg = 36|
	var key;
	evt.regTransps.keysValuesDo({ |k, value|
		if( value.includes( reg ) ) { key = k };
	});
	key;
};

~bo.getTransposition = { |evt, reg = 36|
	var key, factors;
	key = evt.getTranspositionRaw( reg );
	if( key.notNil ) {
		if( key.isKindOf( Symbol ) ) {
			/*
			factors = key.asString.split( $/ );
			if( factors.size == 2 ) {
				(8 / (factors[0].interpret / factors[1].interpret)).ratiomidi.round(1);
			} {
				// "%: multi-fach (%); transposition not found".format( reg, key ).postln;
				nil;
			};
			*/
			switch( key,
				'8/5', 28,
				'3/2', 31
			);
		} {
			switch( key,
				3, { 19; },
				12, { 19 - 24 }, {
				(8 / key).ratiomidi.round(1);
				}
			);
		};
	} {
		"%: unknown; transposition not found".format( reg ).postln;
		nil;
	};
};
);

(

~bo.regRanges = (
	36: [ 36, 92 ],
	37: [ 36, 92 ],
	38: [ 36, 92 ],
	39: [ 36, 92 ], // 92 one note too high!
	40: [ 36, 92 ],
	41: [ 36, 92 ],
	42: [ 36, 92 ],
	43: [ 36, 92 ],
	44: [ 36, 92 ],
	45: [ 36, 92 ], // 88-92 not sounding
	46: [ 59, 92 ],
	47: [ 36, 92 ],
	48: [ 36, 92 ], // 92 not sounding

	// problem with black notes if motor fails:
	49: [ 36, 92 ],
	50: [ 36, 92 ],
	51: [ 56, 92 ],
	52: [ 36, 92 ],
	53: [ 36, 92 ],
	54: [ 36, 92 ],
	55: [ 36, 92 ],
	56: [ 36, 92 ],
	57: [ 36, 92 ], // really to 90?
	58: [ 36, 92 ],
	59: [ 36, 92 ],
	60: [ 36, 92 ],
	61: [ 36, 92 ],

	62: [ 36, 66 ],
	63: [ 36, 66 ],
	64: [ 36, 66 ],
	65: [ 36, 66 ],
	66: [ 36, 66 ],
	67: [ 36, 66 ],
	68: [ 36, 66 ],
);
);

(
~bo.regNames = [
"Burdun", "Principal", "Rohrflott", "Quintathen", "Octav", "Gemshorn", "Weit Pfeiffe", "Sexquint altra", "Mixtur", "Cymbel", "Cornett", "Fagott", "Trompet",

"Gedackt", "Violdi-gamba", "Unda maris", "Principal", "Rohrflott", "Nassat", "Octav", "Waldflott", "Tertia", "Quinta", "Sufflott", "Sharf", "Vox humana",

"Principal", "Subbass", "Quint Bass", "Octav", "Posaune", "Posaune", "Clarin"
];
);

(
~bo.regInfo = ( // this is not actively used, just info (used libs above)
	// name, size, [ min, max ], sounding transposition
	36: [ "Burdun", 16, [ 36, 92 ], -12 ],   // D zacht
	37: [ "Principal", 8, [ 36, 92 ], 0 ],   // A "gedekt"
	38: [ "Rohrflott", 8, [ 36, 92 ], 0 ],   // B soft flute
	39: [ "Quintathen", 8, [ 36, 92 ], 0 ], // F fluitachtig kwint boventoon
	40: [ "Octav", 4, [ 36, 92 ], 12 ],     // C "similar to principal"
	41: [ "Gemshorn", 4, [ 36, 92 ], 12 ],   // F fluitachtig oktaaf boventoon
	42: [ "Weit Pfeiffe", 2, [ 36, 92 ], 24 ], // E fluitachtig ver / dichtnij
	43: [ "Sexquint altra", 'f2', [ 36, 92 ], nil ], // G multi
	44: [ "Mixtur", 'f5', [ 36, 92 ], nil ],      // G
	45: [ "Cymbel", 'f3', [ 36, 92 ], nil ],      // G
	46: [ "Cornett", 'f4', [ 59, 92 ], nil ],     // G
	47: [ "Fagott", 16, [ 36, 92 ], -12 ],        // H tongue
	48: [ "Trompet", 8, [ 36, 92 ], 0 ],          // H

	49: [ "Gedackt", 8, [ 36, 92 ], 0 ],     // D
	50: [ "Violdi-gamba", 8, [ 36, 92 ], 0 ], // I viola (single)
	51: [ "Unda maris", 8, [ 56, 92 ], 0 ],   // J unda maris (detuned)
	52: [ "Principal", 4, [ 36, 92 ], 12 ], // A
	53: [ "Rohrflott", 4, [ 36, 92 ], 12 ], // B
	54: [ "Nassat", 3, [ 36, 92 ], 17 ],    // B
	55: [ "Octav", 2, [ 36, 92 ], 24 ],     // C
	56: [ "Waldflott", 2, [ 36, 92 ], 24 ],  // E
	57: [ "Tertia", '8/5', [ 36, 90 ], 28 ], // C
	58: [ "Quinta", '3/2', [ 36, 92 ], 29 ], // C
	59: [ "Sufflott", 1, [ 36, 92 ], 36 ],   // C
	60: [ "Sharf", 'f4', [ 36, 92 ], nil ],  // G
	61: [ "Vox humana", 8, [ 36, 92 ], 0 ],  // H

	62: [ "Principal", 16, [ 36, 66 ], -12 ], // A
	63: [ "Subbass", 16, [ 36, 66 ], -12 ],   // K su
	64: [ "Quint Bass", 12, [ 36, 66 ], -7 ], // K
	65: [ "Octav", 8, [ 36, 66 ], 0 ],       // C
	66: [ "Posaune", 16, [ 36, 66 ], -12 ],  // H
	67: [ "Posaune", 8, [ 36, 66 ], 0 ],     // H
	68: [ "Clarin", 4, [ 36, 66 ], 12 ],     // H
);
);
)

/*
// manual 3, layer 1, note 69 (A440)
~bo.note( 3, 1, 69, 127, 0.1 ); // 0.1s

~bo.note( 3, 1,  69, 127 ); // infinite duration

~bo.note( 3, 1,  69, 0 ); // end

// all notes off manual 3, layer 1
~bo.note( 3, 2, (..127), 127, 0.1 );

// registers
~bo.reg(3, 1, (36..68).scramble[..5] );


// all notes off manual 3, layer 1
~bo.note( 3, 1, (..127), 0 );

// registers
~bo.reg(3, 1, (36..68).scramble[..5] );

{ SinOsc.ar( 2200 ) }.play;

~bo.getTransposition( 58 );

*/