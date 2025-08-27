#!/usr/bin/perl
# Taipan game remake in Perl with Curses::UI.
# License is GPLv3 or later.
# Original game by Art Canfil, programmed by Jay Link.
# Curses version by Michael Lavery, enhanced with full game logic.

use strict;
use warnings;
use Curses::UI;
use Curses qw(KEY_ENTER KEY_RIGHT KEY_LEFT);  # Import KEY_ENTER, KEY_RIGHT, KEY_LEFT constants
use List::Util qw(shuffle);

our $focus_menu = "ship_menu";
our @menus = qw(ship_menu trade_menu money_menu system_menu);
our %good_map = (o => 'opium', a => 'arms', s => 'silk', g => 'general');

# Menu object references for resetting
our ($ship_menu_obj, $trade_menu_obj, $money_menu_obj, $system_menu_obj);

# Set ESCDELAY to a low value to make the Escape key responsive (avoids 1-second delay)
$ENV{ESCDELAY} = 25;

# Ensure Curses::UI is installed: cpan Curses::UI
my $cui = new Curses::UI(
    -color_support => 1,
    -clear_on_exit => 1,
    -utf8 => 1,  # Enable UTF-8 support for the terminal
);

# Game data structures
my %player = (
    firm_name => '',
    cash => 0,
    debt => 0,  # Starting debt
    ships => 1,
    guns => 0,
    hold_capacity => 60,  # Per ship
    cargo => { opium => 0, arms => 0, silk => 0, general => 0 },
    remaining => 60,  # Remaining hold space
    warehouse => { opium => 0, arms => 0, silk => 0, general => 0 },
    port => 'Hong Kong',
    map => 0, # Index of current map (multiple maps are used)
    date => { year => 1860, month => 1, day => 15 },
);

my @ports = ('Hong Kong', 'Shanghai', 'Nagasaki', 'Saigon', 'Manila', 'Batavia', 'Singapore');

# Define the ascii map text
my @filenames = ('ascii_taipan_map1.txt', 'ascii_taipan_map2.txt', 'ascii_taipan_map3.txt', 'ascii_taipan_map4.txt', 'ascii_taipan_map5.txt', 'ascii_taipan_map6.txt', 'acsii_taipan_map7.txt');
# create blank array to hold map text string values
my @map_text = ();
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


my %goods = (
    opium => { base_price => 5000, volatility => 0.8 },
    arms => { base_price => 250, volatility => 0.5 },
    silk => { base_price => 300, volatility => 0.4 },
    general => { base_price => 50, volatility => 0.3 },
);

my %port_prices;  # Will be generated per port

# References to price labels for updating
my ($opium_price_label, $arms_price_label, $silk_price_label, $general_price_label);

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

# Random events (e.g., pirates)
sub random_event {
    if (rand() < 0.2) {  # 20% chance of pirate attack
        my $pirates = int(rand(5) + 1);
        $cui->dialog("Pirates attack! $pirates junk(s) approaching.");
        # Simple combat logic
        if ($player{guns} >= $pirates) {
            $cui->dialog("You fought off the pirates!");
        } else {
            my $loss = int(rand($player{hold_capacity} / 2));
            foreach my $good (keys %{$player{cargo}}) {
                $player{cargo}{$good} = int($player{cargo}{$good} / 2);
            }
            $cui->dialog("Pirates stole half your cargo!");
        }
    }
}

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
#$cui->set_binding( sub { $menu->focus() }, "\\cS" ); # Ctrl+S to focus menubar
#$cui->set_binding( sub { $menu->focus() }, "\e" );   # Escape key to focus menubar
#$cui->set_binding( \&exit_dialog, "\\cQ" ); # Ctrl+Q to Quit

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

my $status_label = $top_right->add(
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
my $bottom_top_left = $cui->add(
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

my $bottom_bottom_left = $cui->add(
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

my $hold_label = $bottom_right->add(
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
my $current_action = '';

my $prompt_label;

my $text_entry;

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

sub draw_radio_buttons {
    my $map_radio = $top_left->add(
        'map_radio',
        'Radiobuttonbox',
        -x => 50,
        -y => 0,
        -width => 25,
        -height => 6,
        -border => 0,
        -values => ['weather', 'pirates', 'cops', 'prices'],
        -labels => {
            'weather' => 'Weather',
            'pirates' => 'Pirates',
            'cops' => 'Cops (Military)',
            'prices' => 'Prices'
        },
        -selected => 3,
        -fg => 'white',
        -bg => 'black',
        -onchange => sub {
            my $this = shift;
            my $selected = $this->get();
            $cui->dialog("Map mode changed to: $selected");
        },
    );
}

sub update_prices {
    return unless defined $opium_price_label;  # Skip if labels not yet initialized
    $opium_price_label->text("Opium: $port_prices{$player{port}}{opium}");
    $arms_price_label->text("Arms: $port_prices{$player{port}}{arms}");
    $silk_price_label->text("Silk: $port_prices{$player{port}}{silk}");
    $general_price_label->text("General: $port_prices{$player{port}}{general}");
    $cui->draw(1);
}

sub input_prompt {
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
        } elsif ($current_action eq 'repair_ship') {
            repair_ship();
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
        }
        # Reset
        $prompt_label->text('> ');
        $text_entry->text('');
        $current_action = '';
        $bottom_top_left->getobj($focus_menu)->focus();
    }, KEY_ENTER);
    # Ensure focus is set to text entry
    $cui->draw(1);
    $text_entry->focus();
}

sub update_status {
    my $month_name = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')[$player{date}{month} - 1];
    my $status_text = "Date: $player{date}{day} $month_name $player{date}{year}\nPort: $player{port}\nFirm: $player{firm_name}\nCash: \$$player{cash}\nDebt: \$$player{debt}\nShips: $player{ships}\nGuns: $player{guns}\nCapacity: " . ($player{ships} * $player{hold_capacity}) . "\n";
    $status_label->text($status_text);
    update_hold();
    update_prices();  # Update price labels
    $cui->draw(1);
}

sub update_hold {
    # Add a remaining space in hold calculation
    # Sum all cargo and subtract from total capacity
    $player{cargo}{remaining} = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});
    my $hold_text = "Opium: $player{cargo}{opium}\nArms: $player{cargo}{arms}\nSilk: $player{cargo}{silk}\nGeneral: $player{cargo}{general}\n\nWarehouse:\nOpium: $player{warehouse}{opium}\nArms: $player{warehouse}{arms}\nSilk: $player{warehouse}{silk}\nGeneral: $player{warehouse}{general}";
    $hold_label->text($hold_text);
}

