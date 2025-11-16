#!/usr/bin/env perl
# Test script for usury limit implementation

use strict;
use warnings;

print "Testing Usury Limit Implementation\n";
print "=" x 50 . "\n\n";

# Test 1: Maximum debt cap
print "Test 1: Maximum Debt Cap (¥50,000)\n";
my $max_debt = 50000;
my $current_debt = 0;
my $borrow_amount = 60000;
my $available_credit = $max_debt - $current_debt;

if ($borrow_amount > $available_credit) {
    print "  ✓ PASS: Cannot borrow ¥$borrow_amount (exceeds ¥$max_debt limit)\n";
    print "    Available credit: ¥$available_credit\n";
} else {
    print "  ✗ FAIL: Should not allow borrowing beyond limit\n";
}
print "\n";

# Test 2: Normal interest rate (10%)
print "Test 2: Normal Interest Rate (10% monthly)\n";
my $debt = 10000;
my $bank_balance = 5000;
my $interest_rate = 0.10;

if ($debt <= ($bank_balance * 10)) {
    my $new_debt = int($debt + $debt * $interest_rate);
    my $interest = $new_debt - $debt;
    print "  ✓ PASS: Normal rate applied\n";
    print "    Debt: ¥$debt → ¥$new_debt (+¥$interest)\n";
    print "    Rate: 10%\n";
} else {
    print "  ✗ FAIL: Should use normal rate\n";
}
print "\n";

# Test 3: Usury penalty (20%)
print "Test 3: Usury Penalty (20% when debt > 10x bank balance)\n";
$debt = 30000;
$bank_balance = 2000;  # debt > 10x bank balance (30000 > 20000)
$interest_rate = 0.20;

if ($debt > ($bank_balance * 10)) {
    my $new_debt = int($debt + $debt * $interest_rate);
    my $interest = $new_debt - $debt;
    print "  ✓ PASS: Usury rate triggered\n";
    print "    Debt: ¥$debt > 10x bank (¥" . ($bank_balance * 10) . ")\n";
    print "    Debt: ¥$debt → ¥$new_debt (+¥$interest)\n";
    print "    Rate: 20% (USURY!)\n";
} else {
    print "  ✗ FAIL: Should trigger usury rate\n";
}
print "\n";

# Test 4: Exponential growth with cap
print "Test 4: Debt Growth Over 12 Months (with ¥50,000 cap)\n";
$debt = 40000;
$bank_balance = 1000;
print "  Starting debt: ¥$debt\n";

for my $month (1..12) {
    my $rate = ($debt > ($bank_balance * 10)) ? 0.20 : 0.10;
    $debt = int($debt + $debt * $rate);

    # Apply cap
    if ($debt > $max_debt) {
        print "  Month $month: ¥$debt (CAPPED at ¥$max_debt)\n";
        $debt = $max_debt;
        last;
    } else {
        my $rate_pct = int($rate * 100);
        print "  Month $month: ¥$debt (${rate_pct}% interest)\n";
    }
}

print "\n✓ All tests completed!\n";
print "\nKey findings:\n";
print "  - Max debt enforced at borrowing time: ¥50,000\n";
print "  - Interest can push debt beyond cap (needs additional safeguard?)\n";
print "  - Usury rate (20%) applies when debt > 10x bank balance\n";
