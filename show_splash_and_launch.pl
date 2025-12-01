#!/usr/bin/perl
# Taipan Cursed - Animated Splash Screen Launcher
# Shows fullscreen animated pirate ship, then launches main game

use strict;
use warnings;
use Curses::UI;
use File::Basename;

# Load animated ship splash screen module
use lib dirname(__FILE__) . '/ascii_ship_animation';
require 'ship_animation.pl';

# Initialize Curses::UI
my $cui = Curses::UI->new(
    -color_support => 1,
    -clear_on_exit => 1,
);

# Load animation frames
my $num_splash_frames = ShipAnimation::load_frames();

# Get first frame
my $first_splash_frame = ShipAnimation::get_frame(0);
my $splash_text = join("\n", @$first_splash_frame);

# Create fullscreen splash window
my $splash_win = $cui->add(
    'splash_window', 'Window',
    -border => 0,
);

# Create splash screen viewer
my $splash_label = $splash_win->add(
    'splash_viewer', 'TextViewer',
    -text => $splash_text,
    -border => 0,
    -readonly => 1,
    -wrapping => 0,
);

# Animation state
my $splash_current_frame = 0;
my $should_exit = 0;

# Set up animation timer (10 fps)
$cui->set_timer(
    'splash_animation',
    sub {
        return if $should_exit;  # Stop updating if exiting

        # Get next frame
        my $frame = ShipAnimation::get_frame($splash_current_frame);
        my $frame_text = join("\n", @$frame);

        # Update splash screen
        $splash_label->text($frame_text);
        $cui->draw();

        # Advance to next frame (loop continuously)
        $splash_current_frame = ($splash_current_frame + 1) % $num_splash_frames;
    },
    0.1  # 10 fps
);

# Set up key binding to dismiss splash
$splash_label->set_binding(
    sub {
        $should_exit = 1;
        $cui->clear_timer('splash_animation');
        $cui->mainloopExit();
    },
    ''  # Any key
);

$splash_label->focus();

# Run splash screen
$cui->mainloop();

# After splash dismissed, launch main game
exec('perl', 'Taipan_2020_v2.1.2.pl') or die "Could not launch game: $!";
