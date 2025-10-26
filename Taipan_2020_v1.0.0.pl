#!/usr/bin/perl
# Taipan game remake in Perl with Curses::UI.
# License is GPLv3 or later.
# Original game by Art Canfil, programmed by Jay Link.
# Curses version by Michael Lavery, enhanced with full game logic.

use strict;
use warnings;
use Curses::UI;
use Curses qw(KEY_ENTER KEY_RIGHT KEY_LEFT flushinp);  # Import KEY_ENTER, KEY_RIGHT, KEY_LEFT constants
use List::Util qw(shuffle);
use JSON;
use POSIX qw(strftime);
use File::Spec;

# Global variables
our $focus_menu = "ship_menu";
our @menus = qw(ship_menu trade_menu money_menu system_menu);
our %good_map = (o => 'opium', a => 'arms', s => 'silk', g => 'general');
our $choice = '';
our $prompt_label;  # Declare $prompt_label as a global variable
our $current_action;       # Declare $current_action as a global variable

# Menu object references for resetting
our ($ship_menu_obj, $trade_menu_obj, $money_menu_obj, $system_menu_obj);

# Set ESCDELAY to a low value to make the Escape key responsive (avoids 1-second delay)
$ENV{ESCDELAY} = 25;

# Ensure Curses::UI is installed: cpan Curses::UI
our $cui = new Curses::UI(
    -color_support => 1,
    -clear_on_exit => 1,
    -utf8 => 1,  # Enable UTF-8 support for the terminal
);

# Game data structures
our %player = (
    firm_name => '',
    cash => 0,
    debt => 0,  # Starting debt
    bank_balance => 0,  # Money deposited at Hong Kong bank
    ships => 1,
    guns => 1,
    hold_capacity => 60,  # Per ship (SC in original BASIC)
    cargo => { opium => 0, arms => 0, silk => 0, general => 0 },
    remaining => 60,  # Remaining hold space
    port => 'Hong Kong',
    map => 0, # Index of current map (multiple maps are used)
    date => { year => 1860, month => 1, day => 15 },
    damage => 0,  # DM in original BASIC - accumulated damage points
    last_visit => {},  # Track last visit date to each port for spoilage calculation
    last_interest_date => { year => 1860, month => 1, day => 15 },  # Track when interest was last paid
);

our @ports = ('Hong Kong', 'Shanghai', 'Nagasaki', 'Saigon', 'Manila', 'Batavia', 'Singapore');

# Multi-port warehouse system - 10,000 capacity per port
# Historical: Real traders had agents and storage in multiple treaty ports
our %warehouses = (
    'Hong Kong'  => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
    'Shanghai'   => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
    'Nagasaki'   => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
    'Saigon'     => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
    'Manila'     => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
    'Batavia'    => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
    'Singapore'  => { opium => 0, arms => 0, silk => 0, general => 0, capacity => 10000 },
);

# Port-specific risk levels for warehouse theft/spoilage
# Based on historical conditions in 1860s
our %port_risk = (
    'Hong Kong'  => 0.05,  # British controlled, safer
    'Shanghai'   => 0.15,  # Chaotic, Taiping Rebellion era
    'Nagasaki'   => 0.08,  # Japanese controlled
    'Saigon'     => 0.20,  # Frontier town, high theft
    'Manila'     => 0.12,  # Spanish colonial instability
    'Batavia'    => 0.10,  # Dutch controlled
    'Singapore'  => 0.06,  # British, well organized
);

# Define the ascii map text
our @filenames = ('ascii_taipan_map1.txt', 'ascii_taipan_map2.txt', 'ascii_taipan_map3.txt', 'ascii_taipan_map4.txt', 'ascii_taipan_map5.txt', 'ascii_taipan_map6.txt', 'ascii_taipan_map7.txt');
# create blank array to hold map text string values
our @map_text = ();
# Open files one at a time

foreach my $file (@filenames) {
    if (-e $file) {
        open my $fh, '<', $file or die "Cannot open '$file': $!";
        {
            local $/; # Temporarily undefine the input record separator
            # Read all lines from the current file into a temporary array
            my @current_file_lines = <$fh>;

            # Remove trailing newlines from each line
            chomp @current_file_lines;
            # Append the lines from the current file to the main map_text array
            push @map_text, @current_file_lines; 

            close $fh or die "Cannot close '$file': $!";
        }
    }
}


our %goods = (
    opium => { base_price => 5000, volatility => 0.8 },
    arms => { base_price => 250, volatility => 0.5 },
    silk => { base_price => 300, volatility => 0.4 },
    general => { base_price => 50, volatility => 0.3 },
);

our %port_prices;  # Will be generated per port

# References to price labels for updating
our ($opium_price_label, $arms_price_label, $silk_price_label, $general_price_label);

# Combat state variables
our $num_ships = "";
our $num_on_screen = 0;
our @ships_on_screen = (-1) x 10;  # Track up to 10 ships on screen (-1 = empty, 0+ = health)
our $orders = 0;  # 0: No orders, 1: Fight, 2: Run, 3: Throw Cargo
our $ok = 3;  # Escape chance factor
our $ik = 1;  # Escape chance increment
our $s0 = 10;  # Arbitrary constant for escape probability
our $id = 1;   # Difficulty factor (generic for now)
our $ec = 30;  # Enemy strength constant
our $ed = 10;  # Enemy damage constant
our $damage = 0;  # Ship damage (not fully implemented in Perl yet)
our $hold = $player{hold_capacity};  # Current hold space
our $plus_label;
our $bp = 10;  # Battle Power - affects encounter probability (starts at 10, like cash start)
our $li = 0;   # Li Yuen status (0 = not encountered yet, increases with encounters)
our $f1 = 1;   # Damage multiplier: 1 for regular pirates, 2 for Li Yuen

# Generate initial prices
sub generate_prices {
    foreach my $port (@ports) {
        foreach my $good (keys %goods) {
            my $base = $goods{$good}{base_price};
            my $vol = $goods{$good}{volatility};
            $port_prices{$port}{$good} = int($base * (1 + $vol * (rand() - 0.5)));
        }
    }
    update_prices();  # Update price labels after generating prices
}

generate_prices();

# Save Game Function
# use JSON to save player data to a file named after the firm and date
sub save_game {
    my $firm_name = $player{firm_name};
    my $date_str = sprintf("%04d-%02d-%02d", $player{date}{year}, $player{date}{month}, $player{date}{day});
    my $filename = File::Spec->catfile('saves', "${firm_name}_${date_str}.dat");
    mkdir 'saves' unless -d 'saves';

    # Check for overwrite
    if (-e $filename) {
        my $overwrite = $cui->add(
            'overwrite_dialog', 'Dialog::Basic',
            -title => 'Confirm Overwrite',
            -message => "VOC ledger $filename exists. Overwrite?",
            -buttons => ['yes', 'no'],
        );
        my $response = $overwrite->get();
        $cui->delete('overwrite_dialog');
        return if $response eq 'no';
    }

    # Save game data
    eval {
        open my $fh, '>', $filename or die "Cannot open $filename: $!";
        print $fh encode_json(\%player);
        close $fh;
        $cui->dialog("VOC ledger saved as $filename!");
    };
    if ($@) {
        $cui->error("Failed to save VOC ledger: $@");
    }
}

# Load Game Function
sub load_game {
    # Ensure saves directory exists
    mkdir 'saves' unless -d 'saves';

    # Open file browser starting in the saves directory
    my $filename = $cui->filebrowser(-path => 'saves');
    if (defined $filename && $filename ne '') {
        open my $fh, '<:utf8', $filename or die "Cannot open $filename: $!";
        local $/;
        my $json = <$fh>;
        close $fh;

        # Safeguard against undef (empty file)
        $json //= '';  # Set to empty string if undef
        # Trim whitespace and control characters
        $json =~ s/^\s+|\s+$//g;
        $json =~ s/\x00//g; # Remove null bytes

        # Check if JSON is empty after trimming
        if ($json eq '') {
            die "Empty or invalid file: $filename";
        }

        my $loaded_data = decode_json($json);
        %player = %$loaded_data;

        # Regenerate prices after loading (prices are not saved, only player data)
        generate_prices();
    }
    else {
    return; # User cancelled
    }
}

# Advance date by days
sub advance_date {
    my $days = shift;
    $player{date}{day} += $days;
    while ($player{date}{day} > 30) {
        $player{date}{day} -= 30;
        $player{date}{month}++;
        if ($player{date}{month} > 12) {
            $player{date}{month} = 1;
            $player{date}{year}++;
        }
    }
}

# Set screen dimensions
my $screen_height = 40;  # Standard 120x40 terminal
my $screen_width = 120;

# Menubar occupies the top line (y=0), so available height for windows is 39
my $left_width = 80;
my $right_width = 40;

# Add top-left window (80x27)
my $top_left = $cui->add(
    'top_left',
    'Window',
    -x => 0,
    -y => 1,  # Start below menubar
    -width => 80,
    -height => 27,
    -border => 1,
    -title => 'Known World',
    -bfg => 'black',
    -bbg => 'green',
);

# Add bottom-bottom-left window (80x6) for text input
# make it a global variable so it can be accessed in random_event
our $bottom_bottom_left = $cui->add(
    'bottom_bottom_left',
    'Window',
    -x => 0,
    -y => 34,
    -width => 80,
    -height => 6,
    -border => 0,
    -title => 'Text Input',
    -bfg => 'black',
    -bbg => 'green',
);

