use v6.c;

=begin pod

=head1 NAME

Music::Helpers - Abstractions for handling musical content

=head1 SYNOPSIS

    use Music::Helpers;

    my $mode = Mode.new(:root(C), :mode('major'))

    # prints 'C4 E4 G4 ==> C maj (inversion: 0)'
    say $mode.tonic.Str;

    # prints 'F4 A4 C5 ==> F maj (inversion: 0)'
    say $mode.next-chord($mode.tonic, intervals => [P4]);


=end pod

use Audio::PortMIDI;

unit package Music::Helpers;

enum NoteName is export <C Cs D Ds E F Fs G Gs A As B Bs>;
enum Interval is export <P1 m2 M2 m3 M3 P4 TT P5 m6 M6 m7 M7 P8>;

class Note is export {
    has Int $.midi is required;
    has $.freq;
    has $.vel = 95;

    method is-interval(Note:D: Note:D $rhs, Interval $int --> Bool) {
        if self < $rhs {
            $rhs.midi - self.midi == $int
        }
        else {
            self.midi - $rhs.midi == $int
        }
    }

    multi infix:<==>(Note:D $lhs, Note:D $rhs) is export {
        $lhs.same($rhs);
    }

    #| Returns Nil or Less/Same/More
    method same(Note:D $: Note:D $rhs) {
        (self.midi % 12) == ($rhs.midi % 12)
            ?? self.midi == $rhs.midi
                ??  Same but True
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

    method OffEvent(Int $channel = 1) {
        Audio::PortMIDI::Event.new(event-type => NoteOff, data-one => $.midi, data-two => $.vel, timestamp => 0, :$channel);
    }
    method OnEvent(Int $channel = 1) {
        Audio::PortMIDI::Event.new(event-type => NoteOn, data-one => $.midi, data-two => $.vel, timestamp => 0, :$channel);
    }

    method name {
        NoteName($.midi % 12).key;
    }

    method Str {
        NoteName($.midi % 12).key ~ ($.midi div 12)
    }
}

import Note;
class Chord { ... };

role maj {
    method chord-type {
        "maj"
    }
    method dom7 {
        Chord.new(notes => [ |self.normal.notes, self.normal.notes[2] + m3 ])
    }
}
role min {
    method chord-type {
        "min"
    }
}
role weird {
    method chord-type {
        "weird"
    }
}
role dom7 {
    method chord-type {
        "dom7"
    }
    method TT-subst {
        my @notes = $.invert(-$.inversion).notes;
        my $third = @notes[3];
        my $seventh = @notes[1];
        my $root = $third - M3;
        my $fifth = $seventh - m3;
        Chord.new(notes => [ $root, $third, $fifth, $seventh ]).invert($.inversion);
    }
}

class Chord is export {
    has Note @.notes;
    has $.inversion;

    method normal(Chord:D: ) {
        self.invert(-$.inversion)
    }

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
        $!inversion = $!inversion % +@!notes;

        my @intervals;
        loop (my $i = 1; $i < @!notes; ++$i) {
            @intervals.push: Interval(@!notes[$i] - @!notes[$i - 1]);
        }

        given @intervals {
            when (M3, m3)|(P4, M3)|(m3, P4) {
                self does maj;
            }
            when (m3, M3)|(P4, m3)|(M3, P4) {
                self does min;
            }
            when (M3, m3, m3)|(m3, m3, M2)|(m3, M2, M3)|(M2, M3, m3) {
                self does dom7;
            }
            default { # probably want more cases here
                self does weird;
            }
        }

    }

    method OffEvents(Chord:D: Int $channel = 1) {
        @.notes>>.OffEvent($channel);
    }
    method OnEvents(Chord:D: Int $channel = 1) {
        @.notes>>.OnEvent($channel);
    }

    method Str(Chord:D: ) {
        my $name = @.notes>>.Str;

        $name ~= " ==> $.root $.chord-type";
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

    my %modes = ionian      =>    [P1,M2,M3,P4,P5,M6,M7],
                dorian      =>    [P1,M2,m3,P4,P5,M6,m7],
                phrygian    =>    [P1,m2,m3,P4,P5,m6,m7],
                lydian      =>    [P1,M2,M3,TT,P5,M6,M7],
                mixolydian  =>    [P1,M2,M3,P4,P5,M6,m7],
                aeolian     =>    [P1,M2,m3,P4,P5,M6,m7],
                locrian     =>    [P1,m2,m3,P4,TT,m6,m7],
                major       =>    [P1,M2,M3,P4,P5,M6,M7],
                minor       =>    [P1,M2,m3,P4,P5,m6,m7],
                pentatonic  =>    [P1,M2,M3,   P5,M6,  ];

    # subset ModeName of Str where * eq any %modes.keys;

    has $.mode is required;
    has NoteName $.root is required;
    has Note @!notes;
    has @.weights; # NYI, the multi-line commented part above might be useful...

    method modes {
        %modes;
    }

    submethod BUILD(:$!mode, NoteName :$!root, :@!weights) { }

    method tonic(Mode:D: :$octave = 4) {
        $.chords.grep({ $_.root == $.root && $_.root.octave == $octave })[0]
    }

    method root-note(Mode:D: :$octave = 4) {
        Note.new(:midi($!root + $octave * 12))
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
                    @!notes.append( Note.new(midi => ($mode-offset + $!root + (12 * $oct-offset))) );
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
