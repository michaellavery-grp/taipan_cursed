#!/usr/bin/perl
# Taipan game remake in Perl with Curses::UI.
# License is GPLv3 or later.
# Original game by Art Canfil, programmed by Jay Link.
# Curses version by Michael Lavery, enhanced with full game logic.

use strict;
use warnings;
use utf8;
binmode(STDOUT, ':utf8');
use Curses::UI;
use Curses qw(KEY_ENTER KEY_RIGHT KEY_LEFT flushinp);  # Import KEY_ENTER, KEY_RIGHT, KEY_LEFT constants
use List::Util qw(shuffle);
use JSON;
use POSIX qw(strftime);
use File::Spec;

# Debug logging to file - relative path for portability
our $DEBUG_LOG = 'taipan_debug.log';
open(my $debug_fh, '>', $DEBUG_LOG) or die "Cannot open debug log: $!";
sub debug_log {
    my $msg = shift;
    print $debug_fh scalar(localtime) . ": $msg\n";
    $debug_fh->autoflush(1);
}

# Log that we started
debug_log("=== TAIPAN STARTED ===");

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
    bodyguards => 5,  # Number of bodyguards protecting against robbery
    bad_loan_count => 0,  # BL% - Counter for Elder Brother Wu emergency loans (increases interest)
    wu_escort => 0,  # WN flag - Whether Elder Brother Wu has sent an escort
    li_yuen_tribute => 0,  # LI flag - Whether you've paid tribute to Li Yuen (0=no, 1=yes)
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

# Per-port debt tracking - Elder Brother Wu's agents in each port
# Communications between ports are slow, so player can borrow from each port independently
# Each port has a 50,000 yen lending limit
our %port_debt = (
    'Hong Kong'  => 0,
    'Shanghai'   => 0,
    'Nagasaki'   => 0,
    'Saigon'     => 0,
    'Manila'     => 0,
    'Batavia'    => 0,
    'Singapore'  => 0,
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
    arms => { base_price => 1500, volatility => 0.667 },  # Range: 500-2500
    silk => { base_price => 370, volatility => 0.378 },   # Range: 230-510
    general => { base_price => 50, volatility => 0.3 },
);

our %port_prices;  # Will be generated per port

# Price trends: track direction and momentum for each port/good
our %price_trends;  # {port}{good} = {direction => 1/-1, momentum => 0.0-1.0}

# Hot deals tracking - prices 1+ std deviations from median, last 1 week
our %hot_deals = (
    high => [],  # Array of {port, good, price, expires => {year, month, day}}
    low => [],   # Array of {port, good, price, expires => {year, month, day}}
);

# References to price labels for updating
our ($opium_price_label, $arms_price_label, $silk_price_label, $general_price_label);

# Combat state variables
our $num_ships = "";
our $num_on_screen = 0;
our @ships_on_screen = (0) x 10;  # Track up to 10 ships on screen
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

# Initialize price trends for all ports/goods
sub initialize_trends {
    foreach my $port (@ports) {
        foreach my $good (keys %goods) {
            # Random initial direction (1 = up, -1 = down)
            my $direction = (rand() > 0.5) ? 1 : -1;
            # Initial momentum (0.3 to 0.7 range for moderate changes)
            my $momentum = 0.3 + rand(0.4);
            $price_trends{$port}{$good} = {
                direction => $direction,
                momentum => $momentum
            };
        }
    }
}

# Generate initial prices with random starting points
sub generate_initial_prices {
    foreach my $port (@ports) {
        foreach my $good (keys %goods) {
            my $base = $goods{$good}{base_price};
            my $vol = $goods{$good}{volatility};
            $port_prices{$port}{$good} = int($base * (1 + $vol * (rand() - 0.5)));
        }
    }
    update_prices();  # Update price labels after generating prices
}

# Update prices based on trends (called when sailing or time passes)
sub generate_prices {
    foreach my $port (@ports) {
        foreach my $good (keys %goods) {
            my $base = $goods{$good}{base_price};
            my $vol = $goods{$good}{volatility};
            my $current_price = $port_prices{$port}{$good};

            # Get trend info
            my $trend = $price_trends{$port}{$good};
            my $direction = $trend->{direction};
            my $momentum = $trend->{momentum};

            # Calculate price change based on trend
            # Small variation (1-5%) in the direction of the trend
            my $change_percent = $momentum * 0.05 * $direction;  # Max 5% change
            my $noise = (rand() - 0.5) * 0.02;  # +/- 1% random noise
            my $total_change = $change_percent + $noise;

            # Apply the change
            my $new_price = int($current_price * (1 + $total_change));

            # Keep prices within reasonable bounds (30% to 170% of base price)
            my $min_price = int($base * (1 - $vol));
            my $max_price = int($base * (1 + $vol));

            # Reverse trend if hitting bounds
            if ($new_price >= $max_price) {
                $new_price = $max_price;
                $trend->{direction} = -1;  # Start going down
                $trend->{momentum} = 0.4 + rand(0.3);  # New momentum
            } elsif ($new_price <= $min_price) {
                $new_price = $min_price;
                $trend->{direction} = 1;  # Start going up
                $trend->{momentum} = 0.4 + rand(0.3);  # New momentum
            } else {
                # Occasionally reverse trend or change momentum (10% chance)
                if (rand() < 0.1) {
                    $trend->{direction} *= -1;
                    $trend->{momentum} = 0.3 + rand(0.4);
                }
            }

            $port_prices{$port}{$good} = $new_price;
        }
    }
    update_prices();  # Update price labels after generating prices
}

# Initial setup
initialize_trends();
generate_initial_prices();
update_hot_deals();  # Initialize hot deals after generating prices

# Calculate median price for a good across all ports
sub calculate_median {
    my ($good) = @_;
    my @prices = sort { $a <=> $b } map { $port_prices{$_}{$good} } @ports;
    my $mid = int(@prices / 2);
    return @prices % 2 ? $prices[$mid] : ($prices[$mid-1] + $prices[$mid]) / 2;
}

# Calculate standard deviation for a good across all ports
sub calculate_std_dev {
    my ($good, $median) = @_;
    my @prices = map { $port_prices{$_}{$good} } @ports;
    my $sum_sq_diff = 0;
    foreach my $price (@prices) {
        $sum_sq_diff += ($price - $median) ** 2;
    }
    return sqrt($sum_sq_diff / @prices);
}

# Add days to a date, returning new date hash
sub add_days_to_date {
    my ($date_ref, $days_to_add) = @_;
    my %new_date = %$date_ref;
    $new_date{day} += $days_to_add;

    while ($new_date{day} > 30) {
        $new_date{day} -= 30;
        $new_date{month}++;
        if ($new_date{month} > 12) {
            $new_date{month} = 1;
            $new_date{year}++;
        }
    }
    return %new_date;
}

# Check if date1 is before date2
sub date_before {
    my ($date1, $date2) = @_;
    return 1 if $date1->{year} < $date2->{year};
    return 0 if $date1->{year} > $date2->{year};
    return 1 if $date1->{month} < $date2->{month};
    return 0 if $date1->{month} > $date2->{month};
    return $date1->{day} < $date2->{day};
}

# Update hot deals based on current prices
sub update_hot_deals {
    # Clear all deals
    @{$hot_deals{high}} = ();
    @{$hot_deals{low}} = ();

    # Only track opium prices across all seven cities
    my $good = 'opium';

    # Collect all opium prices with port info
    my @opium_prices;
    foreach my $port (@ports) {
        push @opium_prices, {
            port => $port,
            price => $port_prices{$port}{$good}
        };
    }

    # Sort by price
    @opium_prices = sort { $b->{price} <=> $a->{price} } @opium_prices;

    # Get highest prices (top half)
    my $half = int(@opium_prices / 2);
    for (my $i = 0; $i < $half; $i++) {
        push @{$hot_deals{high}}, {
            port => $opium_prices[$i]->{port},
            good => $good,
            price => $opium_prices[$i]->{price},
        };
    }

    # Get lowest prices (bottom half)
    for (my $i = $half; $i < @opium_prices; $i++) {
        push @{$hot_deals{low}}, {
            port => $opium_prices[$i]->{port},
            good => $good,
            price => $opium_prices[$i]->{price},
        };
    }

    # Hot deals will be displayed via update_status()
}