# Draw combat with opposing pirates and Li Yuen's fleet
# Use ASCII art for draw_lorcha
# This function now draws a single lorcha at specified coordinates
sub draw_lorcha {
    my ($x, $y) = @_;
    my $lorcha = "-|-_|_  \n-|-_|_  \n_|__|__/\n\\_____/";

    # Find which slot this corresponds to (0-9)
    my $slot = -1;
    for (my $i = 0; $i < 10; $i++) {
        my $slot_x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
        my $slot_y = ($i < 5) ? 6 : 12;
        if ($x == $slot_x && $y == $slot_y) {
            $slot = $i;
            last;
        }
    }

    # If we found a valid slot, draw it
    if ($slot >= 0) {
        # Delete existing lorcha label if it exists
        if ($top_left->getobj("lorcha$slot")) {
            $top_left->delete("lorcha$slot");
        }

        my $lorcha_label = $top_left->add(
            "lorcha$slot", 'Label',
            -x => $x,
            -y => $y,
            -width => 9,
            -height => 4,
            -text => $lorcha,
            -multi => 1,  # Enable multi-line text
            -fg => 'white',
            -bg => 'black',
        );
        $lorcha_label->draw();
    }
}

# Draw all lorchas on screen based on the ships_on_screen array
sub draw_all_lorchas {
    for (my $i = 0; $i < 10; $i++) {
        if ($ships_on_screen[$i] > 0) {
            my $x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
            my $y = ($i < 5) ? 6 : 12;
            draw_lorcha($x, $y);
        }
    }
}

sub clear_lorcha {
    my ($x, $y) = @_;

    # Find which slot this corresponds to (0-9)
    my $slot = -1;
    for (my $i = 0; $i < 10; $i++) {
        my $slot_x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
        my $slot_y = ($i < 5) ? 6 : 12;
        if ($x == $slot_x && $y == $slot_y) {
            $slot = $i;
            last;
        }
    }

    # If we found a valid slot, clear it
    if ($slot >= 0) {
        # Delete the lorcha label if it exists
        if ($top_left->getobj("lorcha$slot")) {
            $top_left->delete("lorcha$slot");
        }

        # Draw blank space
        my $clear_label = $top_left->add(
            "lorcha$slot", 'Label',
            -x => $x,
            -y => $y,
            -width => 8,
            -height => 4,
            -text => "        \n" x 4,
            -fg => 'white',
            -bg => 'black',
        );
        $clear_label->draw();
        $top_left->delete("lorcha$slot");
    }
}

sub draw_blast {
    my ($x, $y) = @_;

    # Delete existing blast if it exists (safety check)
    if ($top_left->getobj("blast")) {
        $top_left->delete("blast");
    }

    $top_left->add(
        "blast", 'Label',
        -x => $x,
        -y => $y,
        -width => 8,
        -height => 4,
        -text => "********\n" x 4,
        -fg => 'white',
        -bg => 'black',
    )->draw();
    $top_left->delete("blast");
}

sub sink_lorcha {
    my ($x, $y) = @_;
    my $delay = int(rand(20));

    # Find which slot this corresponds to (0-9)
    my $slot = -1;
    for (my $i = 0; $i < 10; $i++) {
        my $slot_x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
        my $slot_y = ($i < 5) ? 6 : 12;
        if ($x == $slot_x && $y == $slot_y) {
            $slot = $i;
            last;
        }
    }

    return if $slot < 0;  # Invalid slot

    my @stages = (
        "        \n-|-_|_  \n-|-_|_  \n_|__|__/",
        "        \n        \n-|-_|_  \n-|-_|_  ",
        "        \n        \n        \n-|-_|_  ",
        "        \n        \n        \n        ",
    );

    for my $stage (@stages) {
        # Delete existing label
        if ($top_left->getobj("lorcha$slot")) {
            $top_left->delete("lorcha$slot");
        }

        $top_left->add(
            "lorcha$slot", 'Label',
            -x => $x,
            -y => $y,
            -width => 9,
            -height => 4,
            -text => $stage,
            -multi => 1,  # Enable multi-line text
            -fg => 'white',
            -bg => 'black',
        )->draw();
        select(undef, undef, undef, 0.5);
        if ($delay == 0) {
            select(undef, undef, undef, 0.5);
        }
    }
    # Final cleanup
    if ($top_left->getobj("lorcha$slot")) {
        $top_left->delete("lorcha$slot");
    }
}

sub fight_stats {
    my ($ships, $orders) = @_;
    my $ch_orders = $orders == 0 ? "" : $orders == 1 ? "Fight      " : $orders == 2 ? "Run        " : "Throw Cargo";
    my $total_firepower = $player{ships} * $player{guns};
    my $text = sprintf("%4d %s attacking, Taipan!\nYour orders are to: %s\n|  We have %d ships\n|  %d guns each (%d total)\n----------",
                       $ships, $ships == 1 ? "ship" : "ships", $ch_orders, $player{ships}, $player{guns}, $total_firepower);

    # Delete existing fight_stats label if it exists
    if ($top_left->getobj('fight_stats')) {
        $top_left->delete('fight_stats');
    }

    $top_left->add(
        'fight_stats', 'Label',
        -x => 0,
        -y => 0,
        -width => 50,
        -height => 5,
        -text => $text,
        -fg => 'white',
        -bg => 'black',
    )->draw();

    # Delete existing plus_label if it exists
    if ($top_left->getobj('plus_label')) {
        $top_left->delete('plus_label');
    }

    # Add plus label for off-screen ships
    $top_left->add(
        'plus_label', 'Label',
        -x => 62,
        -y => 11,
        -width => 1,
        -text => "",
        -fg => 'white',
        -bg => 'black',
    );
}
# Random events (e.g., pirates)
# Original Taipan probability system:
# Two-stage checking:
#   Stage 1: FN R(BP) - determines if ANY encounter occurs (1 in BP chance)
#   Stage 2: FN R(4 + 8 * LI) - determines Li Yuen vs regular pirates
# Fleet sizes:
#   Regular: FN R(SC/10 + GN) + 1 ships, damage multiplier F1=1
#   Li Yuen: FN R(SC/5 + GN) + 5 ships, damage multiplier F1=2
# Combat state variables are now declared at the top of the file (lines 92-107)


