#!/usr/bin/env perl
# Curses::UI animated splash screen test
# Mimics how Taipan Cursed handles splash screens
use strict;
use warnings;
use Curses::UI;

print STDERR "DEBUG: Script started\n";

# Load the animation module from the ascii_ship_animation directory
use lib '/Users/michaellavery/github/taipan_cursed/ascii_ship_animation';
require 'ship_animation.pl';

print STDERR "DEBUG: Animation module loaded\n";

# Load animation frames BEFORE initializing Curses
print STDERR "DEBUG: Loading animation frames...\n";
my $num_frames = ShipAnimation::load_frames();
print STDERR "DEBUG: Loaded $num_frames frames\n";

# Get first frame to display
my $first_frame = ShipAnimation::get_frame(0);
my $frame_text = join("\n", @$first_frame);

print STDERR "DEBUG: First frame prepared\n";

# Initialize Curses::UI
print STDERR "DEBUG: Initializing Curses::UI...\n";
my $cui = Curses::UI->new(
    -clear_on_exit => 1,
    -color_support => 1,
);

print STDERR "DEBUG: Curses::UI initialized\n";

# Create main window
my $win = $cui->add(
    'main_window', 'Window',
);

print STDERR "DEBUG: Main window created\n";

# Add title
my $title = $win->add(
    'title', 'Label',
    -y => 0,
    -text => "=" x 100 . "\n" . " " x 35 . "⚓ TAIPAN CURSED ⚓\n" . "=" x 100,
    -bold => 1,
);

# Add animation viewer using TextViewer (can receive focus)
my $animation = $win->add(
    'animation', 'TextViewer',
    -y => 3,
    -width => 100,
    -height => 40,
    -text => $frame_text,
    -border => 0,
    -readonly => 1,
);

# Add instructions
my $instructions = $win->add(
    'instructions', 'Label',
    -y => 45,
    -text => "Press ANY key to start...",
    -bold => 1,
);

print STDERR "DEBUG: Widgets created\n";

# Bind ANY key to close splash
$cui->set_binding(
    sub {
        print STDERR "DEBUG: Key pressed, exiting...\n";
        exit(0);
    },
    ''  # Empty string = any key
);

$animation->focus();

print STDERR "DEBUG: Animation focused\n";

print STDERR "DEBUG: Entering mainloop...\n";

# Start main loop
$cui->mainloop();

print STDERR "DEBUG: Mainloop exited\n";