# Format hot deals for display
sub get_hot_deals_text {
    my $text = "OPIUM PRICES:\n";

    if (@{$hot_deals{high}} == 0 && @{$hot_deals{low}} == 0) {
        $text .= "None\n";
        return $text;
    }

    # Show high prices (good for selling)
    if (@{$hot_deals{high}} > 0) {
        $text .= "High:\n";
        my @high_deals = sort { $b->{price} <=> $a->{price} } @{$hot_deals{high}};
        foreach my $deal (@high_deals) {
            # Full port name, 5-char fixed width for price with ¥ symbol
            $text .= sprintf("%-9s %4d¥\n", $deal->{port}, $deal->{price});
        }
    }

    # Show low prices (good for buying)
    if (@{$hot_deals{low}} > 0) {
        $text .= "Low:\n";
        my @low_deals = sort { $a->{price} <=> $b->{price} } @{$hot_deals{low}};
        foreach my $deal (@low_deals) {
            # Full port name, 5-char fixed width for price with ¥ symbol
            $text .= sprintf("%-9s %4d¥\n", $deal->{port}, $deal->{price});
        }
    }

    return $text;
}

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

    # Save game data (player, warehouses, and port debts)
    eval {
        my $save_data = {
            player => \%player,
            warehouses => \%warehouses,
            port_debt => \%port_debt,
        };
        open my $fh, '>', $filename or die "Cannot open $filename: $!";
        print $fh encode_json($save_data);
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

        # Check if this is old format (just player hash) or new format (player + warehouses + port_debt)
        if (exists $loaded_data->{player}) {
            # New format: restore all game state
            %player = %{$loaded_data->{player}};
            %warehouses = %{$loaded_data->{warehouses}} if exists $loaded_data->{warehouses};
            %port_debt = %{$loaded_data->{port_debt}} if exists $loaded_data->{port_debt};
            debug_log("Loaded new format save: player, warehouses, port_debt restored");
        } else {
            # Old format: just player data (backward compatibility)
            %player = %$loaded_data;
            debug_log("Loaded old format save: only player data restored");
            # warehouses and port_debt will keep their default values
        }

        # Regenerate prices after loading (prices are not saved, only player data)
        initialize_trends();
        generate_initial_prices();

        # Update all UI elements to reflect loaded game state
        update_status();  # Updates status, hold, and prices
        draw_map();       # Updates the ASCII map with current port position

        $cui->dialog("VOC ledger loaded from $filename!");
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

        # Apply monthly debt interest (Original Taipan: 10% per month!)
        # Line 1010 of original BASIC: DW = INT(DW + DW * .1)
        # USURY PENALTY: 20% if debt > 10x bank balance (Elder Brother Wu gets mean!)
        if ($player{debt} > 0) {
            my $old_debt = $player{debt};
            my $interest_rate = 0.10;  # Normal rate: 10% per month

            # Check if player is in deep trouble (debt > 10x bank balance)
            if ($player{debt} > ($player{bank_balance} * 10)) {
                $interest_rate = 0.20;  # USURY! 20% per month
                debug_log("USURY RATES APPLIED: debt=$player{debt} > 10x bank_balance=" . ($player{bank_balance} * 10));
            }

            $player{debt} = int($player{debt} + $player{debt} * $interest_rate);
            my $interest = $player{debt} - $old_debt;
            my $rate_percent = int($interest_rate * 100);
            debug_log("Monthly debt interest ($rate_percent%): debt increased from $old_debt to $player{debt} (+$interest)");
        }

        if ($player{date}{month} > 12) {
            $player{date}{month} = 1;
            $player{date}{year}++;
        }
    }

    # Update hot deals when time advances
    update_hot_deals();
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
# c code from taipan.c
# had a random number between 0 and bp. Starting status of bp
# was either 10 or 7 depending if Taipan chose Debt or Guns respectively.
# Let's compromise and use 8 as starting bp.
# Combat state variables are now declared at the top of the file (lines 92-105)