sub fight_run_throw {
    # get the passed parameter and set our orders variable
    my $orders = shift || '';
    if ($orders == 1) {  # Fight
        if ($player{guns} > 0) {
            my $sk = 0;  # Sunk ships

            # Calculate total firepower: ships * guns per ship
            my $total_firepower = $player{ships} * $player{guns};

            $cui->dialog("Aye, we'll fight 'em, Taipan!");
            sleep(1);
            $cui->dialog("All $player{ships} ships firing with $player{guns} guns each! Total firepower: $total_firepower!");

            # Opening salvo - flash all visible enemy ships!
            for (my $i = 0; $i < 10; $i++) {
                if ($ships_on_screen[$i] > 0) {
                    my $x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
                    my $y = ($i < 5) ? 6 : 12;
                    draw_blast($x, $y);
                }
            }
            select(undef, undef, undef, 0.3);

            # Redraw all ships after opening salvo
            for (my $i = 0; $i < 10; $i++) {
                if ($ships_on_screen[$i] > 0) {
                    my $x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
                    my $y = ($i < 5) ? 6 : 12;
                    draw_lorcha($x, $y);
                }
            }
            select(undef, undef, undef, 0.5);

            # Fire in volleys for more exciting combat!
            # Calculate volley size (fire multiple guns at once)
            my $volley_size = $player{guns} > 5 ? int($player{guns} / 2) : $player{guns};
            $volley_size = 10 if $volley_size > 10;  # Cap at 10 simultaneous shots

            my $shots_fired = 0;
            while ($shots_fired < $total_firepower && $num_ships > 0) {
                # Replenish on-screen ships if needed
                if ($num_ships > $num_on_screen) {
                    for (my $j = 0; $j <= 9 && $num_ships > $num_on_screen; $j++) {
                        if ($ships_on_screen[$j] <= 0) {  # Empty or sunk slot
                            my $x = ($j < 5) ? (10 + $j * 10) : (10 + ($j - 5) * 10);
                            my $y = ($j < 5) ? 6 : 12;
                            $ships_on_screen[$j] = int($ec * rand() + 20);
                            draw_lorcha($x, $y);
                            $num_on_screen++;
                            select(undef, undef, undef, 0.1);
                        }
                    }
                }

                $plus_label = $top_left->getobj('plus_label');
                $plus_label->text($num_ships > $num_on_screen ? "+" : " ");
                $plus_label->draw();

                # Fire a volley of shots!
                my @targets_hit = ();
                my $this_volley = ($shots_fired + $volley_size > $total_firepower) ?
                                  ($total_firepower - $shots_fired) : $volley_size;

                for (my $v = 0; $v < $this_volley && $num_ships > 0; $v++) {
                    # Pick a random target
                    my $targeted = int(rand(10));
                    my $attempts = 0;
                    while ($ships_on_screen[$targeted] <= 0 && $attempts < 20) {
                        $targeted = int(rand(10));
                        $attempts++;
                    }
                    next if $ships_on_screen[$targeted] <= 0;  # Skip if no valid target

                    my $x = ($targeted < 5) ? (10 + $targeted * 10) : (10 + ($targeted - 5) * 10);
                    my $y = ($targeted < 5) ? 6 : 12;

                    # Add to targets list for blast animation
                    push @targets_hit, { slot => $targeted, x => $x, y => $y };

                    # Apply damage
                    $ships_on_screen[$targeted] -= int(rand(30) + 10);
                }

                # Show all blasts simultaneously!
                foreach my $target (@targets_hit) {
                    draw_blast($target->{x}, $target->{y});
                }
                select(undef, undef, undef, 0.2);

                # Redraw ships
                foreach my $target (@targets_hit) {
                    draw_lorcha($target->{x}, $target->{y}) if $ships_on_screen[$target->{slot}] > 0;
                }
                select(undef, undef, undef, 0.2);

                # Another blast!
                foreach my $target (@targets_hit) {
                    draw_blast($target->{x}, $target->{y}) if $ships_on_screen[$target->{slot}] > 0;
                }
                select(undef, undef, undef, 0.2);

                # Check for sunk ships and animate them
                # IMPORTANT: We check each slot once per volley to avoid double-counting
                my @sinking_ships = ();
                my %slots_checked = ();  # Track which slots we've already processed

                foreach my $target (@targets_hit) {
                    my $slot = $target->{slot};

                    # Skip if we already checked this slot in this volley
                    next if $slots_checked{$slot};
                    $slots_checked{$slot} = 1;

                    # Ship sinks if health <= 0 (includes exactly 0!)
                    # Use a negative marker (-1) to indicate "already sunk" vs "active with 0 health"
                    if ($ships_on_screen[$slot] <= 0 && $ships_on_screen[$slot] > -1) {
                        push @sinking_ships, $target;
                        $num_on_screen--;
                        $num_ships--;
                        $sk++;
                        # Mark as sunk with -1 (not 0, which could be confused with "just reached 0 health")
                        $ships_on_screen[$slot] = -1;
                    }
                }

                # Sink all destroyed ships with dramatic animation!
                foreach my $target (@sinking_ships) {
                    sink_lorcha($target->{x}, $target->{y});
                }

                if (@sinking_ships > 0) {
                    fight_stats($num_ships, $orders);
                }

                $shots_fired += $this_volley;
                select(undef, undef, undef, 0.3);
            }

            # Enemy ships return fire! Apply damage to player ONCE per combat round
            # (AFTER all our volleys complete, not inside the volley loop!)
            # Original formula: DM = DM + FN R(ED * I * F1) + I / 2
            # Where: ED = damage severity, I = num_ships, F1 = damage multiplier
            if ($num_ships > 0) {
                # Scale ED down (original used 0.5, we use 10/20, so divide by 20)
                my $ed_scaled = $ed / 20.0;
                my $damage_taken = int(rand($ed_scaled * $num_ships * $f1)) + int($num_ships / 2);
                $player{damage} += $damage_taken;

                # Check seaworthiness after taking damage
                my $seaworthy = calculate_seaworthiness();
                if ($seaworthy <= 0) {
                    $cui->dialog("We're taking on water, Taipan! The ship is sinking!");
                    sleep(2);
                    $cui->dialog("Your fleet has been lost at sea...");
                    sleep(2);
                    exit(0);  # Game over!
                } elsif ($seaworthy < 30) {
                    $cui->dialog("Took $damage_taken damage! Hull integrity: ${seaworthy}% - We need repairs soon!");
                } elsif ($damage_taken > 5) {
                    $cui->dialog("Took $damage_taken damage from enemy fire!");
                }
            }

            # Check if all ships are destroyed or just some sunk
            if ($num_ships == 0 && $sk > 0) {
                $cui->dialog("We got 'em all, Taipan!");
            } elsif ($sk > 0) {
                $cui->dialog("Sunk $sk of the buggers, Taipan!");
            } else {
                $cui->dialog("Hit 'em, but didn't sink 'em, Taipan!");
            }
            sleep(1);

            # Update status to show new damage level
            update_status();
        }  # Close if ($player{guns} > 0)
    }  # Close if ($orders == 1)
    elsif ($orders == 2) {
        $cui->dialog("Aye, we'll run, Taipan.");
        sleep(1);
        $ok += $ik++;
        if (rand() * $ok > rand() * $num_ships) {
            $cui->dialog("We got away from 'em, Taipan!");
            $num_ships = 0;
            sleep(1);
        } else {
            $cui->dialog("Couldn't lose 'em.");
            sleep(1);
            if ($num_ships > 2 && rand() * 5 < 1) {
                my $lost = int(rand($num_ships / 2) + 1);
                $num_ships -= $lost;
                fight_stats($num_ships, $orders);
                $cui->dialog("But we escaped from $lost of 'em!");
                if ($num_ships <= 10) {
                    for (my $i = 9; $i >= 0 && $num_on_screen > $num_ships; $i--) {
                        if ($ships_on_screen[$i] > 0) {
                            $ships_on_screen[$i] = -1;  # Mark as gone
                            $num_on_screen--;
                            my $x = ($i < 5) ? (($i + 1) * 10) : (($i - 4) * 10);
                            my $y = ($i < 5) ? 6 : 12;
                            clear_lorcha($x, $y);
                            select(undef, undef, undef, 0.1);
                        }
                    }
                    $plus_label->text($num_ships > $num_on_screen ? "+" : " ");
                    $plus_label->draw();
                }
                sleep(1);
            }
        }
    }
    elsif ($orders == 3) {
        # Throw cargo
        if ($hold > 0) {
            my $thrown = int($hold / 3) + 1;
            $hold -= $thrown;
            $player{cargo}{opium} = $player{cargo}{opium} >= $thrown ? $player{cargo}{opium} - $thrown : 0;
            $player{cargo}{arms} = $player{cargo}{arms} >= $thrown ? $player{cargo}{arms} - $thrown : 0;
            $player{cargo}{silk} = $player{cargo}{silk} >= $thrown ? $player{cargo}{silk} - $thrown : 0;
            $player{cargo}{general} = $player{cargo}{general} >= $thrown ? $player{cargo}{general} - $thrown : 0;
            update_hold();
            fight_stats($num_ships, $orders);
            $cui->dialog("Threw $thrown units of cargo overboard, Taipan!");
            sleep(1);
            if (rand() * 5 < 1) {
                my $lost = int(rand($num_ships / 2) + 1);
                $num_ships -= $lost;
                fight_stats($num_ships, $orders);
                $cui->dialog("The pirates stopped to pick up our cargo! We escaped from $lost of 'em!");
                if ($num_ships <= 10) {
                    for (my $i = 9; $i >= 0 && $num_on_screen > $num_ships; $i--) {
                        if ($ships_on_screen[$i] > 0) {
                            $ships_on_screen[$i] = -1;  # Mark as gone
                            $num_on_screen--;
                            my $x = ($i < 5) ? (($i + 1) * 10) : (($i - 4) * 10);
                            my $y = ($i < 5) ? 6 : 12;
                            clear_lorcha($x, $y);
                            select(undef, undef, undef, 0.1);
                        }
                    }
                    $plus_label->text($num_ships > $num_on_screen ? "+" : " ");
                    $plus_label->draw();
                }
                sleep(1);
            }
        } else {
            $cui->error("No cargo to throw, Taipan!");
            sleep(1);
            fight_stats($num_ships, $orders);
        }
    }

    # Don't restore map here - let combat_loop decide when combat is over
    # draw_map() will be called by sail_to after combat is complete
}


# Declare global variables
our $bottom_top_left;      # Declare $bottom_top_left as a global variable
our $status_label;         # Declare $status_label as a global variable
our $hold_label;           # Declare $hold_label as a global variable
our $map_label;            # Declare $map_label as a global variable

# Define a subroutine for the exit dialog
sub exit_dialog {
    my $return = $cui->dialog(
        -fg => 'white',
        -bg => 'blue',
        -message => "Do you really want to quit?",
        -title   => "Are you sure???",
        -buttons => ['yes', 'no'],
    );
    exit(0) if $return;
}

# Retirement function - Original Taipan formula
sub retire {
    # Calculate net worth: CA + BA - DW
    my $net_worth = $player{cash} + $player{bank_balance} - $player{debt};

    # Calculate time index (TI) in months
    my $start_date = { year => 1860, month => 1, day => 15 };
    my $months = ($player{date}{year} - $start_date->{year}) * 12 +
                 ($player{date}{month} - $start_date->{month});
    $months = 1 if $months < 1;  # Avoid division by zero

    # Original formula: INT((CA + BA - DW) / 100 / TI ^ 1.1)
    my $score = int($net_worth / 100 / ($months ** 1.1));

    # Determine rank based on score
    my $rank;
    if ($score >= 50000) {
        $rank = "Ma Tsu";
    } elsif ($score >= 8000) {
        $rank = "Master $player{firm_name}";
    } elsif ($score >= 1000) {
        $rank = $player{firm_name};
    } elsif ($score >= 500) {
        $rank = "Compradore";
    } else {
        $rank = "Galley Hand";
    }

    # Calculate years and months for display
    my $years = int($months / 12);
    my $remaining_months = $months % 12;

    # Build retirement message
    my $msg = "Your Final Status:\n\n";
    $msg .= "Firm: $player{firm_name}\n";
    $msg .= "Net Worth: \$$net_worth\n";
    $msg .= "Ships: $player{ships}\n";
    $msg .= "Guns: $player{guns}\n";
    $msg .= "Trading Time: $years years, $remaining_months months\n\n";
    $msg .= "Final Score: $score\n";
    $msg .= "Rank: $rank\n\n";

    # Special messages
    if ($net_worth >= 1000000) {
        $msg .= "\n*** M I L L I O N A I R E ! ***\n\n";
        $msg .= "You have achieved the ultimate goal!\n";
        $msg .= "The Emperor himself acknowledges your success!";
    } elsif ($score < 0) {
        $msg .= "The crew has requested that you\n";
        $msg .= "stay on shore for their safety!!";
    } elsif ($rank eq "Ma Tsu") {
        $msg .= "You are a legend among traders!\n";
        $msg .= "Songs will be sung of your exploits!";
    } elsif ($rank eq "Galley Hand") {
        $msg .= "Perhaps trading is not your calling, Taipan.";
    }

    $cui->dialog($msg);
    sleep(2);

    # Show final prompt
    my $return = $cui->dialog(
        -message => "Retire from trading?",
        -buttons => ['yes', 'no'],
    );

    if ($return) {
        $cui->dialog("Fair winds and following seas, $player{firm_name}!");
        sleep(1);
        exit(0);
    }
}

