use Test;

plan 17;

use lib 'lib';

use Music::Helpers;

my $mode-name = Mode.modes.pick.key;
my $mode = Mode.new(mode => $mode-name, root => NoteName.pick);

isa-ok $mode, Mode, 'Creating a random mode works';
isa-ok $mode.tonic, Chord, '...and its tonic is actually a chord';
ok $mode.tonic ~~ min|maj|dim, '...and it\'s min, maj or dim as expected';

ok $mode.tonic.notes>>.name.sort eqv $mode.tonic.invert(1).notes>>.name.sort, 
    'inverting doesn\'t add or remove notes';

{
    # i'd like this ordered, please
    my @type-to-interval =  maj      => [M3, m3],
                            min      => [m3, M3],
                            dim      => [m3, m3],
                            aug      => [M3, M3],
                            maj6     => [M3, m3, M2],
                            min6     => [m3, M3, M2],
                            dom7     => [M3, m3, m3],
                            maj7     => [M3, m3, M3],
                            min7     => [m3, M3, m3],
                            dim7     => [m3, m3, m3],
                            halfdim7 => [m3, m3, M3],
                            aug7     => [M3, M3, M2],
                            minmaj7  => [m3, M3, M3];

    for @type-to-interval -> (:$key, :$value) {
        my @notes = Note.new(:48midi); # C4
        @notes.push: @notes[*-1] + $_ for @$value;
        my $chord = Chord.new(:@notes);
        ok $chord.chord-type eq $key, "$key chord in inversion 0";
    }
}
