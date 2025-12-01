#!/usr/bin/env perl
# Test Curses::UI splash screen with animated pirate ship
use strict;
use warnings;
use Curses::UI;
use Time::HiRes qw(time);

print STDERR "DEBUG: Script started\n";

# Load the animation module
use lib '.';
require 'ship_animation.pl';

print STDERR "DEBUG: Animation module loaded\n";

# Initialize Curses::UI
print STDERR "DEBUG: Initializing Curses::UI...\n";
my $cui = new Curses::UI(
    -clear_on_exit => 1,
    -color_support => 1,
);

print STDERR "DEBUG: Curses::UI initialized\n";

# Create main window
print STDERR "DEBUG: Creating main window...\n";
my $win = $cui->add(
    'main_window', 'Window',
    -border => 1,
    -title => 'Taipan Cursed - Splash Screen Test',
);

print STDERR "DEBUG: Main window created\n";

# Create text viewer for animation
print STDERR "DEBUG: Creating animation viewer...\n";
my $animation_viewer = $win->add(
    'animation', 'TextViewer',
    -x => 2,
    -y => 2,
    -width => 102,   # 100 chars + borders
    -height => 42,   # 40 lines + borders
    -border => 0,
    -readonly => 1,
    -text => '',
);

print STDERR "DEBUG: Animation viewer created\n";

# Create title text above animation
print STDERR "DEBUG: Creating title label...\n";
my $title_label = $win->add(
    'title', 'Label',
    -x => 2,
    -y => 1,
    -width => 102,
    -text => '⚓ TAIPAN CURSED ⚓',
    -bold => 1,
);

print STDERR "DEBUG: Title label created\n";

# Create status text below animation
print STDERR "DEBUG: Creating status label...\n";
my $status_label = $win->add(
    'status', 'Label',
    -x => 2,
    -y => 44,
    -width => 102,
    -text => 'Loading animation frames...',
);

print STDERR "DEBUG: Status label created\n";

# Draw initial UI
print STDERR "DEBUG: Drawing initial UI...\n";
$cui->draw();
print STDERR "DEBUG: Initial UI drawn\n";

# Load animation frames
print STDERR "DEBUG: Loading animation frames...\n";
my $num_frames = ShipAnimation::load_frames();
print STDERR "DEBUG: Loaded $num_frames frames\n";

$status_label->text("Loaded $num_frames frames. Starting animation...");
$cui->draw();
print STDERR "DEBUG: UI updated with frame count\n";

# Animation loop variables
my $current_frame = 0;
my $last_frame_time = time();
my $frame_duration = 0.1;  # 10 fps
my $animation_loops = 3;   # Play 3 times
my $current_loop = 0;

# Set up timer for animation
print STDERR "DEBUG: Setting up animation timer...\n";
$cui->set_timer(
    'animation_timer',
    sub {
        print STDERR "DEBUG: Timer callback fired (frame $current_frame)\n" if $current_frame % 10 == 0;
        my $current_time = time();

        # Check if it's time to update the frame
        if ($current_time - $last_frame_time >= $frame_duration) {
            # Get current frame
            my $frame = ShipAnimation::get_frame($current_frame);

            # Convert frame array to text
            my $frame_text = join("\n", @$frame);

            # Update the animation viewer
            $animation_viewer->text($frame_text);

            # Update status
            my $progress = int(($current_frame / $num_frames) * 100);
            $status_label->text(
                sprintf("Loop %d/%d | Frame %d/%d (%d%%) | Press 'q' to quit",
                    $current_loop + 1, $animation_loops,
                    $current_frame + 1, $num_frames,
                    $progress)
            );

            # Redraw
            $cui->draw();

            # Advance to next frame
            $current_frame++;

            # Check if we've completed all frames
            if ($current_frame >= $num_frames) {
                $current_frame = 0;
                $current_loop++;

                # Check if we've completed all loops
                if ($current_loop >= $animation_loops) {
                    # Stop animation
                    $cui->clear_timer('animation_timer');
                    $status_label->text("Animation complete! Press 'q' to quit");
                    $cui->draw();
                }
            }

            $last_frame_time = $current_time;
        }
    },
    0.01  # Check every 10ms
);

print STDERR "DEBUG: Animation timer set up\n";

# Set up key bindings
print STDERR "DEBUG: Setting up key bindings...\n";
$cui->set_binding(
    sub {
        $cui->clear_timer('animation_timer');
        exit(0);
    },
    'q'
);

$cui->set_binding(
    sub {
        $cui->clear_timer('animation_timer');
        exit(0);
    },
    "\cC"  # Ctrl+C
);

print STDERR "DEBUG: Key bindings set up\n";

# Main loop
print STDERR "DEBUG: Entering main loop...\n";
$cui->mainloop();

print STDERR "DEBUG: Main loop exited\n";