# Add the menubar
my $menu = $cui->add(
    'menu',
    'Menubar',
    -fg => 'white',
    -bg => 'blue',
    -menu => [
        {
            -label => 'Taipan',
            -submenu => [
                { -label => 'About', -value => sub { $cui->error("About not implemented"); } },
                { -label => 'License', -value => sub { $cui->error("License not implemented"); } },
                { -label => 'Quit', -value => \&exit_dialog },
            ],
        },
    ],
);

# Unused keybindings - try to add escape back in to focus on menubar

# Make a splash screen using the C++ Taipan! ASCII art
my $splash_text = <<'END_SPLASH';
         _____  _    ___ ____   _    _   _               ===============
        |_   _|/ \  |_ _|  _ \ / \  | \ | |              Created by:
          | | / _ \  | || |_) / _ \ |  \| |                 Art Canfil
          | |/ ___ \ | ||  __/ ___ \| |\  |
          |_/_/   \_\___|_| /_/   \_\_| \_|              ===============
                                                         Programmed by:
   A game based on the China trade of the 1800's            Jay Link
                      ~~|     ,                          jaylink1971
                       ,|`-._/|                               @gmail.com
                     .' |   /||\                         ===============
                   .'   | ./ ||`\                        Curses version
                  / `-. |/._ ||  \                              by
                 /     `||   ||   \                      Michael Lavery
                 |      ||   ||__  \~^=~^~-~^~_~^~=      ===============
 ~=~^~ _~^~ =~ `--------|`---||  `"-`___~~^~ =_~^=        Press ANY key
