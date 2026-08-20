#!/usr/bin/env perl
# Curses::UI animated splash screen with timer-based frame updates
use strict;
use warnings;
use Curses::UI;

print STDERR "DEBUG: Script started\n";

# Load the animation module
use lib '/Users/michaellavery/github/taipan_cursed/ascii_ship_animation';
require 'ship_animation.pl';

print STDERR "DEBUG: Loading animation frames...\n";
my $num_frames = ShipAnimation::load_frames();
print STDERR "DEBUG: Loaded $num_frames frames\n";

# Initialize Curses::UI
print STDERR "DEBUG: Initializing Curses::UI...\n";
my $cui = Curses::UI->new(
    -clear_on_exit => 1,
    -color_support => 1,
);

# Create main window
my $win = $cui->add('main_window', 'Window');

# Add title
my $title = $win->add(
    'title', 'Label',
    -y => 0,
    -text => "=" x 100 . "\n" . " " x 35 . "⚓ TAIPAN CURSED ⚓\n" . "=" x 100,
    -bold => 1,
);

# Add animation viewer using TextViewer
my $animation = $win->add(
    'animation', 'TextViewer',
    -y => 3,
    -width => 100,
    -height => 40,
    -text => '',
    -border => 0,
    -readonly => 1,
    -wrapping => 0,
);

# Add instructions
my $instructions = $win->add(
    'instructions', 'Label',
    -y => 45,
    -text => "Press 'q' to quit | Animating at 10 fps...",
    -bold => 1,
);

# Animation state
my $current_frame = 0;
my $frame_count = 0;
my $max_frames = $num_frames * 3;  # Play 3 loops

print STDERR "DEBUG: Setting up animation timer...\n";

# Set up timer for animation (10 fps = 0.1 seconds between frames)
$cui->set_timer(
    'animation_timer',
    sub {
        # Get current frame
        my $frame = ShipAnimation::get_frame($current_frame);
        my $frame_text = join("\n", @$frame);

        # Update the animation viewer
        $animation->text($frame_text);

        # Update status
        my $progress = int(($frame_count / $max_frames) * 100);
        $instructions->text(
            sprintf("Frame %d/%d (%d%%) | Press 'q' to quit",
                $frame_count + 1, $max_frames, $progress)
        );

        # Redraw
        $cui->draw();

        # Advance to next frame
        $current_frame = ($current_frame + 1) % $num_frames;
        $frame_count++;

        # Stop after 3 loops
        if ($frame_count >= $max_frames) {
            $cui->clear_timer('animation_timer');
            $instructions->text("Animation complete! Press 'q' to quit");
            $cui->draw();
        }
    },
    0.1  # 10 fps
);

print STDERR "DEBUG: Timer set up\n";

# Bind 'q' key to quit
$cui->set_binding(
    sub {
        print STDERR "DEBUG: Quit key pressed\n";
        $cui->clear_timer('animation_timer');
        exit(0);
    },
    'q'
);

# Bind Ctrl-C to quit
$cui->set_binding(
    sub {
        print STDERR "DEBUG: Ctrl-C pressed\n";
        $cui->clear_timer('animation_timer');
        exit(0);
    },
    "\cC"
);

$animation->focus();

print STDERR "DEBUG: Entering mainloop...\n";

# Start main loop
$cui->mainloop();

print STDERR "DEBUG: Mainloop exited\n";
