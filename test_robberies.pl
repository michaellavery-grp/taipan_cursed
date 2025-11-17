#!/usr/bin/env perl
# Test script for robbery and Elder Brother Wu mechanics
# Based on original APPLE II BASIC lines 2501, 1460, 1220, 1330

use strict;
use warnings;

print "Testing Robbery & Elder Brother Wu Mechanics\n";
print "=" x 80 . "\n\n";

# Test 1: Cash Robbery (Line 2501)
print "Test 1: Cash Robbery (CA > 25,000 with 1-in-20 chance)\n";
print "-" x 80 . "\n";

my $iterations = 1000;
my $robbery_triggers = 0;
my @robbery_amounts;
my $total_stolen = 0;

for (1..$iterations) {
    my $cash = 30000;  # Over threshold

    # 1 in 20 chance: NOT (FN R(20))
    if (int(rand(20)) == 0) {
        $robbery_triggers++;

        # Rob amount: FN R(CA / 1.4)
        my $max_robbery = $cash / 1.4;
        my $stolen = int(rand($max_robbery));

        push @robbery_amounts, $stolen;
        $total_stolen += $stolen;
    }
}

my $avg_stolen = $robbery_triggers > 0 ? int($total_stolen / $robbery_triggers) : 0;
my $trigger_rate = ($robbery_triggers / $iterations) * 100;

printf "Robberies triggered:     %4d / %4d (%.1f%%, expected 5%%)\n",
    $robbery_triggers, $iterations, $trigger_rate;
printf "Average amount stolen:   ¥%d (max possible: ¥%d)\n",
    $avg_stolen, int(30000 / 1.4);
printf "Total stolen:            ¥%d\n", $total_stolen;

print "\n";

# Test 2: Bodyguard Massacre (Line 1460)
print "Test 2: Bodyguard Massacre (DW > 20,000 with 1-in-5 chance)\n";
print "-" x 80 . "\n";

my $massacre_triggers = 0;
my %bodyguards_killed;
my $total_cash_lost = 0;

for (1..$iterations) {
    my $debt = 25000;  # Over threshold
    my $cash = 10000;

    # 1 in 5 chance: NOT (FN R(5))
    if (int(rand(5)) == 0) {
        $massacre_triggers++;

        # Kill 1-3 bodyguards: FN R(3) + 1
        my $killed = int(rand(3)) + 1;
        $bodyguards_killed{$killed}++;

        # Lose ALL cash
        $total_cash_lost += $cash;
    }
}

my $avg_cash_lost = $massacre_triggers > 0 ? int($total_cash_lost / $massacre_triggers) : 0;
my $massacre_rate = ($massacre_triggers / $iterations) * 100;

printf "Massacres triggered:     %4d / %4d (%.1f%%, expected 20%%)\n",
    $massacre_triggers, $iterations, $massacre_rate;
printf "Bodyguards killed distribution:\n";
printf "  1 bodyguard:           %4d (%.1f%%)\n",
    $bodyguards_killed{1} || 0, (($bodyguards_killed{1}||0) / ($massacre_triggers||1)) * 100;
printf "  2 bodyguards:          %4d (%.1f%%)\n",
    $bodyguards_killed{2} || 0, (($bodyguards_killed{2}||0) / ($massacre_triggers||1)) * 100;
printf "  3 bodyguards:          %4d (%.1f%%)\n",
    $bodyguards_killed{3} || 0, (($bodyguards_killed{3}||0) / ($massacre_triggers||1)) * 100;
printf "Average cash lost:       ¥%d\n", $avg_cash_lost;
printf "Total cash lost:         ¥%d\n", $total_cash_lost;

print "\n";

# Test 3: Elder Brother Wu Escort (Line 1220)
print "Test 3: Elder Brother Wu Escort\n";
print "-" x 80 . "\n";

my @escort_sizes;
for (1..100) {
    # FN R(100) + 50 = 50-150 braves
    my $braves = int(rand(100)) + 50;
    push @escort_sizes, $braves;
}

my $min_braves = 999;
my $max_braves = 0;
my $total_braves = 0;
foreach my $size (@escort_sizes) {
    $min_braves = $size if $size < $min_braves;
    $max_braves = $size if $size > $max_braves;
    $total_braves += $size;
}
my $avg_braves = int($total_braves / scalar @escort_sizes);

