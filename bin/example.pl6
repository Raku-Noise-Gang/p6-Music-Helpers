use Music::Helpers;

multi MAIN(:$mode = 'major', Int :$root = 48, Int :$channel = 3) {
    my $mode-obj = Mode.new(:$mode, :root(NoteName($root % 12)));

    my $pm = Audio::PortMIDI.new;
    my $s  = $pm.open-output(3, 32);
    my $in = $pm.open-input($pm.default-input-device.device-id, 32);

    sub flip-flop { $ .= not }

    sub nth(Int $in) { (++$) % $in }

    my $code = supply {
        whenever supply { emit $in.poll while True } {
            emit $in.read(1);
        }
    }

    my @intervals = Interval.pick(3);

    react {
        my $next-chord;
        my $chord = $mode-obj.chords.pick;
        my $melnote = $chord.notes.pick + 12;
        my $third = $mode-obj.notes.grep({ $_.is-interval($melnote, one(M3, m3)) && $_.octave == $melnote.octave })[0];
        my $sw = 0;
        whenever $code -> $ev {
            my Audio::PortMIDI::Event @outevs;
            if $ev {
                given $ev[0].data-two {
                    my $redo = False;
                    when * +& 1 {
                        if $sw++ %% 4 {
                            @intervals = Interval.pick(6);
                            say "switching chords";
                        }
                        proceed if rand < .1;
                        $next-chord = $mode-obj.next-chord($chord, :@intervals).invert((-3, -2, -1, 0, 1, 2, 3).pick);
                        $next-chord .= invert(-1) while any($next-chord.notes>>.octave) > 4;
                        $next-chord .= invert( 1) while any($next-chord.notes>>.octave) < 3;
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
                    when 1 < * {
                        if rand < .4 || $redo {
                            $redo = False;
                            @outevs.push: $melnote.OffEvent;
                            $melnote = $chord.notes.pick + (12, 24).pick;
                            if rand < .3 {
                                $melnote = $mode-obj.notes.grep({ $_.is-interval($melnote, any(@intervals.pick(3)) ) }).pick;
                                $redo = True;
                            }
                            @outevs.push: $melnote.?OnEvent // Empty;
                        } 
                        elsif rand < .2 {
                            @outevs.push: $third.OffEvent;
                            $third = $mode-obj.notes.grep({ $_.is-interval($melnote, one(M3, m3)) }).pick;
                            @outevs.push: $melnote.?OnEvent // Empty;
                            @outevs.push: $third.?OnEvent // Empty;
                            $redo = True;
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
