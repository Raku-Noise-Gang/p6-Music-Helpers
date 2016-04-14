use Test;

plan 4;

use lib 'lib';

use Music::Helpers;

my $mode-name = Mode.modes.pick.key;
my $mode = Mode.new(mode => $mode-name, root => NoteName.pick);

isa-ok $mode, Mode, 'Creating a random mode works';
isa-ok $mode.tonic, Chord, '...and its tonic is actually a chord';
ok $mode.tonic ~~ min|maj|dim, '...and it\'s min, maj or dim as expected';

ok $mode.tonic.notes>>.name.sort eqv $mode.tonic.invert(1).notes>>.name.sort, 
    'inverting doesn\'t add or remove notes';
