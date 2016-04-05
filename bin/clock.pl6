use Audio::PortMIDI;

multi sub MAIN(:$server, :$tempo = 120) {
    my $pm = Audio::PortMIDI.new;
    my $stream = $pm.open-output($pm.default-output-device.device-id, 32);

    constant MfID = 0x7d; # Manufacturer ID 'Educational'

    my $step = 1/(($tempo/60)*2);


    my @nth = [0b1111, 0b1000, 0b1100, 0b1000, 0b1110, 0b1000, 0b1100, 0b1000];

    react {
        whenever Supply.interval($step) {
            my $data = @nth[$++ % +@nth];

            my $m = Audio::PortMIDI::Event.new(status => 0b11110000, data-one => MfID, data-two => $data);
            my $n = Audio::PortMIDI::Event.new(status => 0b11110111);
     
            my Audio::PortMIDI::Event @a = $m, $n;
            $stream.write(@a);
       }
    }
}

multi sub MAIN(:$client) {
    my $pm = Audio::PortMIDI.new;
    my $clock = $pm.open-input($pm.default-input-device.device-id, 32);

    my $out = $pm.open-output(3, 32);

    my $code = supply {
        # busy wait... probably a saner way to do this
        whenever supply { emit $clock.poll while True } {
            emit $clock.read(1)
        }
    }

    my $event-type = NoteOn;
    my $channel = 9;

    my %map =   C => Audio::PortMIDI::Event.new(:$event-type, :$channel, data-one => 49, data-two => 127, timestamp => 0),
                R => Audio::PortMIDI::Event.new(:$event-type, :$channel, data-one => 42, data-two => 127, timestamp => 10000000),
                S => Audio::PortMIDI::Event.new(:$event-type, :$channel, data-one => 38, data-two => 127, timestamp => 1000),
                B => Audio::PortMIDI::Event.new(:$event-type, :$channel, data-one => 35, data-two => 127, timestamp => 0);

    react {
        whenever $code -> $ev {
            if $ev {
                my Audio::PortMIDI::Event @outevs;
                if $ev[0].event-type == SystemMessage && $ev[0].data-two != 0 {
                    my $data = $ev[0].data-two;
                    given $data {
                        when * +& 2 {
                            @outevs.push: %map<B>;
                            proceed
                        }
                        when * >= 8 {
                            @outevs.push: %map<R>;
                            proceed
                        }
                        when 12 {
                            @outevs.push: %map<S>;
                            proceed
                        }
                    }
                    $out.write(@outevs);
                }
            }
        }
    }
}
