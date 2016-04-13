use Test;

plan 2;

use lib 'lib';

use Music::Helpers;

my $mode-name = Mode.modes.pick.key;
my $mode = Mode.new(mode => $mode-name, root => NoteName.pick);

isa-ok $mode, Mode, 'Creating a random mode works';
isa-ok $mode.tonic, Chord, '...and its tonic is actually a chord';
