use v6.c;
use Audio::PortMIDI;

unit package Audio::Helpers;

enum NoteName is export < C Cs D Ds E F Fs G Gs A As B Bs >;
enum Interval is export <P1 m2 M2 m3 M3 P4 TT P5 m6 M6 m7 M7>;

class Note is export {
    has Int $.midi is required;
    has $.freq;
    has $.vel = 95;

    multi infix:<==>(Note:D $lhs, Note:D $rhs) is export {
        $lhs.same($rhs);
    }

    method is-interval(Note:D: Note:D $rhs, Interval $int --> Bool) {
        my $diff = self.midi - $rhs.midi;
        $diff < 0 ?? $diff + 12 == $int !! $diff == $int
    }

    #| Returns Nil or Less/Same/More
    method same(Note:D $: Note:D $rhs) {
        (self.midi % 12) == ($rhs.midi % 12)
            ?? self.midi == $rhs.midi 
                ??  Same but True # ???
                !!  self.midi < $rhs.midi 
                    ??  Less 
                    !!  More 
            !! Nil

    }

    multi infix:<->(Note:D $lhs, Note:D $rhs --> Interval) is export {
        my $oct = ($lhs.midi - $rhs.midi) div 12;
        my $int = Interval( ($lhs.midi - $rhs.midi) % 12 );
        $int but role { method octaves { $oct } };
    }

    multi infix:<+>(Note:D $note, Int $interval --> Note) is export {
        Note.new(midi => $note.midi + $interval)
    }

    multi infix:<->(Note:D $note, Int $interval --> Note) is export {
        &infix:<+>($note, -$interval)
    }

    multi infix:<->(Int $interval, Note:D $note --> Note) is export {
        &infix:<+>($note, -$interval)
    }
    
    multi infix:<+>(Int $interval, Note:D $note --> Note) is export {
        &infix:<+>($note, $interval)
    }

    multi infix:«>»(Note:D $lhs, Note:D $rhs --> Bool) is export {
        $lhs.midi < $rhs.midi
    }
    
    multi infix:«<»(Note:D $lhs, Note:D $rhs --> Bool) is export {
        $lhs.midi < $rhs.midi
    }
    
    method Numeric {
        $.midi
    }

    method octave {
        $.midi div 12
    }

    method OffEvent {
        Audio::PortMIDI::Event.new(event-type => NoteOff, data-one => $.midi, data-two => $.vel, timestamp => 0, channel => 3);
    }
    method OnEvent {
        Audio::PortMIDI::Event.new(event-type => NoteOn, data-one => $.midi, data-two => $.vel, timestamp => 0, channel => 3);
    }

    method name {
        NoteName($.midi % 12).key;
    }
    
    method Str {
        NoteName($.midi % 12).key ~ ($.midi div 12)
    }
}

import Note; 

class Chord is export {
    has Note @.notes;
    has $.inversion;

    method root(Chord:D: ) {
        @.notes[(* - $.inversion) % *]
    }

    method third(Chord:D: ) {
        @.notes[($.inversion + 1) % self.notes]
    }

    method fifth(Chord:D: ) {
        @.notes[($.inversion + 2) % self.notes]
    }

    method invert(Chord:D: $degree is copy = 1) {
        my @new-notes = @.notes;
        my $inversion = $degree % @.notes;
        if $degree == 0 {
            self
        }
        elsif $degree < 0 {
            while $degree++ < 0 {
                my $tmp = @new-notes.pop - 12;
                @new-notes = $tmp, |@new-notes;
            }
        }
        elsif $degree > 0 {
            while $degree-- > 0 {
                my $tmp = @new-notes.shift + 12;
                @new-notes = |@new-notes, $tmp;
            }
        }
        Chord.new(notes => @new-notes.Slip, :inversion($inversion + $.inversion));
    }

    submethod BUILD(:@!notes, :$!inversion = 0) {
        @!notes = @!notes;
        $!inversion = $!inversion % +@!notes
    }

    method OffEvents(Chord:D: ) {
        @.notes>>.OffEvent;
    }
    method OnEvents(Chord:D: ) {
        @.notes>>.OnEvent;
    }

    method Str(Chord:D: ) {
        my $name = @.notes>>.Str;

        my @intervals;
        loop (my $i = 1; $i < @.notes; ++$i) {
            @intervals.push: (@.notes[$i] - @.notes[$i - 1]);
        }

        given @intervals[0,1] {
            when (M3, m3)|(P4, M3)|(m3, P4) {
                $name ~= " ==> {$.root.name} Maj";
            }
            when (m3, M3)|(P4, m3)|(M3, P4) {
                $name ~= " ==> {$.root.name} min";
            }
            default {
                $name ~= " ==> {$.root.name} vOv";
            }
        }

        $name ~ " (inversion: $.inversion)";
    }
}

