#!/usr/bin/env perl
# Test script for calculating transaction maximums

use strict;
use warnings;

print "Testing Transaction Maximum Calculations\n";
print "=" x 60 . "\n\n";

# Test scenario setup
my %player = (
    cash => 25000,
    ships => 5,
    hold_capacity => 60,
    cargo => { opium => 50, arms => 100, silk => 0, general => 50 },
    remaining => 100,  # 5 ships * 60 capacity = 300 total, 200 used, 100 remaining
);

my %port_prices = (
    opium => 1000,
    arms => 50,
    silk => 500,
    general => 10,
);

my %warehouses = (
    'Hong Kong' => {
        opium => 500,
        arms => 1000,
        silk => 200,
        general => 3000,
        capacity => 10000,
    },
);

# Test 1: Maximum BUY calculation
print "Test 1: Calculate Maximum BUY for each good\n";
print "  Player cash: ¥$player{cash}\n";
print "  Hold space remaining: $player{remaining}\n\n";

foreach my $good (qw(opium arms silk general)) {
    my $price = $port_prices{$good};

    # Maximum based on cash
    my $max_by_cash = int($player{cash} / $price);

    # Maximum based on hold space
    my $max_by_space = $player{remaining};

    # Actual maximum is the lesser of the two
    my $max_can_buy = ($max_by_cash < $max_by_space) ? $max_by_cash : $max_by_space;

    print "  $good (¥$price each):\n";
    print "    Max by cash: $max_by_cash\n";
    print "    Max by space: $max_by_space\n";
    print "    → Maximum can buy: $max_can_buy\n";
    print "    Total cost: ¥" . ($max_can_buy * $price) . "\n\n";
}

# Test 2: Maximum SELL calculation
print "Test 2: Calculate Maximum SELL for each good\n";
print "  Current cargo:\n";
foreach my $good (keys %{$player{cargo}}) {
    print "    $good: $player{cargo}{$good}\n";
}
print "\n";

foreach my $good (qw(opium arms silk general)) {
    my $max_can_sell = $player{cargo}{$good};
    my $price = $port_prices{$good};

    print "  $good (¥$price each):\n";
    print "    → Maximum can sell: $max_can_sell\n";
    print "    Total value: ¥" . ($max_can_sell * $price) . "\n\n";
}

# Test 3: Maximum STORE calculation
print "Test 3: Calculate Maximum STORE for warehouse\n";
my $current_port = 'Hong Kong';
my $warehouse = $warehouses{$current_port};
my $warehouse_used = 0;
foreach my $good (keys %{$warehouse}) {
    next if $good eq 'capacity';
    $warehouse_used += $warehouse->{$good};
}
my $warehouse_space = $warehouse->{capacity} - $warehouse_used;

print "  Warehouse capacity: $warehouse->{capacity}\n";
print "  Warehouse used: $warehouse_used\n";
print "  Warehouse space remaining: $warehouse_space\n\n";

foreach my $good (qw(opium arms silk general)) {
    my $in_hold = $player{cargo}{$good};
    my $max_can_store = ($in_hold < $warehouse_space) ? $in_hold : $warehouse_space;

    print "  $good:\n";
    print "    In hold: $in_hold\n";
    print "    Warehouse space: $warehouse_space\n";
    print "    → Maximum can store: $max_can_store\n\n";
}

# Test 4: Maximum RETRIEVE calculation
print "Test 4: Calculate Maximum RETRIEVE from warehouse\n";
print "  Hold space remaining: $player{remaining}\n";
print "  Warehouse contents:\n";
foreach my $good (qw(opium arms silk general)) {
    print "    $good: $warehouse->{$good}\n";
}
print "\n";

foreach my $good (qw(opium arms silk general)) {
    my $in_warehouse = $warehouse->{$good};
    my $max_can_retrieve = ($in_warehouse < $player{remaining}) ? $in_warehouse : $player{remaining};

    print "  $good:\n";
    print "    In warehouse: $in_warehouse\n";
    print "    Hold space: $player{remaining}\n";
    print "    → Maximum can retrieve: $max_can_retrieve\n\n";
}

print "=" x 60 . "\n";
print "Summary: All transaction types need max calculation\n";
print "  BUY: min(cash/price, hold_space)\n";
print "  SELL: cargo[good]\n";
print "  STORE: min(cargo[good], warehouse_space)\n";
print "  RETRIEVE: min(warehouse[good], hold_space)\n";
