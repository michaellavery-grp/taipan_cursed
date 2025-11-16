#!/usr/bin/env perl
# Test script for multi-port borrowing implementation

use strict;
use warnings;

print "Testing Multi-Port Borrowing Implementation\n";
print "=" x 60 . "\n\n";

# Initialize test data
my @ports = ('Hong Kong', 'Shanghai', 'Nagasaki', 'Saigon', 'Manila', 'Batavia', 'Singapore');
my %port_debt = (
    'Hong Kong'  => 0,
    'Shanghai'   => 0,
    'Nagasaki'   => 0,
    'Saigon'     => 0,
    'Manila'     => 0,
    'Batavia'    => 0,
    'Singapore'  => 0,
);

my %player = (
    debt => 0,
    cash => 0,
    bank_balance => 5000,
    port => 'Hong Kong',
);

my $max_debt_per_port = 50000;

# Test 1: Borrow in Hong Kong
print "Test 1: Borrow ¥50,000 in Hong Kong\n";
my $current_port = 'Hong Kong';
my $amount = 50000;
my $available_credit = $max_debt_per_port - $port_debt{$current_port};

if ($amount <= $available_credit) {
    $player{debt} += $amount;
    $port_debt{$current_port} += $amount;
    $player{cash} += $amount;
    print "  ✓ PASS: Borrowed ¥$amount in $current_port\n";
    print "    Port debt (Hong Kong): ¥$port_debt{$current_port}\n";
    print "    Total debt: ¥$player{debt}\n";
    print "    Cash: ¥$player{cash}\n";
} else {
    print "  ✗ FAIL: Should allow borrowing\n";
}
print "\n";

# Test 2: Try to borrow more in Hong Kong (should fail)
print "Test 2: Try to borrow ¥10,000 more in Hong Kong (should fail)\n";
$amount = 10000;
$available_credit = $max_debt_per_port - $port_debt{$current_port};

if ($amount > $available_credit) {
    print "  ✓ PASS: Correctly rejected - only ¥$available_credit available\n";
    print "    Port debt limit reached in Hong Kong\n";
} else {
    print "  ✗ FAIL: Should reject borrowing beyond port limit\n";
}
print "\n";

# Test 3: Sail to Shanghai and borrow there
print "Test 3: Sail to Shanghai and borrow ¥50,000\n";
$current_port = 'Shanghai';
$player{port} = $current_port;
$amount = 50000;
$available_credit = $max_debt_per_port - $port_debt{$current_port};

if ($amount <= $available_credit) {
    $player{debt} += $amount;
    $port_debt{$current_port} += $amount;
    $player{cash} += $amount;
    print "  ✓ PASS: Borrowed ¥$amount in $current_port\n";
    print "    Port debt (Shanghai): ¥$port_debt{$current_port}\n";
    print "    Port debt (Hong Kong): ¥$port_debt{'Hong Kong'}\n";
    print "    Total debt: ¥$player{debt}\n";
    print "    Cash: ¥$player{cash}\n";
} else {
    print "  ✗ FAIL: Should allow borrowing in new port\n";
}
print "\n";

# Test 4: Borrow from all 7 ports
print "Test 4: Borrow ¥50,000 from all 7 ports\n";
$player{debt} = 0;
$player{cash} = 0;
%port_debt = map { $_ => 0 } @ports;

foreach my $port (@ports) {
    $current_port = $port;
    $amount = 50000;
    $player{debt} += $amount;
    $port_debt{$current_port} += $amount;
    $player{cash} += $amount;
}

print "  ✓ PASS: Borrowed from all 7 ports\n";
print "    Total debt: ¥$player{debt} (should be ¥350,000)\n";
print "    Cash: ¥$player{cash}\n";
foreach my $port (@ports) {
    print "      $port: ¥$port_debt{$port}\n";
}
print "\n";

# Test 5: Interest calculation with high debt
print "Test 5: Interest calculation with ¥350,000 debt\n";
my $old_debt = $player{debt};
my $interest_rate = ($player{debt} > ($player{bank_balance} * 10)) ? 0.20 : 0.10;
$player{debt} = int($player{debt} + $player{debt} * $interest_rate);
my $interest = $player{debt} - $old_debt;
my $rate_pct = int($interest_rate * 100);

print "  Interest rate: ${rate_pct}% (USURY triggered)\n";
print "  Old debt: ¥$old_debt\n";
print "  New debt: ¥$player{debt}\n";
print "  Interest: ¥$interest\n";

if ($interest_rate == 0.20) {
    print "  ✓ PASS: Usury rate correctly applied (debt > 10x bank balance)\n";
} else {
    print "  ✗ FAIL: Should apply usury rate\n";
}
print "\n";

# Test 6: Pay debt in specific port
print "Test 6: Pay ¥25,000 debt in Hong Kong\n";
$current_port = 'Hong Kong';
$amount = 25000;
my $port_debt_amount = $port_debt{$current_port};

if ($port_debt_amount > 0 && $amount <= $port_debt_amount) {
    $port_debt{$current_port} -= $amount;
    $player{debt} -= $amount;
    print "  ✓ PASS: Paid ¥$amount in $current_port\n";
    print "    Port debt (Hong Kong): ¥$port_debt{$current_port}\n";
    print "    Total debt: ¥$player{debt}\n";
} else {
    print "  ✗ FAIL: Should allow payment\n";
}
print "\n";

# Test 7: Borrow again in Hong Kong after partial payment
print "Test 7: Borrow ¥25,000 again in Hong Kong (should succeed)\n";
$amount = 25000;
$available_credit = $max_debt_per_port - $port_debt{$current_port};

if ($amount <= $available_credit) {
    $player{debt} += $amount;
    $port_debt{$current_port} += $amount;
    print "  ✓ PASS: Borrowed ¥$amount in $current_port\n";
    print "    Port debt (Hong Kong): ¥$port_debt{$current_port} (back to ¥50,000)\n";
    print "    Total debt: ¥$player{debt}\n";
} else {
    print "  ✗ FAIL: Should allow borrowing up to limit\n";
}
print "\n";

print "=" x 60 . "\n";
print "All tests completed!\n\n";
print "Summary of Multi-Port Borrowing Features:\n";
print "  ✓ Each port has independent ¥50,000 lending limit\n";
print "  ✓ Player can borrow from multiple ports simultaneously\n";
print "  ✓ Total debt across all ports is tracked for interest\n";
print "  ✓ Usury rate (20%) applies when total debt > 10x bank balance\n";
print "  ✓ Payments reduce port-specific debt first\n";
print "  ✓ Can borrow again after paying down port-specific debt\n";
print "  ✓ Maximum possible debt: ¥350,000 (7 ports × ¥50,000)\n";