class Mode is export {

    #`{{{
        All of this might still become useful, but I don't see how right now...

        enum Positions < Ton subp domp Sub Dom tonp dim >;

        sub min ($t) { ($t, $t + 3, $t + 7) }
        sub min7 ($t) { ($t, $t + 3, $t + 7, $t + 10) }
        sub min7p ($t) { ($t, $t + 3, $t + 7, $t + 11) }
        sub maj ($t) { ($t, $t + 4, $t + 7) }
        sub maj7 ($t) { ($t, $t + 4, $t + 7, $t + 11) }
        sub maj7s ($t) { ($t, $t + 4, $t + 7, $t + 10) }
        sub dim ($t) { ($t, $t + 3, $t + 7) }

        my %chords = Ton,  [ &maj, &maj7  ],
                     subp, [ &min, &min7  ],
                     domp, [ &min, &min7  ],
                     Sub,  [ &maj, &maj7  ],
                     Dom,  [ &maj, &maj7s ],
                     tonp, [ &min, &min7  ],
                     dim,  [ &dim, &dim   ];

        my %progs = Ton,  (:{Ton => 3, subp => 6, domp => 4, Sub => 8, Dom => 6, tonp => 4, dim => 1}).BagHash,
                    subp, (:{Ton => 2, subp => 3, domp => 6, Sub => 5, Dom => 8, tonp => 2, dim => 1}).BagHash,
                    domp, (:{Ton => 5, subp => 2, domp => 2, Sub => 7, Dom => 8, tonp => 4, dim => 2}).BagHash,
                    Sub,  (:{Ton => 3, subp => 3, domp => 7, Sub => 2, Dom => 8, tonp => 4, dim => 2}).BagHash,
                    Dom,  (:{Ton => 8, subp => 4, domp => 3, Sub => 5, Dom => 4, tonp => 6, dim => 3}).BagHash,
                    tonp, (:{Ton => 3, subp => 6, domp => 4, Sub => 5, Dom => 3, tonp => 2, dim => 1}).BagHash,
                    dim,  (:{Ton => 8, subp => 4, domp => 3, Sub => 5, Dom => 6, tonp => 4, dim => 1}).BagHash;

    }}}

    my %modes = ionian      =>    [0,2,4,5,7,9,11],
                dorian      =>    [0,2,3,5,7,9,10],
                phrygian    =>    [0,1,3,5,7,8,10],
                lydian      =>    [0,2,4,6,7,9,11],
                mixolydian  =>    [0,2,4,5,7,9,10],
                aeolian     =>    [0,2,3,5,7,9,10],
                locrian     =>    [0,1,3,5,6,8,10],
                major       =>    [0,2,4,5,7,9,11],
                pentatonic  =>    [0,2,4,  7,9,  ];

    has Str $.mode is required;
    has Note $.root is required;
    has Note @!notes;
    has Int $!offset;
    has @.weights; # NYI, the commented part above might be useful...

    submethod BUILD(:$!mode, :$!root, :@!weights) {
        $!offset = $!root.midi % 12;
    }

    method next-chord(Mode:D: Chord $current, :@intervals = [ P1, P4, P5 ], :@octaves = [4]) {
        if @.weights { ... }
        else {
            my @next = self.chords.grep({
                $_.root.is-interval($current.root, any(@intervals)) && $current.root - $_.root <= M7
            });
            @next.pick;
        }
    }
    
    method notes() {
        if !@!notes.elems {
            for @(%modes{$.mode}) -> $mode-offset {
                for ^10 -> $oct-offset {
                    @!notes.append( Note.new(midi => ($mode-offset + $!offset + (12 * $oct-offset))) );
                }
            }
            @!notes .= sort({ $^a.midi <=> $^b.midi });
        }
        @!notes
    }

    method octave(Int $oct = 4) {
        self.notes[($oct * %modes{$.mode})..($oct * %modes{$.mode} + %modes{$.mode})]
    }

    my @chords;
    method chords(Mode:D:) {
        if !@chords {
            my @all-notes = |$.notes(:all);
            loop (my int $i = 0; $i < @all-notes - 4; ++$i) {
                my @notes = @all-notes[$i], @all-notes[$i + 2], @all-notes[$i + 4];
                @chords.push: my $chrd = Chord.new: :@notes
            }
        }
        @chords
    }
}
