#!/usr/bin/env perl
# Basic Curses::UI test
use strict;
use warnings;

print STDERR "DEBUG: Testing basic Curses::UI...\n";

eval {
    require Curses::UI;
    print STDERR "DEBUG: Curses::UI module loaded\n";

    my $cui = Curses::UI->new(
        -clear_on_exit => 1,
    );

    print STDERR "DEBUG: Curses::UI object created\n";

    my $win = $cui->add('win', 'Window');
    print STDERR "DEBUG: Window created\n";

    my $label = $win->add('label', 'Label', -text => 'Test');
    print STDERR "DEBUG: Label created\n";

    $cui->draw();
    print STDERR "DEBUG: Draw completed\n";

    # Exit immediately
    sleep(2);
    exit(0);
};

if ($@) {
    print STDERR "ERROR: $@\n";
    exit(1);
}