sub draw_map {
    my $map_label = $top_left->add( 
        'mymaplabel', 'Label',
        -text => "$map_text[$player{map}]\n"
    );
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
                $prompt_label->text('Guns cost 500 each, how many? ');
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
        -values => ['Buy Goods', 'Sell Goods', 'Store Goods'],
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
        -width => 5,
        -height => 5,
        -values => ['Save', 'Load', 'Quit'],
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
                $cui->error("Save not implemented");
            } elsif ($selected eq 'Load') {
                $cui->error("Load not implemented");
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
        -fg => 'white',
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
    my $price = $port_prices{$player{port}}{$good} * $amount;
    my $free_space = ($player{ships} * $player{hold_capacity}) - ($player{cargo}{opium} + $player{cargo}{arms} + $player{cargo}{silk} + $player{cargo}{general});
    if ($amount > $free_space) {
        $cui->error("Not enough hold space.");
    } elsif ($price > $player{cash}) {
        $cui->error("Not enough cash.");
    } else {
        $player{cash} -= $price;
        $player{cargo}{$good} += $amount;
        $cui->dialog("Bought $amount $good.");
        update_status();
    }
}

sub sell_good {
    my ($good, $amount) = @_;
    if ($amount > $player{cargo}{$good}) {
        $cui->error("Not enough $good to sell.");
    } else {
        my $price = $port_prices{$player{port}}{$good} * $amount;
        $player{cash} += $price;
        $player{cargo}{$good} -= $amount;
        $cui->dialog("Sold $amount $good for \$$price.");
        update_status();
    }
}

sub store_good {
    my ($good, $amount) = @_;
    if ($amount > $player{cargo}{$good}) {
        $cui->error("Not enough $good to store.");
    } else {
        $player{cargo}{$good} -= $amount;
        $player{warehouse}{$good} += $amount;
        $cui->dialog("Stored $amount $good in warehouse.");
        update_status();
    }
}

sub buy_ships {
    my $amount = shift;
    my $cost = 10000 * $amount;
    if ($cost > $player{cash}) {
        $cui->error("Not enough cash.");
    } else {
        $player{cash} -= $cost;
        $player{ships} += $amount;
        $cui->dialog("Bought $amount ships.");
        update_status();
    }
}

sub buy_guns {
    my $amount = shift;
    my $cost = 500 * $amount;
    if ($cost > $player{cash}) {
        $cui->error("Not enough cash.");
    } else {
        $player{cash} -= $cost;
        $player{guns} += $amount;
        $cui->dialog("Bought $amount guns.");
        update_status();
    }
}

sub repair_ship {
    # Assume full repair for simplicity
    $cui->dialog("Ship repaired (placeholder).");
}

sub sail_to {
    my $new_port = shift;
    if (grep { $_ eq $new_port } @ports) {
        if ($new_port eq $player{port}) {
            $cui->error("Already in $new_port.");
            return;
        }
        my $days = int(rand(10) + 5);  # Random travel time
        advance_date($days);
        random_event();
        $player{port} = $new_port;
        generate_prices();  # Fluctuate prices and update labels
        $cui->dialog("Arrived in $new_port after $days days.");
        # the port array index value is the map index for the draw_map function
        $player{map} = (grep { $ports[$_] eq $new_port } 0..$#ports)[0] % @filenames;
        $top_left->delete('mymaplabel');
        draw_map();
        update_status();
    } else {
        $cui->error("Invalid port.");
    }
}

sub deposit {
    my $amount = shift;
    # For simplicity, no bank, just placeholder
    $cui->error("Deposit not implemented.");
}

sub withdraw {
    my $amount = shift;
    # For simplicity, no bank, just placeholder
    $cui->error("Withdraw not implemented.");
}

sub borrow {
    my $amount = shift;
    $player{debt} += $amount;
    $player{cash} += $amount;
    $cui->dialog("Borrowed \$$amount.");
    update_status();
}

sub pay_debt {
    my $amount = shift;
    if ($amount > $player{cash}) {
        $cui->error("Not enough cash.");
    } elsif ($amount > $player{debt}) {
        $cui->error("Overpaying debt.");
    } else {
        $player{cash} -= $amount;
        $player{debt} -= $amount;
        $cui->dialog("Paid \$$amount toward debt.");
        update_status();
    }
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