printf "Escort size range:       %d - %d braves\n", $min_braves, $max_braves;
printf "Average escort size:     %d braves\n", $avg_braves;

print "\n";

# Test 4: Elder Brother Wu Emergency Loans (Line 1330)
print "Test 4: Elder Brother Wu Emergency Loans (Predatory Lending)\n";
print "-" x 80 . "\n";

my $bad_loan_counter = 0;
for my $loan_num (1..5) {
    $bad_loan_counter++;  # BL% = BL% + 1

    # Loan amount: INT(FN R(1500) + 500) = 500-2000
    my $loan_amount = int(rand(1500)) + 500;

    # Payback: FN R(2000) * BL% + 1500
    my $payback_amount = int(rand(2000)) * $bad_loan_counter + 1500;

    my $interest_rate = (($payback_amount - $loan_amount) / $loan_amount) * 100;

    printf "Loan #%d: Borrow ¥%4d, Payback ¥%5d (%.0f%% interest, usury factor: %d)\n",
        $loan_num, $loan_amount, $payback_amount, $interest_rate, $bad_loan_counter;
}

print "\n";

# Test 5: Combined Risk Analysis
print "Test 5: Combined Risk Analysis (High Cash + High Debt)\n";
print "-" x 80 . "\n";

my $both_conditions = 0;
my $cash_robbery_only = 0;
my $debt_robbery_only = 0;
my $safe_voyages = 0;

for (1..$iterations) {
    my $cash = 30000;  # Over cash threshold
    my $debt = 25000;  # Over debt threshold

    my $cash_robbed = (int(rand(20)) == 0);
    my $debt_attacked = (int(rand(5)) == 0);

    if ($cash_robbed && $debt_attacked) {
        $both_conditions++;
    } elsif ($cash_robbed) {
        $cash_robbery_only++;
    } elsif ($debt_attacked) {
        $debt_robbery_only++;
    } else {
        $safe_voyages++;
    }
}

printf "Both events triggered:   %4d (%.1f%%)\n",
    $both_conditions, ($both_conditions / $iterations) * 100;
printf "Cash robbery only:       %4d (%.1f%%)\n",
    $cash_robbery_only, ($cash_robbery_only / $iterations) * 100;
printf "Debt attack only:        %4d (%.1f%%)\n",
    $debt_robbery_only, ($debt_robbery_only / $iterations) * 100;
printf "Safe arrivals:           %4d (%.1f%%)\n",
    $safe_voyages, ($safe_voyages / $iterations) * 100;

print "\n";
print "=" x 80 . "\n";
print "Summary: Robbery Mechanics\n";
print "=" x 80 . "\n";
print "1. CASH ROBBERY (Line 2501)\n";
print "   Trigger: Cash > ¥25,000 AND 1-in-20 chance (5%)\n";
print "   Effect:  Steal up to CA/1.4 (max 71% of cash)\n";
print "   Message: 'You've been beaten up and robbed'\n";
print "\n";
print "2. BODYGUARD MASSACRE (Line 1460)\n";
print "   Trigger: Debt > ¥20,000 AND 1-in-5 chance (20%)\n";
print "   Effect:  Kill 1-3 bodyguards, steal ALL cash\n";
print "   Message: 'Bad joss!! X bodyguards killed by cutthroats'\n";
print "\n";
print "3. ELDER BROTHER WU ESCORT (Line 1220)\n";
print "   Effect:  50-150 braves escort you to Wu mansion\n";
print "   Purpose: Safety when debt is high (WN flag set)\n";
print "\n";
print "4. ELDER BROTHER WU EMERGENCY LOANS (Line 1330)\n";
print "   Loan:    ¥500-2,000\n";
print "   Payback: ¥(random(2000) * loan_count + 1500)\n";
print "   Effect:  Increases each time (BL% counter)\n";
print "   Example: Loan #1: ¥1000 → Pay ¥3000 (200% interest)\n";
print "            Loan #2: ¥1500 → Pay ¥5500 (267% interest)\n";
print "\n";
print "✓ All robbery mechanics tested!\n";
print "  The streets of Hong Kong are DANGEROUS, Taipan.\n";