~ ~^~=~^_~^~ =~ \~~~~~~~'~~~~'~~~~/~~`` ~=~^~ ~^=           to start.
 ~^=~^~_~-=~^~ ^ `--------------'~^~=~^~_~^=~^~=~
END_SPLASH
my $splash_label = $top_left->add( 
    'mysplashlabel', 'Label',
    -text => "$splash_text\n"
);

# Add top-right window (40x20)
my $top_right = $cui->add(
    'top_right',
    'Window',
    -x => 80,
    -y => 1,
    -width => 40,
    -height => 20,
    -border => 1,
    -title => 'Status',
    -bfg => 'black',
    -bbg => 'green',
);

$status_label = $top_right->add(
    'status_label',
    'Label',
    -x => 0,
    -y => 0,
    -width => 39,
    -height => 19,
    -multi => 1,
    -text => '',
    -fg => 'white',
    -bg => 'black',
);

# Add bottom-left windows (80x6 for controls, 80x6 for text input)
$bottom_top_left = $cui->add(
    'bottom_top_left',
    'Window',
    -x => 0,
    -y => 28,
    -width => 80,
    -height => 6,
    -border => 0,
    -title => 'Taipan Controls',
    -bfg => 'black',
    -bbg => 'green',
);



# Add bottom-right window for ship's hold (40x20)
my $bottom_right = $cui->add(
    'bottom_right',
    'Window',
    -x => 80,
    -y => 21,
    -width => 40,
    -height => 20,
    -border => 1,
    -title => 'Ships Hold',
    -bfg => 'black',
    -bbg => 'green',
);

$hold_label = $bottom_right->add(
    'hold_label',
    'Label',
    -x => 0,
    -y => 0,
    -width => 39,
    -height => 19,
    -multi => 1,
    -text => '',
    -fg => 'white',
    -bg => 'black',
);

# Variable to track current action
$current_action = '';

our $text_entry;

# Set starting balance
$player{cash} = 500;  # Starting cash

# Initialize input prompt before showing splash screen
input_prompt();

# Give focus to splash screen label
$splash_label->focus();

# Bind any unhandled key on splash to clear it and start game
$splash_label->set_binding( sub {
    clear_splash_screen();
}, '' );  # Empty string for default binding (handles unhandled keys)

# Start the main event loop
$cui->mainloop;

sub update_prices {
    return unless defined $opium_price_label;  # Skip if labels not yet initialized

    # Check if port and prices are valid
    if (!defined $player{port} || !exists $port_prices{$player{port}}) {
        # Regenerate prices if missing
        generate_prices();
    }

    # Safely update price labels with default to 0 if undefined
    $opium_price_label->text("Opium: " . ($port_prices{$player{port}}{opium} // 0));
    $arms_price_label->text("Arms: " . ($port_prices{$player{port}}{arms} // 0));
    $silk_price_label->text("Silk: " . ($port_prices{$player{port}}{silk} // 0));
    $general_price_label->text("General: " . ($port_prices{$player{port}}{general} // 0));
    $cui->draw(1);
}

sub input_prompt {
    #warn "Entering input_prompt\n";
    $prompt_label = $bottom_bottom_left->add(
        'prompt_label',
        'Label',
        -y => 0,
        -x => 0,
        -width => 79,
        -text => 'Taipan, What will you name your Firm? > ',
        -fg => 'white',
        -bg => 'black',
    );

    $text_entry = $bottom_bottom_left->add(
        'text_entry',
        'TextEntry',
        -y => 1,
        -x => 2,
        -width => 77,
        -single => 1,
        -fg => 'white',
        -bg => 'black',
    );

    $text_entry->set_binding( sub {
        my $value = $text_entry->get();
        # Trim leading/trailing whitespace
        $value =~ s/^\s+|\s+$//g if defined $value;
        if ($current_action eq 'name_firm') {
            $player{firm_name} = $value;
            update_status();
            main_loop();  # Proceed to main game loop after naming firm
        } elsif ($current_action eq 'buy_select_good') {
            my $letter = lc substr($value, 0, 1);
            if (exists $good_map{$letter}) {
                my $good = $good_map{$letter};
                $prompt_label->text("How many $good to buy? ");
                $text_entry->text('');
                $text_entry->focus();
                $current_action = "buy_$good";
            } else {
                $cui->error("Invalid good.");
                $prompt_label->text('Buy which good? (o/a/s/g) ');
                $text_entry->text('');
                $text_entry->focus();
            }
            return;
        } elsif ($current_action eq 'sell_select_good') {
            my $letter = lc substr($value, 0, 1);
            if (exists $good_map{$letter}) {
                my $good = $good_map{$letter};
                $prompt_label->text("How many $good to sell? ");
                $text_entry->text('');
                $text_entry->focus();
                $current_action = "sell_$good";
            } else {
                $cui->error("Invalid good.");
                $prompt_label->text('Sell which good? (o/a/s/g) ');
                $text_entry->text('');
                $text_entry->focus();
            }
            return;
        } elsif ($current_action eq 'buy_ships') {
            if ($value =~ /^\d+$/ && $value > 0) {
                buy_ships($value);
            } else {
                $cui->error("Invalid number.");
            }
        } elsif ($current_action eq 'buy_guns') {
            if ($value =~ /^\d+$/ && $value > 0) {
                buy_guns($value);
            } else {
                $cui->error("Invalid number.");
            }
        } elsif ($current_action =~ /^buy_(\w+)$/) {
            my $good = $1;
            if ($value =~ /^\d+$/ && $value > 0) {
                buy_good($good, $value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action =~ /^sell_(\w+)$/) {
            my $good = $1;
            if ($value =~ /^\d+$/ && $value > 0) {
                sell_good($good, $value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action eq 'repair_ship') {
            repair_ship();
        } elsif ($current_action eq 'repair_confirm') {
            if ($value =~ /^\d+$/ && $value >= 0) {
                do_repair($value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action eq 'sail_to') {
            sail_to($value);
        } elsif ($current_action eq 'deposit') {
            if ($value =~ /^\d+$/ && $value > 0) {
                deposit($value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action eq 'withdraw') {
            if ($value =~ /^\d+$/ && $value > 0) {
                withdraw($value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action eq 'borrow') {
            if ($value =~ /^\d+$/ && $value > 0) {
                borrow($value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action eq 'pay') {
            if ($value =~ /^\d+$/ && $value > 0) {
                pay_debt($value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action eq 'store_goods') {
            if ($value =~ /^(\w+) (\d+)$/) {
                my ($good, $amount) = ($1, $2);
                store_good($good, $amount);
            } else {
                $cui->error("Invalid input. Use: good amount");
            }
        } elsif ($current_action eq 'retrieve_goods') {
            if ($value =~ /^(\w+) (\d+)$/) {
                my ($good, $amount) = ($1, $2);
                retrieve_good($good, $amount);
            } else {
                $cui->error("Invalid input. Use: good amount");
            }
        } elsif ($current_action eq 'combat') {
            my $choice = uc substr($value, 0, 1);
            #warn "input_prompt: Combat choice=$choice\n";

            # Map choice to orders: F=1 (Fight), R=2 (Run), T=3 (Throw)
            if ($choice eq 'F') {
                $orders = 1;
                #warn "input_prompt: Orders set to Fight\n";
                fight_run_throw($orders);
                # Combat action is now processed, exit combat mode
                $current_action = '';
            } elsif ($choice eq 'R') {
                $orders = 2;
                #warn "input_prompt: Orders set to Run\n";
                fight_run_throw($orders);
                # Combat action is now processed, exit combat mode
                $current_action = '';
            } elsif ($choice eq 'T') {
                $orders = 3;
                #warn "input_prompt: Orders set to Throw\n";
                fight_run_throw($orders);
                # Combat action is now processed, exit combat mode
                $current_action = '';
            } else {
                $cui->error("Invalid choice. Use F, R, or T.");
                $prompt_label->text('Give orders to your crew (F)ight, (R)un, or (T)hrow cargo? ');
                $text_entry->text('');
                $text_entry->focus();
                #warn "input_prompt: Invalid combat choice\n";
                $cui->draw(1);
                return;
            }

            # Clear prompt and text after combat action
            $text_entry->text('');
            #warn "input_prompt: Combat action processed, current_action=$current_action, num_ships=$num_ships\n";
            return;
        }
        # Reset
        $prompt_label->text('> ');
        $text_entry->text('');
        $current_action = '';
        $bottom_top_left->getobj($focus_menu)->focus();
        $cui->draw(1); # Redraw UI
        #warn "input_prompt: Action completed, reset to menu focus\n";
    }, KEY_ENTER);
    # Ensure focus is set to text entry
    $cui->draw(1);
    $text_entry->focus();
    #warn "input_prompt: Initialized, focus on text_entry\n";
}

sub calculate_seaworthiness {
    # Original formula: 100 - INT(DM / SC * 100)
    # Returns percentage of ship integrity (100 = perfect, 0 = sinking)
    my $sc = $player{hold_capacity};
    return 100 if $sc == 0;  # Avoid division by zero
    my $seaworthy = 100 - int($player{damage} / $sc * 100);
    return $seaworthy < 0 ? 0 : $seaworthy;
}

sub update_status {
    my $month_name = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')[$player{date}{month} - 1];
    my $seaworthy = calculate_seaworthiness();

    # Calculate total net worth
    my $net_worth = $player{cash} + $player{bank_balance} - $player{debt};

    my $status_text = "Date: $player{date}{day} $month_name $player{date}{year}\nPort: $player{port}\nFirm: $player{firm_name}\nCash: \$$player{cash}\nBank: \$$player{bank_balance}\nDebt: \$$player{debt}\nNet Worth: \$$net_worth\nShips: $player{ships}\nGuns: $player{guns}\nCapacity: " . ($player{ships} * $player{hold_capacity}) . "\nSeaworthy: ${seaworthy}%\n";
    $status_label->text($status_text);
    update_hold();
    update_prices();  # Update price labels
    $cui->draw(1);

    # Check for automatic victory condition
    if ($net_worth >= 1000000) {
        check_victory();
    }
}

sub check_victory {
    # Only trigger once
    return if $player{victory_announced};
    $player{victory_announced} = 1;

    $cui->dialog("*** M I L L I O N A I R E ! ***\n\nCongratulations, Taipan!\n\nYou have achieved a net worth of over \$1,000,000!\n\nYou may continue trading or retire to see your final rank.");
}

sub update_hold {
    # Add a remaining space in hold calculation
    # Sum all cargo and subtract from total capacity
    $player{cargo}{remaining} = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});

    # Get current port's warehouse
    my $current_port = $player{port};
    my $wh = $warehouses{$current_port};

    # Calculate warehouse usage
    my $wh_used = $wh->{opium} + $wh->{arms} + $wh->{silk} + $wh->{general};
    my $wh_remaining = $wh->{capacity} - $wh_used;

    my $hold_text = "Opium: $player{cargo}{opium}\nArms: $player{cargo}{arms}\nSilk: $player{cargo}{silk}\nGeneral: $player{cargo}{general}\nRemaining: $player{cargo}{remaining}\n\n$current_port Warehouse:\nOpium: $wh->{opium}\nArms: $wh->{arms}\nSilk: $wh->{silk}\nGeneral: $wh->{general}\nFree: $wh_remaining";
    $hold_label->text($hold_text);
}

# Modified draw_map subroutine
sub draw_map {
    #warn "Entering draw_map: map index=$player{map}\n";
    # Remove existing map label if present
    if ($top_left->getobj('mymaplabel')) {
        $top_left->delete('mymaplabel');
        #warn "draw_map: Deleted existing mymaplabel\n";
    }
    # Select map text based on $player{map}
    my $current_map = $map_text[$player{map}] || '';
    if ($current_map eq '') {
        #warn "draw_map: No map data for index $player{map}\n";
        $current_map = "Map not available";
    }
    $map_label = $top_left->add(
        'mymaplabel',
        'Label',
        -x => 0,
        -y => 0, # Adjust to avoid overlapping radio buttons
        -text => $current_map,
        -multi => 1,
        -fg => 'white',
        -bg => 'black',
    );
    $cui->draw(1); # Force UI redraw
    #warn "draw_map: Map label added, UI redrawn\n";
}

# Initialize combat - draw initial ships on screen
sub init_combat {
    # Clear the map display to make room for combat graphics
    if ($top_left->getobj('mymaplabel')) {
        $top_left->delete('mymaplabel');
        #warn "init_combat: Deleted map label\n";
    }

    # The window already has a black background, no need for combat_bg
    # Just clear the window by forcing a redraw
    $top_left->draw();

    # Clear any existing lorcha labels
    for (my $i = 0; $i < 10; $i++) {
        if ($top_left->getobj("lorcha$i")) {
            $top_left->delete("lorcha$i");
        }
        $ships_on_screen[$i] = -1;  # Mark all slots as empty
    }
    $num_on_screen = 0;

    # Draw initial ships (up to 10 on screen)
    my $initial_ships = ($num_ships < 10) ? $num_ships : 10;
    for (my $i = 0; $i < $initial_ships; $i++) {
        my $x = ($i < 5) ? (10 + $i * 10) : (10 + ($i - 5) * 10);
        my $y = ($i < 5) ? 6 : 12;
        $ships_on_screen[$i] = int($ec * rand() + 20);  # Ship health
        draw_lorcha($x, $y);
        $num_on_screen++;
    }

    # Update the stats display
    fight_stats($num_ships, $orders);

    # Force a redraw to ensure all ships are visible
    $cui->draw(1);
}

# Combat loop - waits until combat is resolved
sub combat_loop {
    #warn "Entering combat_loop with $num_ships ships\n";

    # Show initial combat message
    $cui->dialog("Pirates attacking, Taipan! $num_ships " . ($num_ships == 1 ? "ship" : "ships") . " approaching!");

    # Combat continues while there are enemy ships
    while ($num_ships > 0) {
        $prompt_label->text('Give orders to your crew (F)ight, (R)un, or (T)hrow cargo? ');
        $text_entry->text('');
        $current_action = 'combat'; # Set current action to combat for input handling
        $cui->draw(1); # Force full UI redraw to ensure prompt is visible
        $text_entry->focus(); # Ensure text entry is focused

        # Wait for user to give combat orders
        # This will process events until the user makes a choice
        while ($current_action eq 'combat' && $num_ships > 0) {
            $cui->do_one_event();
        }

        # Check if combat ended (player escaped or destroyed all ships)
        if ($num_ships <= 0) {
            #warn "combat_loop: All enemy ships destroyed or escaped\n";
            last;
        }

        # If player is still in combat but didn't escape, continue the loop
        #warn "combat_loop: $num_ships ships remaining, continuing combat\n";
    }

    # Combat is over, check for Li Yuen confiscation
    #warn "combat_loop: Combat ended\n";

    # Li Yuen's Pirate Confiscation (Original Taipan)
    # If Li Yuen encounter ($f1 == 2) and player still has enemy ships remaining
    # Pirates can seize opium cargo and demand payment
    if ($f1 == 2 && $num_ships > 0) {
        # Player didn't destroy all of Li Yuen's fleet
        if ($player{cargo}{opium} > 0 || $player{cash} > 0) {
            my $opium_seized = $player{cargo}{opium};
            my $cash_demanded = int(rand($player{cash} / 1.8));  # Up to ~56% of cash

            if ($opium_seized > 0 || $cash_demanded > 0) {
                my $msg = "Li Yuen's remaining fleet boards your ships!\n\n";

                if ($opium_seized > 0) {
                    $player{cargo}{opium} = 0;
                    $msg .= "They confiscate ALL your opium ($opium_seized units)!\n";
                }

                if ($cash_demanded > 0 && $player{cash} >= $cash_demanded) {
                    $player{cash} -= $cash_demanded;
                    $msg .= "Li Yuen demands \$$cash_demanded as tribute!\n";
                }

                $msg .= "\n'You got off easy, Taipan!' laughs Li Yuen.";
                $cui->dialog($msg);
                sleep(2);
                update_status();
                update_hold();
            }
        }
    }

    $current_action = '';

    # Clear combat visuals from screen
    for (my $i = 0; $i < 10; $i++) {
        if ($top_left->getobj("lorcha$i")) {
            $top_left->delete("lorcha$i");
        }
    }

    # Clear fight stats if present
    if ($top_left->getobj('fight_stats')) {
        $top_left->delete('fight_stats');
    }
    if ($top_left->getobj('plus_label')) {
        $top_left->delete('plus_label');
    }

    # Reset prompt
    $prompt_label->text('> ');
    $text_entry->text('');
}

# Modified random_event subroutine - implements original Taipan probability system
sub random_event {
    #warn "Entering random_event\n";

    # STAGE 1: Check if ANY encounter occurs using Battle Power (BP)
    # Formula: FN R(BP) - returns 1 in BP chance
    # If random number (0 to BP-1) is NOT 0, no encounter occurs
    my $bp_check = int(rand($bp));
    #warn "random_event: BP=$bp, bp_check=$bp_check\n";

    if ($bp_check != 0) {
        # No encounter this time
        $current_action = 'sail_to';
        #warn "random_event: No encounter (BP check failed), returning\n";
        return;
    }

    # STAGE 2: Determine encounter type - Li Yuen vs Regular Pirates
    # Formula: FN R(4 + 8 * LI)
    # Higher LI value makes Li Yuen MORE likely
    my $li_check = int(rand(4 + 8 * $li));
    my $is_li_yuen = ($li_check == 0);  # If 0, it's Li Yuen!

    #warn "random_event: LI=$li, li_check=$li_check, is_li_yuen=$is_li_yuen\n";

    # Calculate fleet size based on encounter type
    # SC = ship capacity (we'll use hold_capacity as proxy)
    # GN = guns
    my $sc = $player{hold_capacity};
    my $gn = $player{guns};

    if ($is_li_yuen) {
        # Li Yuen's fleet: FN R(SC/5 + GN) + 5
        # Minimum 5 ships, can be MASSIVE
        $num_ships = int(rand(int($sc / 5) + $gn)) + 5;
        $ec = 60;  # Li Yuen ships are tougher
        $ed = 20;  # Li Yuen does more damage
        $f1 = 2;   # Li Yuen damage multiplier (2x damage to player)
        #warn "random_event: Li Yuen encounter! Fleet size: $num_ships\n";
    } else {
        # Regular pirates: FN R(SC/10 + GN) + 1
        $num_ships = int(rand(int($sc / 10) + $gn)) + 1;
        $ec = 30;  # Regular pirate strength (normal)
        $ed = 10;  # Regular damage
        $f1 = 1;   # Regular damage multiplier
        #warn "random_event: Regular pirate encounter! Fleet size: $num_ships\n";
    }

    # Cap at 9999 for display purposes
    if ($num_ships > 9999) {
        $num_ships = 9999;
    }

    # Ensure at least 1 ship
    $num_ships = 1 if $num_ships < 1;

    # Reset combat state
    $num_on_screen = 0;
    @ships_on_screen = (-1) x 10;  # Reset ship tracking array (all empty)
    $orders = 0;  # Reset orders
    $ok = 3; # Reset escape chance factor

    # Initialize combat display
    init_combat();

    # Show special message for Li Yuen encounters
    if ($is_li_yuen) {
        $cui->dialog("Li Yuen's FLEET approaching, Taipan! $num_ships warships on the horizon!");
        $li++;  # Increase Li Yuen encounter counter
    }

    # Enter combat loop - this blocks until combat is resolved
    combat_loop();

    # After combat, increase Battle Power (makes future encounters less likely)
    # This simulates player getting stronger/more experienced
    $bp++ if $bp < 20;  # Cap BP at 20 to keep some danger
    $ec += 2;  # Enemies get slightly tougher over time
    $ed += 1;  # And do more damage

    #warn "random_event: Combat completed, BP now $bp, EC=$ec, ED=$ed\n";
}

sub clear_splash_screen {
    $top_left->delete('mysplashlabel');
    draw_map();
    $prompt_label->text("Taipan, What will you name your Firm? > ");
    $text_entry->text('');
    $current_action = 'name_firm';
    $cui->draw(1);  # Force UI refresh
    $text_entry->focus();
}


sub move_menu {
    my $dir = shift;
    my $index = 0;
    for my $i (0 .. $#menus) {
        if ($menus[$i] eq $focus_menu) {
            $index = $i;
            last;
        }
    }
    $index = ($index + $dir) % @menus;
    $focus_menu = $menus[$index];
    $bottom_top_left->getobj($focus_menu)->focus();
}

sub draw_menu1 {
    $bottom_top_left->add(
        'ship_label',
        'Label',
        -y => 0,
        -x => 0,
        -width => 15,
        -textalignment => 'center',
        -text => 'SHIP',
        -htmltext => 1,
        -fg => 'red',
        -bg => 'white',
    );

    $ship_menu_obj = $bottom_top_left->add(
        'ship_menu',
        'Listbox',
        -y => 1,
        -x => 0,
        -width => 14,
        -height => 5,
        -values => ['Buy Ships', 'Sail to Port', 'Repair Ship', 'Buy Guns'],
        -border => 0,
        -vscrollbar => 1,
        -fg => 'white',
        -bg => 'black',
        -onchange => \&listbox_ship_menu_changed,
    );

    sub listbox_ship_menu_changed {
        my $this = shift;
        my $selected = $this->get();
        if (defined $selected) {
            if ($selected eq 'Buy Ships') {
                $prompt_label->text('Ships cost 10000 each, how many? ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'buy_ships';
            } elsif ($selected eq 'Buy Guns') {
                my $guns_cost_per_ship = 500;
                my $total_cost_example = $guns_cost_per_ship * $player{ships};
                $prompt_label->text("Guns cost \$$guns_cost_per_ship per gun per ship (\$$total_cost_example per gun for your $player{ships} ships). How many guns per ship? ");
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'buy_guns';
            } elsif ($selected eq 'Repair Ship') {
                repair_ship();
            } elsif ($selected eq 'Sail to Port') {
                $prompt_label->text('Sail to which port? ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'sail_to';
            }
            $this->clear_selection();
            $focus_menu = 'ship_menu';
        }
    }

}

sub draw_menu2 {
    $bottom_top_left->add(
        'trade_label',
        'Label',
        -y => 0,
        -x => 15,
        -width => 15,
        -textalignment => 'center',
        -text => 'TRADE',
        -htmltext => 1,
        -fg => 'red',
        -bg => 'white',
    );

    $trade_menu_obj = $bottom_top_left->add(
        'trade_menu',
        'Listbox',
        -y => 1,
        -x => 15,
        -width => 15,
        -height => 5,
        -values => ['Buy Goods', 'Sell Goods', 'Store Goods', 'Retrieve Goods'],
        -border => 0,
        -vscrollbar => 1,
        -fg => 'white',
        -bg => 'black',
        -onchange => \&listbox_trade_menu_changed,
    );

    sub listbox_trade_menu_changed{
        my $this = shift;
        my $selected = $this->get();
        if (defined $selected) {
            if ($selected eq 'Buy Goods') {
                buy_goods_menu();
            } elsif ($selected eq 'Sell Goods') {
                sell_goods_menu();
            } elsif ($selected eq 'Store Goods') {
                $prompt_label->text('Store which good and how much? (e.g., opium 10) ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'store_goods';
            } elsif ($selected eq 'Retrieve Goods') {
                $prompt_label->text('Retrieve which good and how much? (e.g., silk 50) ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'retrieve_goods';
            }
            $this->clear_selection();
            $focus_menu = 'trade_menu';
        }
    }
}

sub draw_menu3 {
    $bottom_top_left->add(
        'money_label',
        'Label',
        -y => 0,
        -x => 30,
        -width => 10,
        -textalignment => 'center',
        -text => 'MONEY',
        -htmltext => 1,
        -fg => 'red',
        -bg => 'white',
    );

    $money_menu_obj = $bottom_top_left->add(
        'money_menu',
        'Listbox',
        -y => 1,
        -x => 30,
        -width => 10,
        -height => 5,
        -values => ['Deposit', 'Withdraw', 'Borrow', 'Pay'],
        -border => 0,
        -vscrollbar => 1,
        -fg => 'white',
        -bg => 'black',
        -onchange => \&listbox_money_menu_changed,
    );

# Simplified orders_taipan (optional, can be removed if not needed elsewhere)
sub orders_taipan {
    #warn "Entering orders_taipan\n";
    $prompt_label->text('Give orders to your crew (F)ight, (R)un, or (T)hrow cargo? ');
    $text_entry->text('');
    $current_action = 'combat';
    $cui->draw(1); # Force UI redraw
    $text_entry->focus();
    #warn "orders_taipan: Prompt set, action=combat, focus on text_entry\n";
}

    sub listbox_money_menu_changed{
        my $this = shift;
        my $selected = $this->get();
        if (defined $selected) {
            if ($selected eq 'Borrow') {
                $prompt_label->text('Borrow how much? ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'borrow';
            } elsif ($selected eq 'Pay') {
                $prompt_label->text('Pay how much? ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'pay';
            } elsif ($selected eq 'Deposit') {
                $prompt_label->text('Deposit how much? ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'deposit';
            } elsif ($selected eq 'Withdraw') {
                $prompt_label->text('Withdraw how much? ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'withdraw';
            }
            $this->clear_selection;
            $focus_menu = 'money_menu';
        }
    }
}

sub draw_menu4 {
    $bottom_top_left->add(
        'system_label',
        'Label',
        -y => 0,
        -x => 40,
        -width => 5,
        -textalignment => 'center',
        -text => 'SYS',
        -htmltext => 1,
        -fg => 'red',
        -bg => 'white',
    );

    $system_menu_obj = $bottom_top_left->add(
        'system_menu',
        'Listbox',
        -y => 1,
        -x => 40,
        -width => 6,
        -height => 5,
        -values => ['Save', 'Load', 'Retire', 'Quit'],
        -border => 0,
        -vscrollbar => 1,
        -fg => 'white',
        -bg => 'black',
        -onchange => \&listbox_system_menu_changed,
    );

    sub listbox_system_menu_changed {
        my $this = shift;
        my $selected = $this->get();
        if (defined $selected) {
            if ($selected eq 'Quit') {
                exit_dialog();
            } elsif ($selected eq 'Save') {
                save_game();
            } elsif ($selected eq 'Load') {
                load_game();
                update_status();
                update_hold();
                update_prices();
            } elsif ($selected eq 'Retire') {
                retire();
            }
            $this->clear_selection;
            $focus_menu = 'system_menu';
        }
    }
}

sub draw_menu5 {
    $bottom_top_left->add(
        'prices_label',
        'Label',
        -y => 0,
        -x => 60,
        -width => 15,
        -textalignment => 'center',
        -text => 'PRICES',
        -htmltext => 1,
        -fg => 'red',
        -bg => 'blue',
    );

    $opium_price_label = $bottom_top_left->add(
        'opium_price',
        'Label',
        -y => 1,
        -x => 60,
        -width => 15,
        -text => "Opium: $port_prices{$player{port}}{opium}",
        -fg => 'white',
        -bg => 'black',
    );

    $arms_price_label = $bottom_top_left->add(
        'arms_price',
        'Label',
        -y => 2,
        -x => 60,
        -width => 15,
        -text => "Arms: $port_prices{$player{port}}{arms}",
        -fg => 'white',
        -bg => 'black',
    );

    $silk_price_label = $bottom_top_left->add(
        'silk_price',
        'Label',
        -y => 3,
        -x => 60,
        -width => 15,
        -text => "Silk: $port_prices{$player{port}}{silk}",
        -fg => 'white',
        -bg => 'black',
    );

    $general_price_label = $bottom_top_left->add(
        'general_price',
        'Label',
        -y => 4,
        -x => 60,
        -width => 15,
        -text => "General: $port_prices{$player{port}}{general}",
        -fg => 'white',
        -bg => 'black',
    );
}

sub buy_goods_menu {
    $prompt_label->text('Buy which good? (o/a/s/g) ');
    $text_entry->text('');
    $text_entry->focus();
    $current_action = 'buy_select_good';
}

sub sell_goods_menu {
    $prompt_label->text('Sell which good? (o/a/s/g) ');
    $text_entry->text('');
    $text_entry->focus();
    $current_action = 'sell_select_good';
}

sub buy_good {
    my ($good, $amount) = @_;

    # Safety check: ensure prices exist for current port
    if (!exists $port_prices{$player{port}} || !exists $port_prices{$player{port}}{$good}) {
        generate_prices();  # Regenerate if missing
    }

    my $price = $port_prices{$player{port}}{$good} * $amount;
    my $free_space = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});

    if ($amount > $free_space) {
        $cui->error("Not enough hold space. Need $amount units but only $free_space available.");
    } elsif ($price > $player{cash}) {
        $cui->error("Not enough cash. Need \$$price but only have \$$player{cash}.");
    } else {
        $player{cash} -= $price;
        $player{cargo}{$good} += $amount;
        $cui->dialog("Bought $amount $good for \$$price, Taipan!");
        update_status();
        update_hold();  # Update cargo hold display
    }
}

sub sell_good {
    my ($good, $amount) = @_;

    # Safety check: ensure prices exist for current port
    if (!exists $port_prices{$player{port}} || !exists $port_prices{$player{port}}{$good}) {
        generate_prices();  # Regenerate if missing
    }

    if ($amount > $player{cargo}{$good}) {
        $cui->error("Not enough $good to sell. You only have $player{cargo}{$good}.");
    } else {
        my $price = $port_prices{$player{port}}{$good} * $amount;
        $player{cash} += $price;
        $player{cargo}{$good} -= $amount;
        $cui->dialog("Sold $amount $good for \$$price, Taipan!");
        update_status();
        update_hold();  # Update cargo hold display
    }
}

sub store_good {
    my ($good, $amount) = @_;

    # Get current port's warehouse
    my $current_port = $player{port};
    my $wh = $warehouses{$current_port};

    # Check if player has enough cargo
    if ($amount > $player{cargo}{$good}) {
        $cui->error("Not enough $good to store. You only have $player{cargo}{$good}.");
        return;
    }

    # Check warehouse capacity
    my $wh_used = $wh->{opium} + $wh->{arms} + $wh->{silk} + $wh->{general};
    my $wh_remaining = $wh->{capacity} - $wh_used;

    if ($amount > $wh_remaining) {
        $cui->error("Warehouse in $current_port only has $wh_remaining units of space remaining!");
        return;
    }

    # Transfer from cargo to warehouse
    $player{cargo}{$good} -= $amount;
    $wh->{$good} += $amount;

    $cui->dialog("Stored $amount $good in $current_port warehouse.");
    update_status();
    update_hold();
}

sub retrieve_good {
    my ($good, $amount) = @_;

    # Get current port's warehouse
    my $current_port = $player{port};
    my $wh = $warehouses{$current_port};

    # Check if warehouse has enough
    if ($amount > $wh->{$good}) {
        $cui->error("Warehouse in $current_port only has $wh->{$good} $good stored!");
        return;
    }

    # Check ship capacity
    my $free_space = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});

    if ($amount > $free_space) {
        $cui->error("Not enough hold space. Need $amount units but only $free_space available.");
        return;
    }

    # Transfer from warehouse to cargo
    $wh->{$good} -= $amount;
    $player{cargo}{$good} += $amount;

    $cui->dialog("Retrieved $amount $good from $current_port warehouse.");
    update_status();
    update_hold();
}

sub buy_ships {
    my $amount = shift;

    # Validate input - check if defined, not empty, and numeric
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    # Convert to number explicitly
    $amount = int($amount);

    my $cost = 10000 * $amount;

    # Check if player has enough cash
    if ($cost > $player{cash}) {
        $cui->error("Not enough cash. Need \$$cost but only have \$$player{cash}.");
        return;
    }

    # Purchase ships
    $player{cash} -= $cost;
    $player{ships} += $amount;

    # Show confirmation with proper singular/plural
    my $ship_word = $amount == 1 ? "ship" : "ships";
    $cui->dialog("Bought $amount $ship_word for \$$cost, Taipan!");

    # Update displays (status shows ship count, hold shows new capacity)
    update_status();
    update_hold();  # Cargo capacity has increased!
}

sub buy_guns {
    my $amount = shift;

    # Validate input - check if defined, not empty, and numeric
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    # Convert to number explicitly
    $amount = int($amount);

    # Calculate cost: $500 per gun per ship (need to equip entire fleet!)
    my $total_guns_needed = $amount * $player{ships};
    my $cost = 500 * $total_guns_needed;

    # Check if player has enough cash
    if ($cost > $player{cash}) {
        $cui->error("Not enough cash. Need \$$cost to equip all $player{ships} ships but only have \$$player{cash}.");
        return;
    }

    # Purchase guns
    $player{cash} -= $cost;
    $player{guns} += $amount;

    # Show confirmation with proper singular/plural
    my $gun_word = $amount == 1 ? "gun" : "guns";
    my $ship_word = $player{ships} == 1 ? "ship" : "ships";
    $cui->dialog("Bought $amount $gun_word per ship for all $player{ships} $ship_word ($total_guns_needed guns total) for \$$cost, Taipan!");

    # Update status display
    update_status();
}

sub repair_ship {
    # Original Taipan repair system
    # Check if there's any damage
    if ($player{damage} <= 0) {
        $cui->dialog("Your fleet is in perfect condition, Taipan! No repairs needed.");
        return;
    }

    my $seaworthy = calculate_seaworthiness();
    my $damage_percent = 100 - $seaworthy;

    # Calculate repair cost per unit
    # Original: BR = INT((FN R(60 * (TI + 3) / 4) + 25 * (TI + 3) / 4) * SC / 50)
    # TI = time index (we'll use a simplified version based on game progress)
    # For now, use a simpler formula based on hold capacity
    my $sc = $player{hold_capacity};
    my $ti = int($bp / 2);  # Use battle power as time proxy
    my $br = int((rand(60 * ($ti + 3) / 4) + 25 * ($ti + 3) / 4) * $sc / 50);
    $br = 10 if $br < 10;  # Minimum cost per unit

    # Show damage assessment
    $cui->dialog("The shipwright examines your fleet...\n\n'${damage_percent}% of your ships are damaged, Taipan.\nRepairs cost \$$br per unit.\nYou have $player{damage} damage points.'");

    # Ask how much to spend on repairs
    $prompt_label->text("How much cash to spend on repairs? (0 to cancel) ");
    $text_entry->text('');
    $text_entry->focus();
    $current_action = 'repair_confirm';

    # Store repair rate for the confirm action
    $player{_temp_repair_rate} = $br;
}

sub do_repair {
    my $cash_spent = shift;

    # Cancel if 0
    if ($cash_spent == 0) {
        $cui->dialog("No repairs made, Taipan.");
        return;
    }

    # Check if player has enough cash
    if ($cash_spent > $player{cash}) {
        $cui->error("Not enough cash. You have \$$player{cash}.");
        return;
    }

    # Get stored repair rate
    my $br = $player{_temp_repair_rate} || 50;  # Default to 50 if not set

    # Calculate repair amount: WW = INT(W / BR + .5)
    my $repaired = int($cash_spent / $br + 0.5);

    # Can't repair more than current damage
    if ($repaired > $player{damage}) {
        $repaired = $player{damage};
        $cash_spent = $repaired * $br;  # Adjust cost
    }

    # Apply repairs
    $player{damage} -= $repaired;
    $player{cash} -= $cash_spent;

    # Clean up temp variable
    delete $player{_temp_repair_rate};

    my $new_seaworthy = calculate_seaworthiness();
    $cui->dialog("Repaired $repaired damage points for \$$cash_spent!\n\nHull integrity now: ${new_seaworthy}%");

    update_status();
}

sub check_port_events {
    my $port = shift;

    # 0. BANK INTEREST (Hong Kong only)
    if ($port eq 'Hong Kong') {
        apply_bank_interest();
    }

    # 1. ROBBERY EVENT (Original Taipan formula)
    # Trigger: CA > 25000 AND NOT(FN R(20))
    # Original: 5% chance (1 in 20) when cash > $25,000
    if ($player{cash} > 25000 && int(rand(20)) == 0) {
        # Amount stolen: I = FN R(CA/1.4) = random up to ~71% of cash
        my $stolen = int(rand($player{cash} / 1.4));
        $player{cash} -= $stolen;

        $cui->dialog("You've been beaten up and robbed of \$$stolen in the streets of $port, Taipan!!\n\nBe more careful carrying so much cash!");
        sleep(1);
    }

    # 2. WAREHOUSE SPOILAGE/THEFT
    # Check if we've been away from this port for a while
    my $wh = $warehouses{$port};
    my $risk = $port_risk{$port};

    # Calculate days since last visit
    if (exists $player{last_visit}{$port}) {
        my $last = $player{last_visit}{$port};
        my $days_away = ($player{date}{year} - $last->{year}) * 360 +
                        ($player{date}{month} - $last->{month}) * 30 +
                        ($player{date}{day} - $last->{day});

        # If away more than 60 days, check for theft/spoilage
        if ($days_away > 60) {
            my $theft_check = rand();
            if ($theft_check < $risk) {
                # Calculate losses (general > silk > opium/arms)
                my $general_loss = int($wh->{general} * rand(0.3));
                my $silk_loss = int($wh->{silk} * rand(0.2));
                my $opium_loss = int($wh->{opium} * rand(0.1));
                my $arms_loss = int($wh->{arms} * rand(0.1));

                my $total_loss = $general_loss + $silk_loss + $opium_loss + $arms_loss;

                if ($total_loss > 0) {
                    $wh->{general} -= $general_loss;
                    $wh->{silk} -= $silk_loss;
                    $wh->{opium} -= $opium_loss;
                    $wh->{arms} -= $arms_loss;

                    my $loss_msg = "Bad news, Taipan! Your warehouse in $port was away unattended for $days_away days.\n\n";
                    $loss_msg .= "Losses due to theft and spoilage:\n";
                    $loss_msg .= "General: $general_loss\n" if $general_loss > 0;
                    $loss_msg .= "Silk: $silk_loss\n" if $silk_loss > 0;
                    $loss_msg .= "Opium: $opium_loss\n" if $opium_loss > 0;
                    $loss_msg .= "Arms: $arms_loss\n" if $arms_loss > 0;
                    $loss_msg .= "\nTotal lost: $total_loss units";

                    $cui->dialog($loss_msg);
                    sleep(1);
                }
            }
        }
    }

    # Update last visit date for this port
    $player{last_visit}{$port} = {
        year => $player{date}{year},
        month => $player{date}{month},
        day => $player{date}{day}
    };
}

sub sail_to {
    my $new_port = shift;
    #warn "Entering sail_to: new_port=$new_port\n";
    if (grep { $_ eq $new_port } @ports) {
        if ($new_port eq $player{port}) {
            $cui->error("Already in $new_port.");
            #warn "sail_to: Already in $new_port, returning\n";
            return;
        }
        my $days = int(rand(10) + 5);  # Random travel time
        #warn "sail_to: Traveling for $days days\n";
        advance_date($days);
        $current_action = 'combat'; # in case we get in a fight after sailing for input_prompt
        random_event();
        #warn "sail_to: Returned from random_event\n";
        $player{port} = $new_port;
        $player{map} = (grep { $ports[$_] eq $new_port } 0..$#ports)[0] % @filenames;
        #warn "sail_to: Updated port to $player{port}, map index to $player{map}\n";
        generate_prices(); # Fluctuate prices and update labels
        #warn "sail_to: Prices generated\n";
        draw_map(); # Redraw map with new port indicator
        #warn "sail_to: Map drawn\n";
        $cui->dialog("Arrived in $new_port after $days days.");
        #warn "sail_to: Dialog displayed\n";

        # Check for random events at port
        check_port_events($new_port);

        update_status();
        #warn "sail_to: Status updated\n";

        # Clear the text entry and reset prompt after sailing
        $text_entry->text('');
        $prompt_label->text('> ');
        $current_action = '';

        #reset_menus(); # Clear menu selections on new port
        ##warn "sail_to: Menus reset\n";
        $cui->draw(1); # Force UI redraw
        $bottom_top_left->getobj($focus_menu)->focus();
        #warn "sail_to: UI redrawn, focus set to $focus_menu\n";
    } else {
        $cui->error("Invalid port.");
    }
}

sub calculate_interest_rate {
    # Sliding interest rate based on balance (historical 1860s Hong Kong banking)
    # Larger deposits get better rates
    my $balance = $player{bank_balance};

    if ($balance >= 100000) {
        return 0.05;  # 5% for large accounts (100k+)
    } elsif ($balance >= 50000) {
        return 0.045; # 4.5% for substantial accounts (50k-100k)
    } elsif ($balance >= 10000) {
        return 0.04;  # 4% for good accounts (10k-50k)
    } else {
        return 0.03;  # 3% for smaller accounts (<10k)
    }
}

sub deposit {
    my $amount = shift;

    # Validate input
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    $amount = int($amount);

    # Check if player has enough cash
    if ($amount > $player{cash}) {
        $cui->error("Not enough cash. You have \$$player{cash}.");
        return;
    }

    # Banking only available in Hong Kong
    if ($player{port} ne 'Hong Kong') {
        $cui->error("The Hong Kong & Shanghai Banking Corporation only operates in Hong Kong, Taipan!");
        return;
    }

    # Transfer to bank
    $player{cash} -= $amount;
    $player{bank_balance} += $amount;

    my $new_rate = calculate_interest_rate() * 100;
    $cui->dialog("Deposited \$$amount to your account at the Hong Kong & Shanghai Banking Corporation.\n\nNew balance: \$$player{bank_balance}\nCurrent interest rate: ${new_rate}%");

    update_status();
}

sub withdraw {
    my $amount = shift;

    # Validate input
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    $amount = int($amount);

    # Banking only available in Hong Kong
    if ($player{port} ne 'Hong Kong') {
        $cui->error("The Hong Kong & Shanghai Banking Corporation only operates in Hong Kong, Taipan!");
        return;
    }

    # Check if bank has enough
    if ($amount > $player{bank_balance}) {
        $cui->error("Insufficient funds. Your bank balance is \$$player{bank_balance}.");
        return;
    }

    # Withdraw from bank
    $player{bank_balance} -= $amount;
    $player{cash} += $amount;

    my $remaining_rate = calculate_interest_rate() * 100;
    $cui->dialog("Withdrew \$$amount from your account.\n\nRemaining balance: \$$player{bank_balance}\nCurrent interest rate: ${remaining_rate}%");

    update_status();
}

sub apply_bank_interest {
    # Calculate interest since last payment
    # Called when arriving in Hong Kong

    return if $player{bank_balance} <= 0;  # No balance, no interest

    my $last = $player{last_interest_date};
    my $days_elapsed = ($player{date}{year} - $last->{year}) * 360 +
                       ($player{date}{month} - $last->{month}) * 30 +
                       ($player{date}{day} - $last->{day});

    # Apply interest if at least 30 days have passed (1 month)
    if ($days_elapsed >= 30) {
        my $months = int($days_elapsed / 30);
        my $rate = calculate_interest_rate();

        # Calculate compound interest: balance * (1 + rate/12)^months
        my $monthly_rate = $rate / 12;
        my $multiplier = (1 + $monthly_rate) ** $months;
        my $new_balance = int($player{bank_balance} * $multiplier);
        my $interest_earned = $new_balance - $player{bank_balance};

        if ($interest_earned > 0) {
            $player{bank_balance} = $new_balance;

            my $annual_rate = $rate * 100;
            $cui->dialog("The Hong Kong & Shanghai Banking Corporation credits your account:\n\n$months months of interest at ${annual_rate}% annual rate\nInterest earned: \$$interest_earned\n\nNew balance: \$$player{bank_balance}");

            # Update last interest date
            $player{last_interest_date} = {
                year => $player{date}{year},
                month => $player{date}{month},
                day => $player{date}{day}
            };
        }
    }
}

sub borrow {
    my $amount = shift;

    # Validate input
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    # Convert to number explicitly
    $amount = int($amount);

    # Brother Wu is generous but has limits!
    my $max_loan = 50000;  # Maximum loan amount
    if ($amount > $max_loan) {
        $cui->error("Brother Wu says: 'Too much risk, Taipan! Maximum loan is \$$max_loan.'");
        return;
    }

    # Add to debt and cash
    $player{debt} += $amount;
    $player{cash} += $amount;
    $cui->dialog("Brother Wu says: 'Borrowed \$$amount at favorable rates, Taipan! Total debt now \$$player{debt}.'");
    update_status();
}

sub pay_debt {
    my $amount = shift;

    # Validate input
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    # Convert to number explicitly
    $amount = int($amount);

    # Check if no debt exists
    if ($player{debt} <= 0) {
        $cui->dialog("Brother Wu says: 'You owe nothing, Taipan! Your honor is intact.'");
        return;
    }

    # Check if player has enough cash
    if ($amount > $player{cash}) {
        $cui->error("Not enough cash. You have \$$player{cash} but trying to pay \$$amount.");
        return;
    }

    # Allow overpayment - Brother Wu will only take what's owed
    if ($amount > $player{debt}) {
        my $actual_payment = $player{debt};
        $player{cash} -= $actual_payment;
        $player{debt} = 0;
        $cui->dialog("Brother Wu says: 'You tried to pay \$$amount but only owed \$$actual_payment. Debt cleared, Taipan! Your honor shines bright!'");
    } else {
        # Normal payment
        $player{cash} -= $amount;
        $player{debt} -= $amount;
        my $remaining = $player{debt};
        if ($remaining > 0) {
            $cui->dialog("Paid \$$amount toward debt. Brother Wu says: 'Remaining debt: \$$remaining, Taipan.'");
        } else {
            $cui->dialog("Paid \$$amount. Brother Wu says: 'Debt cleared, Taipan! Your honor is restored!'");
        }
    }

    update_status();
}

sub main_loop {
    #draw_radio_buttons();
    draw_menu1();
    draw_menu2();
    draw_menu3();
    draw_menu4();
    draw_menu5();
    update_status();
    # Bind cursor right/left to move between menus
    $bottom_top_left->set_binding( sub { move_menu(1); }, KEY_RIGHT );
    $bottom_top_left->set_binding( sub { move_menu(-1); }, KEY_LEFT );
    $cui->draw(1);
    $bottom_top_left->getobj($focus_menu)->focus();
}