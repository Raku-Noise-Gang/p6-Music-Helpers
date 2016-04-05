use Audio::Helpers;

multi MAIN(Int :$root = 48, Int :$channel = 3) {
    my $mode = Mode.new(:mode('major'), :root(Note.new(:midi($root))));

    my $pm = Audio::PortMIDI.new;
    my $s  = $pm.open-output(3, 32);
    my $in = $pm.open-input($pm.default-input-device.device-id, 32);

    my @chords;
    my $chord = $mode.chords(:octaves([3,4])).pick;
    my @steps = (|([m2, M2, P4], [m3, M3, P5], [m6, M6, m7, M7, P1], [m3, M3, m6, M6, P1]) xx 2);
    for @steps {
        @chords.push: $chord; 
        $chord = $mode.next-chord($chord, intervals => $_).invert( ^3 .pick );
        $chord .= invert(-1) while $chord.root.midi > 55;
        $chord .= invert(1)  while $chord.root.midi < 46;
    }

    my $next-chord = @chords[0];

    sub flip-flop { $ .= not }

    sub nth(Int $in) { (++$) % $in }

    my $code = supply {
        whenever supply { emit $in.poll while True } {
            emit $in.read(1);
        }
    }

    say "hi?";

    my $melnote = ((flip-flop() ?? $chord.notes[0] !! $mode.next-chord($chord, intervals => [m2, M2, m3, M3, m6, M6]).notes) <<+>> 12).pick;
    my $third = $mode.notes.grep({ $_.is-interval($melnote, one(m3, M3)) })[0];;
    my $set-next;

    react {
        whenever $code -> $ev {
            my Audio::PortMIDI::Event @outevs;
            if $ev {
                given $ev[0].data-two {
                    my $v;
                    when * +& 1 {
                        proceed if rand < .1;
                        $next-chord = $mode.next-chord($chord, intervals => [m2, M3, TT, M6, m7]).invert((-3, -2, -1, 0, 1, 2, 3).pick);
                        $next-chord .= invert(-1) while $next-chord.root.octave > 4;
                        $next-chord .= invert( 1) while $next-chord.root.octave < 2;
                        say $next-chord.Str;
                        # proceed if rand < .2;
                        for $chord.OffEvents {
                            @outevs.push: $_
                        }
                        $chord = $next-chord.invert( (-1, 0, 1).pick );
                        for $chord.OnEvents {
                            @outevs.push: $_
                        }
                        proceed;
                    }
                    when 7 < * < 14 {
                        $v = (80..127).pick;
                        if rand < .4 {
                            $v = (80..127).cache.pick;
                            @outevs.push: $melnote.OffEvent;
                            $melnote = $chord.notes.pick + (12, 24).pick;
                            if rand < .3 {
                                $melnote = $mode.notes.grep({ $_.is-interval($melnote, any(m2, M2, m7, M7)) }).pick;
                            }
                            @outevs.push: $melnote.OnEvent;
                        } 
                        elsif rand < .2 {
                            @outevs.push: $third.OffEvent;
                            $third = $mode.notes.grep({ $_.is-interval($melnote, one(M3, m3)) }).pick + (12,24).pick;
                            @outevs.push: $melnote.OnEvent;
                            @outevs.push: $third.OnEvent;
                        }
                        proceed;
                    }
                }
                $s.write(@outevs);
                @outevs = [];
            }
        }
    }
}
