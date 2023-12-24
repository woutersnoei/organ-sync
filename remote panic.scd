(
// remote panic; kills all notes on the remote organ(s)
{
5.do({ |i|
	127.do({ |ii|
		0.01.wait;
		~local_organ.sendMappedRemoteNote(  i, ii, 0 );
	});
});
	"done".postln;
}.fork
)

(
~motorWin = Window( "BO Motor", Rect(12,11,393,97) ).front;
~motorWin.asView.addFlowLayout;

~motorSlider = EZSlider( ~motorWin, 380@20, "motor", [0,1,\lin,0,0].asSpec, { |sl|
	~bo.motorSpeed( sl.value );
});

~remotePanicButton = Button( ~motorWin, 100@30 ).states_([ ["remote panic"] ]).action_({ |bt|
	// remote panic; kills all notes on the remote organ(s)
	{
		5.do({ |i|
			127.do({ |ii|
				0.01.wait;
				~local_organ.sendMappedRemoteNote(  i, ii, 0 );
			});
		});
		"done".postln;
	}.fork
});
)

/*
TCP/IP - 15-20mins
George -10 mins
Wouter - 7 mins
Jacob - 7-10mins
Gamut Inc - 14 mins
*/


~bo.addr.sendMsg( "/panic" );

( // cleanup
4.do({ |i|
	4.do({ |ii|
	~bo.reg( i, ii+1 );
	});
});
)

( // registration for george 0:00
~bo.reg(0, 1, [63, 49] );
~bo.reg(1, 1, [36] );
~bo.reg(2, 1, [38] );
~bo.reg(3, 1, [53] );
)

( // registration for george 2:00
~bo.reg(0, 1, [63, 49] );
~bo.reg(1, 1, [36, 37] );
~bo.reg(2, 1, [38] );
~bo.reg(3, 1, [53] );
)

( // registration for george 6:00 wind down
~bo.reg(0, 1, [63, 49] );
~bo.reg(1, 1, [36, 37] );
~bo.reg(2, 1, [38] );
~bo.reg(3, 1, [61] );
)

( // registration for georg 9:00
  //                        10:00: wind on again
~bo.reg(0, 1, [63, 49] );
~bo.reg(1, 1, [36] );
~bo.reg(2, 1, [38] );
~bo.reg(3, 1, [53] );
)

( // extra stops one by one
//~bo.reg(0, 1, [63, 49] );
~bo.reg(1, 1, [36, 42] );
// ~bo.reg(2, 1, [38] );
~bo.reg(3, 1, [53, 41] );
)




36, 38, 53, [63, 49]
"For my registration, soft flutes 16 and 8 on each manual/division"

Add principle 8 to manual 1 two minutes in




/*
36: Burdun 16  //
37: Principal 8
38: Rohrflott 8 //
39: Quintathen 8
40: Octav 4
41: Gemshorn 4
42: Weit Pfeiffe 2
43: Sexquint altra f2
44: Mixtur f5
45: Cymbel f3
46: Cornett f4
47: Fagott 16
48: Trompet 8
49: Gedackt 8
50: Violdi-gamba 8
51: Unda maris 8
52: Principal 4
53: Rohrflott 4 //
54: Nassat 3
55: Octav 2
56: Waldflott 2
57: Tertia 8/5
58: Quinta 3/2
59: Sufflott 1
60: Sharf f4
61: Vox humana 8
62: Principal 16
63: Subbass 16 //
64: Quint Bass 12
65: Octav 8
66: Posaune 16
67: Posaune 8
68: Clarin 4
*/