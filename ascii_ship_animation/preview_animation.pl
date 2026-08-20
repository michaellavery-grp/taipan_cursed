#!/usr/bin/env perl
# ASCII Animation Preview - Play the pirate ship animation in terminal
use strict;
use warnings;
use Time::HiRes qw(sleep);

# Load the animation module
use lib '.';
require 'ship_animation.pl';

print "Loading animation frames...\n";
my $num_frames = ShipAnimation::load_frames();
print "Loaded $num_frames frames\n";
print "Starting animation in 2 seconds...\n";
sleep(2);

# Clear screen and play animation in a loop
my $loops = 3;  # Play 3 times
for (my $loop = 0; $loop < $loops; $loop++) {
    ShipAnimation::reset();

    for (my $i = 0; $i < $num_frames; $i++) {
        # Clear screen (ANSI escape code)
        print "\033[2J\033[H";

        # Get current frame
        my $frame = ShipAnimation::next_frame();

        # Print frame info
        print "=== Pirate Ship Animation ===\n";
        print "Loop: " . ($loop + 1) . "/$loops | Frame: " . ($i + 1) . "/$num_frames\n";
        print "=" x 40 . "\n\n";

        # Print the ASCII art
        foreach my $line (@$frame) {
            print "$line\n";
        }

        print "\n" . "=" x 40 . "\n";
        print "Press Ctrl+C to stop\n";

        # Delay between frames (~10 fps)
        sleep(0.1);
    }
}

# Clear screen one last time
print "\033[2J\033[H";
print "Animation complete!\n";
print "Total frames: $num_frames\n";
print "Duration: " . ($num_frames * 0.1) . " seconds per loop\n";
