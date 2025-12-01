#!/usr/bin/env perl
# Simple animated splash screen without Curses::UI
# Uses direct terminal control with ANSI codes
use strict;
use warnings;
use Time::HiRes qw(sleep);
use Term::ReadKey;

# Load the animation module
use lib '.';
require 'ship_animation.pl';

print STDERR "Loading animation frames...\n";
my $num_frames = ShipAnimation::load_frames();
print STDERR "Loaded $num_frames frames\n";

# Put terminal in raw mode for non-blocking input
ReadMode('cbreak');

# Hide cursor
print "\033[?25l";

# Clear screen
print "\033[2J\033[H";

my $loops = 3;  # Play 3 times
for (my $loop = 0; $loop < $loops; $loop++) {
    ShipAnimation::reset();

    for (my $i = 0; $i < $num_frames; $i++) {
        # Clear screen and move to home
        print "\033[2J\033[H";

        # Print title
        print "\033[1;33m";  # Bold yellow
        print "=" x 100 . "\n";
        print " " x 35 . "⚓ TAIPAN CURSED ⚓\n";
        print "=" x 100 . "\n";
        print "\033[0m";  # Reset color

        # Get and print current frame
        my $frame = ShipAnimation::next_frame();
        foreach my $line (@$frame) {
            print "$line\n";
        }

        # Print status
        print "\n";
        print "=" x 100 . "\n";
        print "\033[1;32m";  # Bold green
        printf("Loop %d/%d | Frame %d/%d (%d%%) | Press 'q' to quit\n",
            $loop + 1, $loops,
            $i + 1, $num_frames,
            int(($i / $num_frames) * 100));
        print "\033[0m";  # Reset color

        # Check for 'q' key (non-blocking)
        my $key = ReadKey(-1);
        if (defined $key && $key eq 'q') {
            # Clean up and exit
            print "\033[2J\033[H";  # Clear screen
            print "\033[?25h";      # Show cursor
            ReadMode('normal');
            exit(0);
        }

        # Frame delay (~10 fps)
        sleep(0.1);
    }
}

# Clean up
print "\033[2J\033[H";  # Clear screen
print "\033[?25h";      # Show cursor
ReadMode('normal');

print "\n\033[1;32mAnimation complete!\033[0m\n";
print "Total frames: $num_frames\n";
print "Duration: " . ($num_frames * 0.1) . " seconds per loop\n";