sub fight_run_throw {
    # get the passed parameter and set our orders variable
    my $orders = shift || '';
    debug_log("=== fight_run_throw START: orders=$orders, num_ships=$num_ships, player ships=$player{ships}, guns=$player{guns} ===");
    if ($orders == 1) {  # Fight
        if ($player{guns} > 0) {
            my $sk = 0;  # Sunk ships

            # Calculate total firepower: ships * guns per ship
            my $total_firepower = $player{ships} * $player{guns};
            debug_log("Fight: total_firepower=$total_firepower, num_on_screen=$num_on_screen");

            $cui->dialog("Aye, we'll fight 'em, Taipan!");
            sleep(1);
            $cui->dialog("All $player{ships} ships firing with $player{guns} guns each! Total firepower: $total_firepower!");
            draw_blast(10, 6);
            sleep(1);

            # Fire in volleys for more exciting combat!
            # Calculate volley size (fire multiple guns at once)
            my $volley_size = $player{guns} > 5 ? int($player{guns} / 2) : $player{guns};
            $volley_size = 10 if $volley_size > 10;  # Cap at 10 simultaneous shots
            debug_log("Volley size: $volley_size");

            my $shots_fired = 0;
            debug_log("Starting volley loop: shots_fired=0, total_firepower=$total_firepower");
            while ($shots_fired < $total_firepower && $num_ships > 0) {
                debug_log("Volley iteration: shots_fired=$shots_fired, num_ships=$num_ships, num_on_screen=$num_on_screen");
                # Replenish on-screen ships if needed
                if ($num_ships > $num_on_screen) {
                    for (my $j = 0; $j <= 9 && $num_ships > $num_on_screen; $j++) {
                        if ($ships_on_screen[$j] <= 0) {  # Empty slot (0, -999, or any negative)
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
                    while ($ships_on_screen[$targeted] <= 0 && $attempts < 20) {  # Changed == to <=
                        $targeted = int(rand(10));
                        $attempts++;
                    }
                    next if $ships_on_screen[$targeted] <= 0;  # Skip if no valid target (changed == to <=)

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
                # Track which slots we've already processed to avoid double-counting within this volley
                my @sinking_ships = ();
                my %slots_processed = ();
                foreach my $target (@targets_hit) {
                    my $slot = $target->{slot};
                    # Skip if we already processed this slot in this volley
                    next if $slots_processed{$slot};
                    $slots_processed{$slot} = 1;

                    # Ship sinks if health <= 0 (includes exactly 0!)
                    # The slots_processed hash prevents double-counting
                    if ($ships_on_screen[$slot] <= 0) {
                        debug_log("Sinking ship in slot $slot with health=$ships_on_screen[$slot]");
                        push @sinking_ships, $target;
                        $num_on_screen--;
                        $num_ships--;
                        $sk++;
                        $ships_on_screen[$slot] = -999;  # Mark as definitively sunk (won't be targeted)
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
            debug_log("Volley loop complete: shots_fired=$shots_fired, num_ships=$num_ships, sk=$sk");

            # Enemy ships return fire! Apply damage to player ONCE per combat round
            # (AFTER all our volleys complete, not inside the volley loop!)
            # Original formula: DM = DM + FN R(ED * I * F1) + I / 2
            # Where: ED = damage severity, I = num_ships, F1 = damage multiplier
            if ($num_ships > 0) {
                # Scale ED down (original used 0.5, we use 10/20, so divide by 20)
                my $ed_scaled = $ed / 20.0;
                my $damage_taken = int(rand($ed_scaled * $num_ships * $f1)) + int($num_ships / 2);
                $player{damage} += $damage_taken;
                debug_log("Enemy damage: took $damage_taken damage, total damage now=$player{damage}");

                # Check seaworthiness after taking damage
                my $seaworthy = calculate_seaworthiness();
                debug_log("Seaworthiness after damage: ${seaworthy}%");

                # Always show damage message if we took any damage
                if ($seaworthy <= 0) {
                    $cui->dialog("We're taking on water, Taipan! The ship is sinking!");
                    sleep(2);
                    $cui->dialog("Your fleet has been lost at sea...");
                    sleep(2);
                    exit(0);  # Game over!
                } elsif ($seaworthy < 30) {
                    $cui->dialog("Took $damage_taken damage! Hull integrity: ${seaworthy}% - We need repairs soon!");
                } elsif ($seaworthy < 50) {
                    $cui->dialog("Took $damage_taken damage! Hull integrity: ${seaworthy}%");
                } elsif ($damage_taken > 0) {
                    $cui->dialog("Took $damage_taken damage from enemy fire! (Seaworthy: ${seaworthy}%)");
                }
            } else {
                debug_log("No enemy damage: num_ships=0, all enemies destroyed");
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
            debug_log("Fight round complete: num_ships=$num_ships, sk=$sk");

}  # Add this missing closing bracket
    }
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

            # ENEMY ATTACK PHASE when Run fails!
            # Original formula: DM = DM + FN R(ED * I * F1) + I / 2
            # Where: ED = damage severity, I = num_ships, F1 = damage multiplier
            my $ed_scaled = $ed / 20.0;
            my $damage_taken = int(rand($ed_scaled * $num_ships * $f1)) + int($num_ships / 2);
            $player{damage} += $damage_taken;
            debug_log("Run failed - Enemy attack: took $damage_taken damage, total damage now=$player{damage}");

            # Check seaworthiness after taking damage
            my $seaworthy = calculate_seaworthiness();
            debug_log("Seaworthiness after run damage: ${seaworthy}%");

            # Show damage message
            if ($seaworthy <= 0) {
                $cui->dialog("They're firing on us! We're taking on water, Taipan! The ship is sinking!");
                sleep(2);
                $cui->dialog("Your fleet has been lost at sea...");
                sleep(2);
                exit(0);  # Game over!
            } elsif ($seaworthy < 30) {
                $cui->dialog("They hit us hard! Took $damage_taken damage! Hull integrity: ${seaworthy}% - Critical!");
            } elsif ($seaworthy < 50) {
                $cui->dialog("They got some shots off! Took $damage_taken damage! Hull integrity: ${seaworthy}%");
            } elsif ($damage_taken > 0) {
                $cui->dialog("Enemy fire hit us as we ran! Took $damage_taken damage (Seaworthy: ${seaworthy}%)");
            }
            sleep(1);

            if ($num_ships > 2 && rand() * 5 < 1) {
                my $lost = int(rand($num_ships / 2) + 1);
                $num_ships -= $lost;
                fight_stats($num_ships, $orders);
                $cui->dialog("But we escaped from $lost of 'em!");
                if ($num_ships <= 10) {
                    for (my $i = 9; $i >= 0 && $num_on_screen > $num_ships; $i--) {
                        if ($ships_on_screen[$i] > 0) {
                            $ships_on_screen[$i] = 0;
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
                            $ships_on_screen[$i] = 0;
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
    -width => 19,
    -height => 19,
    -multi => 1,
    -text => '',
    -fg => 'white',
    -bg => 'black',
);

# Add opium prices label on the right side
our $opium_prices_label = $bottom_right->add(
    'opium_prices_label',
    'Label',
    -x => 20,
    -y => 0,
    -width => 19,
    -height => 19,
    -multi => 1,
    -text => '',
    -fg => 'yellow',
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
debug_log("Splash screen focused");

# Bind any unhandled key on splash to clear it and start game
$splash_label->set_binding( sub {
    debug_log("Splash key pressed - calling clear_splash_screen");
    clear_splash_screen();
}, '' );  # Empty string for default binding (handles unhandled keys)

debug_log("Splash binding set, starting mainloop");

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
    $opium_price_label->text("Opium: ¥" . ($port_prices{$player{port}}{opium} // 0));
    $arms_price_label->text("Arms: ¥" . ($port_prices{$player{port}}{arms} // 0));
    $silk_price_label->text("Silk: ¥" . ($port_prices{$player{port}}{silk} // 0));
    $general_price_label->text("General: ¥" . ($port_prices{$player{port}}{general} // 0));
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
        -text => '',  # Start blank - will be set after splash screen choice
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
        if ($current_action eq 'game_choice') {
            my $choice = uc(substr($value, 0, 1));  # Get first letter, uppercase
            debug_log("User entered game choice: $choice");

            # Clear instructions and show map
            $top_left->delete('instructions_label') if $top_left->getobj('instructions_label');
            draw_map();
            $cui->draw(1);

            if ($choice eq 'L') {
                debug_log("User chose LOAD GAME");
                load_game();
                debug_log("Returned from load_game, starting main_loop");
                # After loading, start the game
                $prompt_label->text('');
                $text_entry->text('');
                $current_action = '';
                main_loop();  # Start playing the loaded game!
            } else {
                debug_log("User chose NEW GAME (choice=$choice)");
                # New game - ask for firm name using a question dialog
                debug_log("NEW GAME: Showing firm name dialog");
                my $firm_name = $cui->question("Taipan, What will you name your Firm?");
                debug_log("NEW GAME: User entered firm name: $firm_name");

                if (defined $firm_name && $firm_name ne '') {
                    $player{firm_name} = $firm_name;
                    debug_log("NEW GAME: Calling update_status");
                    update_status();
                    debug_log("NEW GAME: Calling main_loop");
                    main_loop();  # Start the game!
                    debug_log("NEW GAME: Returned from main_loop");
                } else {
                    debug_log("NEW GAME: No firm name entered, exiting");
                    $cui->error("No firm name entered. Exiting.");
                }
            }
        } elsif ($current_action eq 'name_firm') {
            debug_log("name_firm: User entered firm name: $value");
            $player{firm_name} = $value;
            debug_log("name_firm: Calling update_status");
            update_status();
            debug_log("name_firm: Calling main_loop");
            main_loop();  # Proceed to main game loop after naming firm
            debug_log("name_firm: Returned from main_loop");
        } elsif ($current_action eq 'buy_select_good') {
            my $letter = lc substr($value, 0, 1);
            if (exists $good_map{$letter}) {
                my $good = $good_map{$letter};

                # Calculate maximum that can be bought
                my $price = $port_prices{$player{port}}{$good};
                my $free_space = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});
                my $max_by_cash = int($player{cash} / $price);
                my $max_can_buy = ($max_by_cash < $free_space) ? $max_by_cash : $free_space;

                # Show maximum in prompt with Enter-for-max pattern
                $prompt_label->text("How many $good to buy? [Enter for max: $max_can_buy] @ ¥$price ea ");
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

                # Calculate maximum that can be sold (all cargo of this type)
                my $max_can_sell = $player{cargo}{$good};
                my $price = $port_prices{$player{port}}{$good};
                my $total_value = $max_can_sell * $price;

                # Show maximum in prompt with Enter-for-max pattern
                $prompt_label->text("How many $good to sell? [Enter for max: $max_can_sell] @ ¥$price ea = ¥$total_value ");
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
        } elsif ($current_action eq 'store_select_good') {
            my $letter = lc substr($value, 0, 1);
            if (exists $good_map{$letter}) {
                my $good = $good_map{$letter};

                # Calculate maximum that can be stored
                my $current_port = $player{port};
                my $wh = $warehouses{$current_port};
                my $wh_used = $wh->{opium} + $wh->{arms} + $wh->{silk} + $wh->{general};
                my $wh_remaining = $wh->{capacity} - $wh_used;
                my $in_hold = $player{cargo}{$good};
                my $max_can_store = ($in_hold < $wh_remaining) ? $in_hold : $wh_remaining;

                # Show maximum in prompt and pre-fill text entry
                $prompt_label->text("How many $good to store? (max: $max_can_store, warehouse space: $wh_remaining) ");
                $text_entry->text($max_can_store);
                $text_entry->focus();
                $current_action = "store_$good";
            } else {
                $cui->error("Invalid good.");
                $prompt_label->text('Store which good? (o/a/s/g) ');
                $text_entry->text('');
                $text_entry->focus();
            }
            return;
        } elsif ($current_action eq 'retrieve_select_good') {
            my $letter = lc substr($value, 0, 1);
            if (exists $good_map{$letter}) {
                my $good = $good_map{$letter};

                # Calculate maximum that can be retrieved
                my $current_port = $player{port};
                my $wh = $warehouses{$current_port};
                my $in_warehouse = $wh->{$good};
                my $free_space = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});
                my $max_can_retrieve = ($in_warehouse < $free_space) ? $in_warehouse : $free_space;

                # Show maximum in prompt and pre-fill text entry
                $prompt_label->text("How many $good to retrieve? (max: $max_can_retrieve, hold space: $free_space) ");
                $text_entry->text($max_can_retrieve);
                $text_entry->focus();
                $current_action = "retrieve_$good";
            } else {
                $cui->error("Invalid good.");
                $prompt_label->text('Retrieve which good? (o/a/s/g) ');
                $text_entry->text('');
                $text_entry->focus();
            }
            return;
        } elsif ($current_action eq 'buy_ships') {
            # If empty, calculate and use maximum
            if (!defined $value || $value eq '') {
                my $ship_cost = 10000;
                if ($player{guns} > 20) {
                    my $guns_over_20 = $player{guns} - 20;
                    my $additional_cost = int($guns_over_20 / 2) * 1000;
                    $ship_cost += $additional_cost;
                }
                $value = int($player{cash} / $ship_cost);
            }
            if ($value =~ /^\d+$/ && $value > 0) {
                buy_ships($value);
            } else {
                $cui->error("Invalid number.");
            }
        } elsif ($current_action eq 'buy_guns') {
            # If empty, calculate and use maximum
            if (!defined $value || $value eq '') {
                my $cost_per_gun_round = 500 * $player{ships};
                $value = int($player{cash} / $cost_per_gun_round);
            }
            if ($value =~ /^\d+$/ && $value > 0) {
                buy_guns($value);
            } else {
                $cui->error("Invalid number.");
            }
        } elsif ($current_action =~ /^buy_(\w+)$/) {
            my $good = $1;
            # If empty, calculate and use maximum
            if (!defined $value || $value eq '') {
                my $price = $port_prices{$player{port}}{$good};
                my $free_space = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});
                my $max_by_cash = int($player{cash} / $price);
                $value = ($max_by_cash < $free_space) ? $max_by_cash : $free_space;
            }
            if ($value =~ /^\d+$/ && $value > 0) {
                buy_good($good, $value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action =~ /^sell_(\w+)$/) {
            my $good = $1;
            # If empty, use maximum (all cargo of this type)
            if (!defined $value || $value eq '') {
                $value = $player{cargo}{$good};
            }
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
            # If empty, calculate and use maximum
            if (!defined $value || $value eq '') {
                # Recalculate maximum payment
                my $available_funds;
                if ($player{port} eq 'Hong Kong') {
                    $available_funds = $player{cash} + $player{bank_balance};
                } else {
                    $available_funds = $player{cash};
                }
                $value = ($player{debt} < $available_funds) ? $player{debt} : $available_funds;
            }
            if ($value =~ /^\d+$/ && $value > 0) {
                pay_debt($value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action =~ /^store_(\w+)$/) {
            my $good = $1;
            if ($value =~ /^\d+$/ && $value > 0) {
                store_good($good, $value);
            } else {
                $cui->error("Invalid amount.");
            }
        } elsif ($current_action =~ /^retrieve_(\w+)$/) {
            my $good = $1;
            if ($value =~ /^\d+$/ && $value > 0) {
                retrieve_good($good, $value);
            } else {
                $cui->error("Invalid amount.");
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

sub update_status {
    my $month_name = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')[$player{date}{month} - 1];
    my $seaworthy = calculate_seaworthiness();

    # Calculate total net worth
    my $net_worth = $player{cash} + $player{bank_balance} - $player{debt};

    my $status_text = "Date: $player{date}{day} $month_name $player{date}{year}\nPort: $player{port}\nFirm: $player{firm_name}\nCash: ¥$player{cash}\nBank: ¥$player{bank_balance}\nDebt: ¥$player{debt}\nNet Worth: ¥$net_worth\nShips: $player{ships}\nGuns: $player{guns}\nCapacity: " . ($player{ships} * $player{hold_capacity}) . "\nSeaworthy: ${seaworthy}%\n";

    $status_label->text($status_text);
    update_hold();
    update_prices();  # Update price labels
    $cui->draw(1);

    # Check for automatic victory condition
    if ($net_worth >= 1000000) {
        $cui->dialog("*** FÙHÁO (Wealthy Magnate)! ***\n\nYou have achieved the ultimate goal!\nNet Worth: ¥$net_worth\n\nThe Emperor himself acknowledges your success!");
        retire();  # Automatically trigger retirement
    }
}

sub update_hold {
    # Add a remaining space in hold calculation
    # Sum all cargo and subtract from total capacity
    $player{cargo}{remaining} = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});

    # Get current port's warehouse
    my $wh = $warehouses{$player{port}};
    my $wh_used = $wh->{opium} + $wh->{arms} + $wh->{silk} + $wh->{general};
    my $wh_free = $wh->{capacity} - $wh_used;

    # Calculate ship cost (base ¥10,000 + ¥1,000 per 2 guns over 20)
    my $ship_cost = 10000;
    if ($player{guns} > 20) {
        my $guns_over_20 = $player{guns} - 20;
        my $additional_cost = int($guns_over_20 / 2) * 1000;
        $ship_cost += $additional_cost;
    }

    # Calculate gun cost (¥500 per gun × number of ships)
    my $gun_cost = 500 * $player{ships};

    # Format hold text for left column (narrower)
    my $hold_text = "CARGO:\n";
    $hold_text .= "Opium: $player{cargo}{opium}\n";
    $hold_text .= "Arms: $player{cargo}{arms}\n";
    $hold_text .= "Silk: $player{cargo}{silk}\n";
    $hold_text .= "General: $player{cargo}{general}\n";
    $hold_text .= "Free: $player{cargo}{remaining}\n";
    $hold_text .= "\nWAREHOUSE:\n";
    $hold_text .= "Opium: $wh->{opium}\n";
    $hold_text .= "Arms: $wh->{arms}\n";
    $hold_text .= "Silk: $wh->{silk}\n";
    $hold_text .= "General: $wh->{general}\n";
    $hold_text .= "Free: $wh_free\n";
    $hold_text .= "\nSHIPS: ¥$ship_cost ea\n";
    $hold_text .= "GUNS: ¥$gun_cost ea";

    $hold_label->text($hold_text);

    # Update opium prices in right column
    $opium_prices_label->text(get_hot_deals_text());
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
        $ships_on_screen[$i] = 0;
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
    debug_log("=== COMBAT_LOOP START: num_ships=$num_ships ===");

    # Show initial combat message
    $cui->dialog("Pirates attacking, Taipan! $num_ships " . ($num_ships == 1 ? "ship" : "ships") . " approaching!");

    # Combat continues while there are enemy ships
    while ($num_ships > 0) {
        debug_log("Combat loop iteration: num_ships=$num_ships, num_on_screen=$num_on_screen, current_action=$current_action");
        $prompt_label->text('Give orders to your crew (F)ight, (R)un, or (T)hrow cargo? ');
        $text_entry->text('');
        $current_action = 'combat'; # Set current action to combat for input handling
        $cui->draw(1); # Force full UI redraw to ensure prompt is visible
        $text_entry->focus(); # Ensure text entry is focused

        # Wait for user to give combat orders
        # This will process events until the user makes a choice
        debug_log("Waiting for user input...");
        while ($current_action eq 'combat' && $num_ships > 0) {
            $cui->do_one_event();
        }
        debug_log("User input received: current_action=$current_action, num_ships=$num_ships");

        # Check if combat ended (player escaped or destroyed all ships)
        if ($num_ships <= 0) {
            debug_log("Combat ended: num_ships=$num_ships");
            last;
        }

        # If player is still in combat but didn't escape, continue the loop
        debug_log("Continuing combat: $num_ships ships remaining");
    }

    # Combat is over, clean up
    #warn "combat_loop: Combat ended\n";
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

# Modified random_event subroutine
sub random_event {
    my ($destination_port_ref) = @_;  # Pass destination by reference to allow changing it
    #warn "Entering random_event\n";

    # STORM MECHANICS (Original APPLE II BASIC lines 3310-3340)
    # 1-in-10 chance of storm (FN R(10))
    if (int(rand(10)) == 0) {
        debug_log("STORM EVENT: Storm encountered during voyage!");
        $cui->dialog("Storm, Taipan!!\n\nDark clouds gather...\nThe seas are rising!");

        # 1-in-30 chance of going down (NOT FN R(30))
        if (int(rand(30)) == 0) {
            debug_log("STORM: Ship in danger of sinking!");
            $cui->dialog("I think we're going down!!");

            # Damage-based sinking chance: FN R(DM / SC * 3)
            # Higher damage = more likely to sink
            my $damage_factor = $player{damage} / $player{hold_capacity} * 3;
            debug_log("STORM: Damage factor = $damage_factor (damage=$player{damage}, capacity=$player{hold_capacity})");

            if (rand() < $damage_factor) {
                # SHIPS LOST IN STORM - some or all may sink
                # Calculate ships lost: 30-70% of fleet based on damage
                my $loss_percent = 0.3 + ($damage_factor * 0.2);  # 30-50% typically
                if ($loss_percent > 0.7) { $loss_percent = 0.7; }  # Cap at 70%
                my $ships_lost = int($player{ships} * $loss_percent);
                if ($ships_lost < 1) { $ships_lost = 1; }  # Lose at least 1 ship

                debug_log("STORM: Ships lost! $ships_lost of $player{ships} ships sinking (loss rate: " . int($loss_percent * 100) . "%)");

                if ($ships_lost >= $player{ships}) {
                    # ALL SHIPS LOST - GAME OVER
                    debug_log("STORM: ALL SHIPS SANK! Game over.");
                    $cui->dialog("We're going down, Taipan!!\n\nAll $player{ships} ships are lost to the waves...\nAll hands lost at sea.\n\nFinal net worth: ¥" . ($player{cash} + $player{bank_balance} - $player{debt}));
                    sleep(3);
                    $cui->dialog("Elder Brother Wu collects what's left of your estate.\n\n'The sea takes what the sea wants, Taipan.'\n\nGAME OVER");
                    sleep(2);
                    exit(0);
                } else {
                    # PARTIAL LOSS - lose some ships and cargo
                    my $cargo_lost_percent = $ships_lost / $player{ships};
                    my $cargo_lost = {
                        opium => int($player{cargo}{opium} * $cargo_lost_percent),
                        arms => int($player{cargo}{arms} * $cargo_lost_percent),
                        silk => int($player{cargo}{silk} * $cargo_lost_percent),
                        general => int($player{cargo}{general} * $cargo_lost_percent),
                    };

                    $player{ships} -= $ships_lost;
                    $player{cargo}{opium} -= $cargo_lost->{opium};
                    $player{cargo}{arms} -= $cargo_lost->{arms};
                    $player{cargo}{silk} -= $cargo_lost->{silk};
                    $player{cargo}{general} -= $cargo_lost->{general};

                    # Add damage from storm
                    $player{damage} += int($player{hold_capacity} * 0.5);  # Significant storm damage

                    my $total_cargo_lost = $cargo_lost->{opium} + $cargo_lost->{arms} + $cargo_lost->{silk} + $cargo_lost->{general};
                    debug_log("STORM: Lost $ships_lost ships and $total_cargo_lost units of cargo. Fleet reduced to $player{ships} ships.");

                    $cui->dialog("We're going down, Taipan!!\n\n$ships_lost of your ships are lost to the waves!\nCargo lost: $total_cargo_lost units\n\nYou have $player{ships} ships remaining.\nSevere storm damage sustained.");
                    sleep(2);
                }
            }
        }

        # Survived the storm!
        $cui->dialog("We made it!!\n\nThe storm passes...\nYour ships are battered but afloat.");

        # 1-in-3 chance of being blown off course (FN R(3))
        if (int(rand(3)) == 0) {
            # Pick random port that's NOT the destination
            my $original_dest = defined($destination_port_ref) ? $$destination_port_ref : $player{port};
            my $new_port;
            do {
                $new_port = $ports[int(rand(scalar @ports))];
            } while ($new_port eq $original_dest);

            debug_log("STORM: Blown off course from $original_dest to $new_port");
            $cui->dialog("We've been blown off course to $new_port!\n\n'The winds have decided our fate, Taipan!'");

            # Change the destination port
            if (defined $destination_port_ref) {
                $$destination_port_ref = $new_port;
            }
        }
    }

    # ENFORCER ATTACK: If debt > 10x bank balance, Elder Brother Wu sends Wu-Li  & Qui-Chang!
    # These goons ALWAYS attack (no random chance) and are tougher than regular pirates
    if ($player{debt} > 0 && $player{debt} > ($player{bank_balance} * 10)) {
        # Calculate enforcer strength: more debt = more enforcers
        my $debt_ratio = int($player{debt} / ($player{bank_balance} + 1));  # +1 to avoid division by zero
        my $enforcers = int($debt_ratio / 2) + 3;  # Minimum 3 enforcers, scales with debt
        if ($enforcers > 20) { $enforcers = 20; }  # Cap at 20

        $num_ships = $enforcers;
        debug_log("ENFORCER ATTACK! Debt=$player{debt}, Bank=$player{bank_balance}, Enforcers=$enforcers");
        $cui->dialog("Elder Brother Wu's enforcers attack!\n\n'Wu-Li and Qui Chang  are here to collect, Taipan!\nYou owe ¥$player{debt}!\nTime to pay up... in blood if necessary!'\n\n$enforcers armed junks surround your fleet!");
        init_combat();
        combat_loop();
        return;  # Enforcer attack handled, skip normal pirate logic
    }

    # PIRATE/LI YUEN ENCOUNTER (1 in 9 chance)
    # Original BASIC line 3110-3230
    my $rando = int(rand(9)); # Random number between 0 and 8
    #warn "random_event: rando=$rando\n";
    if ($rando != 0) { # 1 in 9 chance of pirate attack
        $current_action = 'sail_to'; # Set current action to sailing to avoid input issues
        #warn "random_event: No attack, returning with action=sail_to\n";
        return; # No attack
    }

    # Encounter! Check if it's Li Yuen or regular pirates
    # Line 3210: IF FN R(4 + 8 * LI) THEN 3300
    # LI=0 (no tribute): 1-in-4 (25%) chance of Li Yuen
    # LI=1 (paid tribute): 1-in-12 (8.3%) chance of Li Yuen
    my $li_yuen_chance = 4 + (8 * $player{li_yuen_tribute});
    my $is_li_yuen = (int(rand($li_yuen_chance)) == 0);

    if ($is_li_yuen) {
        # LI YUEN ENCOUNTER! (Lines 3220-3230)
        debug_log("LI YUEN ENCOUNTER! tribute=$player{li_yuen_tribute}");
        $cui->dialog("Li Yuen's pirates, Taipan!!\n\nThe legendary pirate lord's black sails appear on the horizon!");
        sleep(1);

        if ($player{li_yuen_tribute}) {
            # Paid tribute - they let you pass (Line 3220)
            debug_log("LI YUEN: Tribute paid, letting player pass");
            $cui->dialog("Good joss!!\n\nLi Yuen's fleet recognizes your tribute.\nThey let us be!\n\n'Pass, Taipan. You have earned our respect.'");
            sleep(2);
            return;  # Let them pass, no combat
        } else {
            # No tribute - ATTACK! (Line 3230)
            # SN = FN R(SC / 5 + GN) + 5
            $num_ships = int(rand(($player{hold_capacity} / 5) + $player{guns})) + 5;
            if ($num_ships > 9999) { $num_ships = 9999; }
            my $initial_pirates = $num_ships;

            debug_log("LI YUEN ATTACK! Fleet size: $num_ships ships, F1=2 (double damage)");

            $cui->dialog("$num_ships ships of Li Yuen's pirate fleet, Taipan!!\n\nThe most feared pirate armada in the South China Sea!\n\n'You have not paid tribute, Taipan. Now you will pay in blood!'");
            sleep(2);

            $num_on_screen = 0;
            @ships_on_screen = (0) x 10;  # Reset ship tracking array
            $orders = 0;  # Reset orders
            $ok = 3; # Reset escape chance factor
            $f1 = 2;  # Li Yuen does DOUBLE damage!

            # Initialize combat display
            init_combat();

            # Enter combat loop - this blocks until combat is resolved
            combat_loop();

            # Award booty if player won
            if ($num_ships == 0 && $initial_pirates > 0) {
                my $months = ($player{date}{year} - 1860) * 12 + ($player{date}{month} - 1);
                $months = 1 if $months < 1;

                # Li Yuen booty is 2x normal due to F1=2
                my $base_booty = int(rand($months / 4 * 1000 * ($initial_pirates ** 1.05))) * 2;
                my $bonus = int(rand(1000)) + 250;
                my $booty = $base_booty + $bonus;

                $player{cash} += $booty;
                debug_log("Victory over Li Yuen! Defeated $initial_pirates ships, earned ¥$booty (base=$base_booty, bonus=$bonus)");

                $cui->dialog("We've defeated Li Yuen's fleet, Taipan!!\n\nTheir treasure is legendary!\n\nBooty captured: ¥$booty\n\n'The gods smile upon you, Taipan!'");
                sleep(2);
                update_status();
            }

            $f1 = 1;  # Reset damage multiplier
            return;
        }
    }

    # NORMAL PIRATE ENCOUNTER (Line 3120)
    # SN = FN R(SC / 10 + GN) + 1
    my $pirates = int(rand(($player{hold_capacity} / 10) + $player{guns}) + 1);
    if ($pirates > 9999) {
        $pirates = 9999; # Cap at 9999 for display purposes
    }

    my $initial_pirates = $pirates;  # Remember how many we started with
    $num_ships = $pirates;
    $num_on_screen = 0;
    @ships_on_screen = (0) x 10;  # Reset ship tracking array
    $orders = 0;  # Reset orders
    $ok = 3; # Reset escape chance factor
    $f1 = 1;  # Normal pirates, normal damage

    # Announce pirate sighting BEFORE combat starts
    $cui->dialog("Taipan!! Pirates sighted off the port bow!\n\n$num_ships " . ($num_ships == 1 ? "ship" : "ships") . " approaching fast!");
    sleep(1);

    # Initialize combat display
    init_combat();

    # Enter combat loop - this blocks until combat is resolved
    combat_loop();

    # Award booty if player won (destroyed all enemy ships)
    # Original formula (Line 5080): BT = FN R(TI / 4 * 1000 * SN ^ 1.05) + FN R(1000) + 250
    # TI = time in months, SN = number of ships
    if ($num_ships == 0 && $initial_pirates > 0) {
        my $months = ($player{date}{year} - 1860) * 12 + ($player{date}{month} - 1);
        $months = 1 if $months < 1;  # Minimum 1 month

        # Calculate booty based on time and fleet size
        my $base_booty = int(rand($months / 4 * 1000 * ($initial_pirates ** 1.05)));
        my $bonus = int(rand(1000)) + 250;
        my $booty = $base_booty + $bonus;

        $player{cash} += $booty;
        debug_log("Victory booty: defeated $initial_pirates pirates, earned ¥$booty (base=$base_booty, bonus=$bonus, months=$months)");

        $cui->dialog("We've captured some booty, Taipan!\n\nIt's worth ¥$booty!\n\nDefeated $initial_pirates " . ($initial_pirates == 1 ? "pirate ship" : "pirate ships") . ".");
        sleep(1);
        update_status();
    }

    #warn "random_event: Combat completed, returning to sailing\n";
}

sub clear_splash_screen {
    debug_log("clear_splash_screen called");

    eval {
        debug_log("About to delete splash label");
        $top_left->delete('mysplashlabel');
        debug_log("Splash label deleted");

        # Clear the bottom prompt area
        $prompt_label->text('');
        $text_entry->text('');
        $current_action = '';

        # Show instructions in the Known World window
        my $instructions = <<'END_INSTRUCTIONS';

    ========================================================================
                            TAIPAN - HOW TO PLAY
    ========================================================================

    NAVIGATION:
      - Use TAB or arrow keys to move between menus
      - Press ENTER to confirm selections
      - Type numbers/text in the input field at bottom

    TRADING:
      - Enter amounts to buy/sell goods
      - Enter exact PORT NAME to sail (e.g., "Shanghai")

    SHIP MANAGEMENT:
      - Buy ships to increase cargo capacity (60 units each)
      - Buy guns for protection (500 yen per gun x all ships)
      - More guns (>20) increase ship purchase costs
      - Repair damage after battles

    GOAL:
      - Build your trading empire across 7 Asian ports
      - Achieve net worth of 1,000,000 yen to become a FUHÁO!

END_INSTRUCTIONS

        my $instructions_label = $top_left->add(
            'instructions_label', 'Label',
            -text => $instructions,
            -fg => 'white',
            -bg => 'black',
        );

        $cui->draw(1);  # Force UI refresh
        debug_log("Instructions displayed");

        # Ask if player wants new game or load game via text input
        $prompt_label->text('(N)ew Game or (L)oad Game? > ');
        $text_entry->text('');
        $text_entry->focus();
        $current_action = 'game_choice';
        debug_log("Waiting for game choice (N or L)");

        # This returns control to main_loop which will handle the 'game_choice' action
        # We need to set a flag so main_loop knows to come back here
        $player{choosing_game_mode} = 1;
    };

    if ($@) {
        debug_log("ERROR in clear_splash_screen: $@");
        # Fallback to old behavior if there's an error
        $top_left->delete('mysplashlabel') if $top_left->getobj('mysplashlabel');
        draw_map();
        $prompt_label->text("Taipan, What will you name your Firm? > ");
        $text_entry->text('');
        $current_action = 'name_firm';
        $cui->draw(1);
        $text_entry->focus();
    }
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
                # Calculate actual ship cost based on current guns
                my $ship_cost = 10000;
                if ($player{guns} > 20) {
                    my $guns_over_20 = $player{guns} - 20;
                    my $additional_cost = int($guns_over_20 / 2) * 1000;
                    $ship_cost += $additional_cost;
                }

                # Calculate maximum ships player can afford
                my $max_ships = int($player{cash} / $ship_cost);

                $prompt_label->text("Ships cost ¥$ship_cost each. How many? [Enter for max: $max_ships] ");
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'buy_ships';
            } elsif ($selected eq 'Buy Guns') {
                my $guns_cost_per_ship = 500;
                my $cost_per_gun_round = $guns_cost_per_ship * $player{ships};

                # Calculate maximum guns player can afford
                my $max_guns = int($player{cash} / $cost_per_gun_round);

                $prompt_label->text("Guns cost ¥$cost_per_gun_round per gun for all $player{ships} ships.\nHow many guns per ship? [Enter for max: $max_guns] ");
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
        -width => 12,
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
                $prompt_label->text('Store which good? (o/a/s/g) ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'store_select_good';
            } elsif ($selected eq 'Retrieve Goods') {
                $prompt_label->text('Retrieve which good? (o/a/s/g) ');
                $text_entry->text('');
                $text_entry->focus();
                $current_action = 'retrieve_select_good';
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
                # Calculate available funds based on location
                my $available_funds;
                my $location_note;

                if ($player{port} eq 'Hong Kong') {
                    $available_funds = $player{cash} + $player{bank_balance};
                    $location_note = " (cash + bank)";
                } else {
                    $available_funds = $player{cash};
                    $location_note = " (cash only)";
                }

                # Maximum payment is lesser of debt or available funds
                my $max_payment = ($player{debt} < $available_funds)
                    ? $player{debt}
                    : $available_funds;

                # Check if player has any debt
                if ($player{debt} <= 0) {
                    $cui->error("You have no debt, Taipan!");
                    $this->clear_selection();
                    $focus_menu = 'money_menu';
                    return;
                }

                # Check if player has any money to pay with
                if ($max_payment <= 0) {
                    $cui->error("You have no funds to pay debt with, Taipan!");
                    $this->clear_selection();
                    $focus_menu = 'money_menu';
                    return;
                }

                $prompt_label->text("Pay how much debt? [Enter for max: ¥$max_payment$location_note] Total debt: ¥$player{debt} ");
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
        -width => 7,
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
        $cui->error("Not enough cash. Need ¥$price but only have ¥$player{cash}.");
    } else {
        $player{cash} -= $price;
        $player{cargo}{$good} += $amount;
        $cui->dialog("Bought $amount $good for ¥$price, Taipan!");
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
        $cui->dialog("Sold $amount $good for ¥$price, Taipan!");
        update_status();
        update_hold();  # Update cargo hold display
    }
}

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
        $rank = "Master Taipan";
    } elsif ($score >= 1000) {
        $rank = "Taipan";
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
    $msg .= "Net Worth: ¥$net_worth\n";
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

sub calculate_seaworthiness {
    # Original formula: 100 - INT(DM / SC * 100)
    # Returns percentage of ship integrity (100 = perfect, 0 = sinking)
    my $sc = $player{hold_capacity};
    return 100 if $sc == 0;  # Avoid division by zero
    my $seaworthy = 100 - int($player{damage} / $sc * 100);
    return $seaworthy < 0 ? 0 : $seaworthy;
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
    $cui->dialog("The shipwright examines your fleet...\n\n'${damage_percent}% of your ships are damaged, Taipan.\nRepairs cost ¥$br per unit.\nYou have $player{damage} damage points.'");

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
        $cui->error("Not enough cash. You have ¥$player{cash}.");
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
    $cui->dialog("Repaired $repaired damage points for ¥$cash_spent!\n\nHull integrity now: ${new_seaworthy}%");

    update_status();
}

sub check_port_events {
    my $port = shift;

    # 0. DEBT WARNING (Elder Brother Wu's concern)
    # Warn when debt is high relative to net worth
    if ($player{debt} > 0) {
        my $net_worth = $player{cash} + $player{bank_balance} - $player{debt};

        # USURY RATES: Debt > 10x bank balance (20% monthly interest!)
        if ($player{debt} > ($player{bank_balance} * 10)) {
            $cui->dialog("Elder Brother Wu sends his enforcers:\n\n'Taipan! Your debt of ¥$player{debt} is TEN TIMES your bank balance!\n\nUSURY RATES now apply: 20% monthly interest!\n\nVinnie and Mario will be watching you closely...'");
        }
        # Critical: Debt exceeds total assets
        elsif ($player{debt} > ($player{cash} + $player{bank_balance})) {
            $cui->dialog("Elder Brother Wu sends word:\n\n'Taipan, your debt of ¥$player{debt} exceeds your assets!\nThe 10% monthly interest compounds relentlessly.\nPay down your debt before it consumes you!'");
        }
        # Warning: Debt is more than 50% of net worth
        elsif ($player{debt} > $net_worth * 0.5) {
            $cui->dialog("Elder Brother Wu sends word:\n\n'Taipan, your debt grows at 10% per month.\nCurrent debt: ¥$player{debt}\nConsider paying it down soon.'");
        }
    }

    # 1. BANK INTEREST (Hong Kong only)
    if ($port eq 'Hong Kong') {
        apply_bank_interest();
    }

    # 2. ROBBERY EVENTS (Original Taipan formulas)

    # CASH ROBBERY (Line 2501)
    # Trigger: CA > 25000 AND NOT(FN R(20))
    # Original: 5% chance (1 in 20) when cash > $25,000
    if ($player{cash} > 25000 && int(rand(20)) == 0) {
        # Amount stolen: I = FN R(CA/1.4) = random up to ~71% of cash
        my $stolen = int(rand($player{cash} / 1.4));
        $player{cash} -= $stolen;

        debug_log("CASH ROBBERY: ¥$stolen stolen in $port (had ¥" . ($player{cash} + $stolen) . ")");
        $cui->dialog("You've been beaten up and robbed of ¥$stolen in the streets of $port, Taipan!!\n\nBe more careful carrying so much cash!");
        sleep(1);
        update_status();
    }

    # BODYGUARD MASSACRE (Line 1460)
    # Trigger: DW > 20000 AND NOT(FN R(5))
    # Original: 20% chance (1 in 5) when debt > ¥20,000
    # Effect: Kill 1-3 bodyguards, steal ALL cash
    if ($player{debt} > 20000 && int(rand(5)) == 0) {
        my $bodyguards_killed = int(rand(3)) + 1;  # FN R(3) + 1 = 1-3
        my $cash_lost = $player{cash};

        $player{bodyguards} -= $bodyguards_killed;
        if ($player{bodyguards} < 0) { $player{bodyguards} = 0; }
        $player{cash} = 0;

        debug_log("BODYGUARD MASSACRE: $bodyguards_killed killed, ¥$cash_lost stolen, debt=¥$player{debt}");

        my $message = "Bad joss!!\n\n";
        $message .= "$bodyguards_killed of your bodyguards have been killed by cutthroats!\n\n";
        $message .= "You have been robbed of ALL your cash: ¥$cash_lost!\n\n";
        $message .= "Bodyguards remaining: $player{bodyguards}\n";
        $message .= "Elder Brother Wu's agents grow impatient...";

        $cui->dialog($message);
        sleep(2);
        update_status();

        # If out of bodyguards, Elder Brother Wu offers help (below)
    }

    # ELDER BROTHER WU ESCORT (Line 1220)
    # When debt is very high AND bodyguards are low, Wu sends protection
    if ($port eq 'Hong Kong' && $player{debt} > 30000 && $player{bodyguards} < 3 && !$player{wu_escort}) {
        my $braves = int(rand(100)) + 50;  # FN R(100) + 50 = 50-150 braves
        $player{wu_escort} = 1;
        $player{bodyguards} += 5;  # Wu provides new bodyguards

        debug_log("ELDER WU ESCORT: $braves braves sent, debt=¥$player{debt}, bodyguards restored to $player{bodyguards}");

        my $message = "Elder Brother Wu has sent $braves braves to escort you to the Wu mansion, Taipan.\n\n";
        $message .= "'We cannot have our clients harmed in the streets.\nBad for business.'\n\n";
        $message .= "He has assigned you 5 new bodyguards.\n";
        $message .= "'Consider it... an investment in your safety.'";

        $cui->dialog($message);
        sleep(2);
        update_status();
    }

    # ELDER BROTHER WU EMERGENCY LOAN OFFER (Line 1330)
    # When cash very low AND debt high, Wu offers predatory loans
    if ($port eq 'Hong Kong' && $player{cash} < 500 && $player{debt} > 10000) {
        # BL% = BL% + 1
        $player{bad_loan_count}++;

        # Loan amount: INT(FN R(1500) + 500) = 500-2000
        my $loan_amount = int(rand(1500)) + 500;

        # Payback: FN R(2000) * BL% + 1500
        my $payback_amount = int(rand(2000)) * $player{bad_loan_count} + 1500;

        my $interest_rate = int((($payback_amount - $loan_amount) / $loan_amount) * 100);

        debug_log("ELDER WU EMERGENCY LOAN: Offer loan #$player{bad_loan_count}: ¥$loan_amount for ¥$payback_amount payback ($interest_rate% interest)");

        my $message = "Elder Brother is aware of your plight, Taipan.\n\n";
        $message .= "He is willing to loan you an additional ¥$loan_amount\n";
        $message .= "if you will pay back ¥$payback_amount.\n\n";
        $message .= "($interest_rate% interest)\n\n";
        $message .= "Accept this emergency loan?";

        my $accept = $cui->dialog(
            -message => $message,
            -buttons => ['yes', 'no'],
        );

        if ($accept) {
            $player{cash} += $loan_amount;
            $player{debt} += $payback_amount;

            debug_log("ELDER WU EMERGENCY LOAN ACCEPTED: ¥$loan_amount borrowed, ¥$payback_amount added to debt");

            $cui->dialog("Elder Brother Wu smiles thinly.\n\n'Wise choice, Taipan. I knew you'd see reason.'\n\nCash increased by ¥$loan_amount\nDebt increased by ¥$payback_amount");
            sleep(1);
            update_status();
        } else {
            $cui->dialog("'As you wish, Taipan. But my offer stands... for now.'\n\nElder Brother Wu's expression hardens.");
            sleep(1);
        }
    }

    # 3. WAREHOUSE SPOILAGE/THEFT
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
        $cui->error("Not enough cash. You have ¥$player{cash}.");
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
    $cui->dialog("Deposited ¥$amount to your account at the Hong Kong & Shanghai Banking Corporation.\n\nNew balance: ¥$player{bank_balance}\nCurrent interest rate: ${new_rate}%");

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
        $cui->error("Insufficient funds. Your bank balance is ¥$player{bank_balance}.");
        return;
    }

    # Withdraw from bank
    $player{bank_balance} -= $amount;
    $player{cash} += $amount;

    my $remaining_rate = calculate_interest_rate() * 100;
    $cui->dialog("Withdrew ¥$amount from your account.\n\nRemaining balance: ¥$player{bank_balance}\nCurrent interest rate: ${remaining_rate}%");

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
            $cui->dialog("The Hong Kong & Shanghai Banking Corporation credits your account:\n\n$months months of interest at ${annual_rate}% annual rate\nInterest earned: ¥$interest_earned\n\nNew balance: ¥$player{bank_balance}");

            # Update last interest date
            $player{last_interest_date} = {
                year => $player{date}{year},
                month => $player{date}{month},
                day => $player{date}{day}
            };
        }
    }
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

    # Base cost per ship
    my $base_cost = 10000;

    # Increase cost if guns > 20: add $1000 for every 2 guns over 20
    if ($player{guns} > 20) {
        my $guns_over_20 = $player{guns} - 20;
        my $additional_cost = int($guns_over_20 / 2) * 1000;
        $base_cost += $additional_cost;
    }

    my $cost = $base_cost * $amount;

    # Check if player has enough cash
    if ($cost > $player{cash}) {
        $cui->error("Not enough cash. Need ¥$cost but only have ¥$player{cash}.");
        return;
    }

    # Purchase ships
    $player{cash} -= $cost;
    $player{ships} += $amount;

    # Show confirmation with proper singular/plural
    my $ship_word = $amount == 1 ? "ship" : "ships";
    $cui->dialog("Bought $amount $ship_word for ¥$cost, Taipan!");

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
        $cui->error("Not enough cash. Need ¥$cost to equip all $player{ships} ships but only have ¥$player{cash}.");
        return;
    }

    # Purchase guns
    $player{cash} -= $cost;
    $player{guns} += $amount;

    # Show confirmation with proper singular/plural
    my $gun_word = $amount == 1 ? "gun" : "guns";
    my $ship_word = $player{ships} == 1 ? "ship" : "ships";
    $cui->dialog("Bought $amount $gun_word per ship for all $player{ships} $ship_word ($total_guns_needed guns total) for ¥$cost, Taipan!");

    # Update status display
    update_status();
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
        random_event(\$new_port);  # Pass port by reference - storm may change destination
        #warn "sail_to: Returned from random_event, port is now $new_port\n";
        $player{port} = $new_port;
        $player{map} = (grep { $ports[$_] eq $new_port } 0..$#ports)[0] % @filenames;
        #warn "sail_to: Updated port to $player{port}, map index to $player{map}\n";
        generate_prices(); # Fluctuate prices and update labels
        update_hot_deals(); # Update hot deals after price changes
        #warn "sail_to: Prices generated\n";
        draw_map(); # Redraw map with new port indicator
        #warn "sail_to: Map drawn\n";
        $cui->dialog("Arrived in $new_port after $days days.");
        #warn "sail_to: Dialog displayed\n";

        # Elder Brother Wu's Zen wisdom upon arriving in Hong Kong
        if ($new_port eq 'Hong Kong' && $player{debt} > 0) {
            my @messages = (
                # Zen koans
                "Elder Brother Wu greets you at the dock:\n\n'Taipan, the river knows all tributaries,\nthough each flows from a different mountain.\nYour debts: ¥$player{debt}.'\n\nHe smiles knowingly.",
                "Elder Brother Wu emerges from the shadows:\n\n'The spider knows each thread in her web,\nthough she sits at the center in stillness.\nI know your debts, Taipan: ¥$player{debt}.'\n\nHe bows slightly.",
                "Elder Brother Wu sips tea on the pier:\n\n'A wise man once said: he who borrows from seven ports\nowes seven times, but the moon sees all.\nYour total burden: ¥$player{debt}, Taipan.'\n\nHe offers you tea.",
                "Elder Brother Wu counts on an abacus:\n\n'The mathematician needs no telegraph to sum numbers.\nMy brothers in distant ports write slowly,\nbut I have already added your debts: ¥$player{debt}.'\n\nClick. Click. Click.",
                "Elder Brother Wu stands at the dock:\n\n'They say my agents cannot communicate fast enough.\nTrue! But debt, like smoke, rises to heaven\nwhere all accounts are balanced.\nI see ¥$player{debt}, Taipan.'\n\nHe lights incense.",
                # Godfather-style messages
                "Elder Brother Wu waits at the dock with two large men:\n\n'Taipan, my dear friend... Vinnie and Mario here,\nthey help me remember things.\nRight now they remind me you owe ¥$player{debt}.\nDon't make them remind you personally.'\n\nVinnie cracks his knuckles.",
                "Elder Brother Wu leans against a crate:\n\n'You know, Taipan, I'm a reasonable man.\nI lend money to my friends in seven ports.\nAnd my friends, they always pay me back.\n¥$player{debt}, Taipan. In case you forgot.'\n\nHe lights a cigar.",
                "Two men in dark suits approach your ship.\nOne speaks:\n\n'Elder Brother Wu sends his regards, Taipan.\nHe wanted us to mention - very friendly-like -\nthat you borrowed ¥$player{debt} from the family.\nThe Don, he appreciates prompt payment.'\n\nThey smile coldly.",
                "Elder Brother Wu greets you warmly:\n\n'Taipan! Come, sit! You're family to me.\nThat's why I'm going to be straight with you:\n¥$player{debt}. That's what you owe.\nNow, we're going to settle this, yes?\nOne way... or another.'\n\nHe pours you wine."
            );

            # Choose a random message
            my $message = $messages[int(rand(scalar @messages))];
            $cui->dialog($message);
        }

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

sub borrow {
    my $amount = shift;

    # Validate input
    if (!defined $amount || $amount eq '' || $amount !~ /^\d+$/ || $amount <= 0) {
        $cui->error("Invalid amount. Please enter a positive number.");
        return;
    }

    # Elder Brother Wu's lending limit: 50,000 yen PER PORT
    # His agents in each port don't communicate fast enough to track total debt
    my $max_debt_per_port = 50000;
    my $current_port = $player{port};
    my $port_debt_amount = $port_debt{$current_port} || 0;
    my $available_credit = $max_debt_per_port - $port_debt_amount;

    if ($available_credit <= 0) {
        $cui->error("Elder Brother Wu's agent in $current_port says:\n'You already owe ¥$port_debt_amount here, Taipan.\nNo more credit from this office!'");
        return;
    }

    if ($amount > $available_credit) {
        $cui->error("Elder Brother Wu's agent in $current_port says:\n'I can only lend you ¥$available_credit more, Taipan.\nYou already owe ¥$port_debt_amount here.\nMy limit is ¥$max_debt_per_port per port.'");
        return;
    }

    # Track debt both globally (for interest) and per-port (for borrowing limits)
    $player{debt} += $amount;
    $port_debt{$current_port} += $amount;
    $player{cash} += $amount;

    debug_log("Borrowed ¥$amount in $current_port. Port debt: ¥$port_debt{$current_port}, Total debt: ¥$player{debt}");

    # Flavor text based on total debt situation
    my $total_debt = $player{debt};
    my $dialog_text;

    if ($total_debt > $max_debt_per_port * 2) {
        # Player owes a lot across multiple ports
        $dialog_text = "Elder Brother Wu's agent in $current_port lends you ¥$amount.\n\n'Taipan, I hear you owe ¥$total_debt across all our offices...\nBut business is business! This office can still lend you ¥$available_credit more.\n\nJust remember: 10% monthly interest compounds everywhere!'";
    } elsif ($total_debt > $max_debt_per_port) {
        # Player has debt in another port
        $dialog_text = "Elder Brother Wu's agent in $current_port lends you ¥$amount.\n\n'I see you have debts in other ports, Taipan.\nYour total across all offices is ¥$total_debt.\nBut here in $current_port, you still have credit!\n\n10% monthly interest, as always.'";
    } else {
        # First or only port with debt
        $dialog_text = "Elder Brother Wu's agent in $current_port lends you ¥$amount.\n\n'Don't forget the 10% monthly interest, Taipan!\nYour total debt is now ¥$total_debt.'";
    }

    $cui->dialog($dialog_text);
    update_status();
}

sub pay_debt {
    my $amount = shift;
    my $current_port = $player{port};

    # Check if overpaying
    if ($amount > $player{debt}) {
        $cui->error("Cannot overpay debt. You only owe ¥$player{debt}.");
        return;
    }

    # Smart payment: use bank funds if in Hong Kong and needed
    my $used_bank = 0;
    if ($amount > $player{cash}) {
        if ($player{port} eq 'Hong Kong') {
            my $need_from_bank = $amount - $player{cash};

            if ($need_from_bank > $player{bank_balance}) {
                my $total_available = $player{cash} + $player{bank_balance};
                $cui->error("Not enough funds. Need ¥$amount but only have ¥$total_available (¥$player{cash} cash + ¥$player{bank_balance} bank).");
                return;
            }

            # Auto-withdraw from bank
            $player{bank_balance} -= $need_from_bank;
            $player{cash} += $need_from_bank;
            $used_bank = 1;

            debug_log("Auto-withdrew ¥$need_from_bank from bank to pay debt");
        } else {
            $cui->error("Not enough cash. Need ¥$amount but only have ¥$player{cash}.\n(Banking only available in Hong Kong)");
            return;
        }
    }

    # Reduce global debt and cash
    $player{debt} -= $amount;
    $player{cash} -= $amount;

    # Pay down debt in current port first
    my $port_debt_amount = $port_debt{$current_port} || 0;
    my $remaining_payment = $amount;

    if ($port_debt_amount > 0) {
        # Pay current port's debt first
        my $port_payment = ($remaining_payment <= $port_debt_amount) ? $remaining_payment : $port_debt_amount;
        $port_debt{$current_port} -= $port_payment;
        $remaining_payment -= $port_payment;

        debug_log("Paid ¥$port_payment to current port $current_port. Port debt now ¥$port_debt{$current_port}");
    }

    # If payment exceeds current port's debt, distribute overflow to other ports
    if ($remaining_payment > 0) {
        debug_log("Payment overflow of ¥$remaining_payment needs distribution to other ports");

        # Find all ports with outstanding debt and distribute the overflow
        for my $port (@ports) {
            next if $port eq $current_port;  # Already handled
            next if ($port_debt{$port} || 0) <= 0;  # No debt here

            my $port_owed = $port_debt{$port};
            my $pay_to_port = ($remaining_payment <= $port_owed) ? $remaining_payment : $port_owed;
            $port_debt{$port} -= $pay_to_port;
            $remaining_payment -= $pay_to_port;

            debug_log("Distributed ¥$pay_to_port to $port. Port debt now ¥$port_debt{$port}");

            last if $remaining_payment <= 0;
        }
    }

    # If all debt is paid off, ensure all port_debt values are zero (safety check)
    if ($player{debt} == 0) {
        for my $port (@ports) {
            $port_debt{$port} = 0;
        }
        debug_log("All debt paid - zeroed out all port_debt values");
    }

    debug_log("Payment complete. Total debt now ¥$player{debt}");

    # Enhanced dialog showing if bank was used
    my $payment_source = $used_bank ? " (using cash + bank funds)" : "";
    my $debt_status = ($player{debt} == 0) ? "Your account is settled!" : "Total debt remaining: ¥$player{debt}";

    if ($port_debt_amount > 0) {
        $cui->dialog("Paid ¥$amount toward debt$payment_source.\n'Thank you, Taipan!' says Elder Brother Wu's agent in $current_port.\n\n$debt_status");
    } else {
        $cui->dialog("Paid ¥$amount toward debt$payment_source.\n\n'Your debt is not with this office, Taipan,\nbut I will send word to my brothers.'\n\n$debt_status");
    }

    update_status();
}

sub main_loop {
    debug_log("=== MAIN_LOOP START ===");
    #draw_radio_buttons();
    debug_log("main_loop: Drawing menus");
    draw_menu1();
    draw_menu2();
    draw_menu3();
    draw_menu4();
    draw_menu5();
    debug_log("main_loop: Menus drawn, updating status");
    update_status();
    # Bind cursor right/left to move between menus
    $bottom_top_left->set_binding( sub { move_menu(1); }, KEY_RIGHT );
    $bottom_top_left->set_binding( sub { move_menu(-1); }, KEY_LEFT );
    debug_log("main_loop: Drawing UI and setting focus");
    $cui->draw(1);
    $bottom_top_left->getobj($focus_menu)->focus();
    debug_log("=== MAIN_LOOP COMPLETE ===");
}
