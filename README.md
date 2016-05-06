NAME
====

Music::Helpers - Abstractions for handling musical content

SYNOPSIS
========

    use Music::Helpers;

    my $mode = Mode.new(:root(C), :mode('major'))

    # prints 'C4 E4 G4 ==> C maj (inversion: 0)'
    say $mode.tonic.Str;

    # prints 'F4 A4 C5 ==> F maj (inversion: 0)'
    say $mode.next-chord($mode.tonic, intervals => [P4]).Str;

DESCRIPTION
===========

This module provides a few OO abstraction for handling musical content. Explicitly these are the classes `Mode`, `Chord` and `Note` as well as Enums `NoteName` and `Interval`. As anyone with even passing musical knowledge knows, `Mode`s and `Chord`s consists of `Note`s with one of those being the root and the others having a specific half-step distance from this root. As the main purpose for this module is utilizing these classes over MIDI (via [Audio::PortMIDI](https://github.com/jonathanstowe/Audio-PortMIDI/)), non-standard tunings will have to be handled by the instruments that play these notes.

A `Mode` knows, which natural triads it contains, and memoizes the `Note`s and `Chord`s on each step of the scale for probably more octaves than necessary. (That is, 10 octaves, from C-1 to C9, MIDI values 0 to 120.) Further, a `Chord` knows via a set of Roles applied at construction time, which kind of alterations on it are feasible. E.g:

    my $mode  = Mode.new(:root(F), :mode<major>);
    my $fmaj  = $mode.tonic;
    my $fdom7 = $fmaj.dom7;
    # prints 'F4 G4 C5 => F4 sus2 (inversion: 0)'
    say $fsus2.Str;

    my $mode = Mode.new(:root(F), :mode<minor>);
    my $fmin = $mode.tonic;
    # dies, "Method 'dom7' not found for invocant of class 'Music::Helpers::Chord+{Music::Helpers::min}'
    my $fdom7 = $fmin.dom7;

Although I do readily admit that not all possible alterations and augmentations are currently implemented. A `Chord` tells you, which variants it support via the methods `.variant-methods` and `.variant-roles`:

    my @notes = do [ Note.new(midi => $_ + 4 * P8) for C, E, G];
    my $chord = Chord.new(:@notes, :0inversion);

    # prints '[(sus2) (sus4) (maj6) (maj7) (dom7)]'
    say $chord.variant-roles;

    # prints '[sus2 sus4 maj6 maj7 dom7]'
    say $chord.variant-methods;

    # prints 'C4 E4 G4 B4 ==> C4 maj7 (inversion: 0)'
    say $chord.variant-methods[3]($chord);

Note that `.variant-methods` is usually what you want to use when trying to create a variant of a given `Chord`.

Further, positive and negative inversions are supported via the method `.invert`:

    # prints 'C5 F5 A5 ==> F5 maj (inversion: 2)'
    say $fmaj.invert(2).Str;

    # prints 'C4 F4 A4 ==> F4 maj (inversion: 2)'
    say $fmaj.invert(-1).Str;

Finally, a `Note` knows how to build a `Audio::PortMIDI::Event` that can be sent via a `Audio::PortMIDI::Stream`, and a `Chord` knows to ask the `Note`s it consists of for these Events:

    # prints a whole lot, not replicated for brevity
    say $fmaj.OnEvents;

Note that this documentation is a work in progress. The file bin/example.pl6 in this repository might be of interest.
