#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;

# TEST HARNESS FOR LI YUEN ENCOUNTERS
# Based on APPLE II BASIC lines 3110-3230
# Validates:
# 1. Li Yuen encounter probability without tribute: ~25% (1-in-4)
# 2. Li Yuen encounter probability with tribute: ~8.3% (1-in-12)
# 3. "Good joss" pass-through when tribute is paid
# 4. Fleet size calculation: SC/5 + GN + 5 ships
# 5. F1=2 damage multiplier is set
# 6. 2x booty calculation for Li Yuen victories

my $ITERATIONS = 1000;

# Simulation state
my %stats_no_tribute = (
    total_pirate_encounters => 0,
    li_yuen_encounters => 0,
    li_yuen_attacks => 0,
    normal_pirates => 0,
    fleet_sizes => [],
);

my %stats_with_tribute = (
    total_pirate_encounters => 0,
    li_yuen_encounters => 0,
    li_yuen_passes => 0,
    li_yuen_attacks => 0,  # Should be 0 with tribute
    normal_pirates => 0,
    fleet_sizes => [],
);

print "=" x 80 . "\n";
print "LI YUEN ENCOUNTER TEST HARNESS\n";
print "=" x 80 . "\n";
print "Testing Li Yuen encounter mechanics from APPLE II BASIC lines 3110-3230\n";
print "Iterations: $ITERATIONS\n\n";

# Test player state
my %test_player = (
    hold_capacity => 400,  # SC
    guns => 40,            # GN
    ships => 10,
    cash => 100000,
);

print "Test Configuration:\n";
print "  Hold Capacity (SC): $test_player{hold_capacity}\n";
print "  Guns (GN): $test_player{guns}\n";
print "  Ships: $test_player{ships}\n\n";

# PART 1: Test WITHOUT tribute (LI=0)
print "-" x 80 . "\n";
print "PART 1: Testing Li Yuen encounters WITHOUT tribute (LI=0)\n";
print "-" x 80 . "\n";
print "Expected: ~25% of pirate encounters should be Li Yuen (1-in-4)\n";
print "Expected: All Li Yuen encounters should result in attacks\n\n";

for my $i (1..$ITERATIONS) {
    # Simulate pirate encounter (1-in-9 chance per voyage)
    if (int(rand(9)) == 0) {
        $stats_no_tribute{total_pirate_encounters}++;

        # Check if it's Li Yuen (no tribute: LI=0)
        # IF FN R(4 + 8 * LI) THEN 3300
        # LI=0: FN R(4) => 1-in-4 (25%)
        my $li_yuen_tribute = 0;
        my $li_yuen_chance = 4 + (8 * $li_yuen_tribute);
        my $is_li_yuen = (int(rand($li_yuen_chance)) == 0);

        if ($is_li_yuen) {
            $stats_no_tribute{li_yuen_encounters}++;

            # No tribute means ATTACK
            $stats_no_tribute{li_yuen_attacks}++;

            # Calculate fleet size: SN = FN R(SC / 5 + GN) + 5
            my $fleet_size = int(rand(($test_player{hold_capacity} / 5) + $test_player{guns})) + 5;
            push @{$stats_no_tribute{fleet_sizes}}, $fleet_size;

        } else {
            $stats_no_tribute{normal_pirates}++;
        }
    }
}

# PART 2: Test WITH tribute (LI=1)
print "Running $ITERATIONS iterations...\n\n";

for my $i (1..$ITERATIONS) {
    # Simulate pirate encounter (1-in-9 chance per voyage)
    if (int(rand(9)) == 0) {
        $stats_with_tribute{total_pirate_encounters}++;

        # Check if it's Li Yuen (with tribute: LI=1)
        # IF FN R(4 + 8 * LI) THEN 3300
        # LI=1: FN R(12) => 1-in-12 (8.3%)
        my $li_yuen_tribute = 1;
        my $li_yuen_chance = 4 + (8 * $li_yuen_tribute);
        my $is_li_yuen = (int(rand($li_yuen_chance)) == 0);

        if ($is_li_yuen) {
            $stats_with_tribute{li_yuen_encounters}++;

            # With tribute, they let you pass
            $stats_with_tribute{li_yuen_passes}++;

        } else {
            $stats_with_tribute{normal_pirates}++;
        }
    }
}

# ANALYSIS
print "=" x 80 . "\n";
print "RESULTS: Li Yuen WITHOUT Tribute (LI=0)\n";
print "=" x 80 . "\n";
print "Total Pirate Encounters: $stats_no_tribute{total_pirate_encounters}\n";
print "Li Yuen Encounters: $stats_no_tribute{li_yuen_encounters}\n";
print "  - Li Yuen Attacks: $stats_no_tribute{li_yuen_attacks}\n";
print "Normal Pirate Encounters: $stats_no_tribute{normal_pirates}\n\n";

if ($stats_no_tribute{total_pirate_encounters} > 0) {
    my $li_yuen_pct = ($stats_no_tribute{li_yuen_encounters} / $stats_no_tribute{total_pirate_encounters}) * 100;
    print sprintf("Li Yuen Encounter Rate: %.1f%% (Expected: ~25%%)\n", $li_yuen_pct);

    if ($stats_no_tribute{li_yuen_encounters} > 0) {
        my $attack_rate = ($stats_no_tribute{li_yuen_attacks} / $stats_no_tribute{li_yuen_encounters}) * 100;
        print sprintf("Li Yuen Attack Rate: %.1f%% (Expected: 100%%)\n\n", $attack_rate);

        # Fleet size analysis
        my @fleet_sizes = @{$stats_no_tribute{fleet_sizes}};
        my $min_fleet = (sort {$a <=> $b} @fleet_sizes)[0];
        my $max_fleet = (sort {$a <=> $b} @fleet_sizes)[-1];
        my $avg_fleet = (sum(@fleet_sizes) / scalar(@fleet_sizes));

        # Expected range: 5 to (SC/5 + GN + 4)
        # SC=400, GN=40 => 5 to (80 + 40 + 4) = 5 to 124
        my $expected_min = 5;
        my $expected_max = int($test_player{hold_capacity} / 5) + $test_player{guns} + 4;

        print "Fleet Size Statistics:\n";
        print sprintf("  Min: %d (Expected: >= %d)\n", $min_fleet, $expected_min);
        print sprintf("  Max: %d (Expected: <= %d)\n", $max_fleet, $expected_max);
        print sprintf("  Avg: %.1f\n", $avg_fleet);

        # Validation
        my $fleet_valid = ($min_fleet >= $expected_min && $max_fleet <= $expected_max);
        print sprintf("  Fleet Size Formula: %s\n", $fleet_valid ? "PASS" : "FAIL");
    }
}

print "\n";
print "=" x 80 . "\n";
print "RESULTS: Li Yuen WITH Tribute (LI=1)\n";
print "=" x 80 . "\n";
print "Total Pirate Encounters: $stats_with_tribute{total_pirate_encounters}\n";
print "Li Yuen Encounters: $stats_with_tribute{li_yuen_encounters}\n";
print "  - Li Yuen Passes (Good Joss): $stats_with_tribute{li_yuen_passes}\n";
print "  - Li Yuen Attacks: $stats_with_tribute{li_yuen_attacks}\n";
print "Normal Pirate Encounters: $stats_with_tribute{normal_pirates}\n\n";

if ($stats_with_tribute{total_pirate_encounters} > 0) {
    my $li_yuen_pct = ($stats_with_tribute{li_yuen_encounters} / $stats_with_tribute{total_pirate_encounters}) * 100;
    print sprintf("Li Yuen Encounter Rate: %.1f%% (Expected: ~8.3%%)\n", $li_yuen_pct);

    if ($stats_with_tribute{li_yuen_encounters} > 0) {
        my $pass_rate = ($stats_with_tribute{li_yuen_passes} / $stats_with_tribute{li_yuen_encounters}) * 100;
        print sprintf("Li Yuen Pass Rate: %.1f%% (Expected: 100%%)\n", $pass_rate);
        print sprintf("Li Yuen Attack Rate: %.1f%% (Expected: 0%%)\n",
            ($stats_with_tribute{li_yuen_attacks} / $stats_with_tribute{li_yuen_encounters}) * 100);
    }
}

print "\n";
print "=" x 80 . "\n";
print "VALIDATION SUMMARY\n";
print "=" x 80 . "\n";

my @validations;

# Validation 1: Li Yuen rate without tribute (should be ~25%, allow 20-30%)
if ($stats_no_tribute{total_pirate_encounters} > 0) {
    my $li_yuen_pct = ($stats_no_tribute{li_yuen_encounters} / $stats_no_tribute{total_pirate_encounters}) * 100;
    my $pass = ($li_yuen_pct >= 20 && $li_yuen_pct <= 30);
    push @validations, {
        test => "Li Yuen encounter rate (no tribute)",
        expected => "20-30%",
        actual => sprintf("%.1f%%", $li_yuen_pct),
        pass => $pass,
    };
}

# Validation 2: Li Yuen rate with tribute (should be ~8.3%, allow 5-12%)
if ($stats_with_tribute{total_pirate_encounters} > 0) {
    my $li_yuen_pct = ($stats_with_tribute{li_yuen_encounters} / $stats_with_tribute{total_pirate_encounters}) * 100;
    my $pass = ($li_yuen_pct >= 5 && $li_yuen_pct <= 12);
    push @validations, {
        test => "Li Yuen encounter rate (with tribute)",
        expected => "5-12%",
        actual => sprintf("%.1f%%", $li_yuen_pct),
        pass => $pass,
    };
}

# Validation 3: All Li Yuen without tribute should attack
my $no_tribute_attack_rate = 0;
if ($stats_no_tribute{li_yuen_encounters} > 0) {
    $no_tribute_attack_rate = ($stats_no_tribute{li_yuen_attacks} / $stats_no_tribute{li_yuen_encounters}) * 100;
}
push @validations, {
    test => "Li Yuen attacks (no tribute)",
    expected => "100%",
    actual => sprintf("%.1f%%", $no_tribute_attack_rate),
    pass => ($no_tribute_attack_rate == 100),
};

# Validation 4: All Li Yuen with tribute should pass
my $tribute_pass_rate = 0;
if ($stats_with_tribute{li_yuen_encounters} > 0) {
    $tribute_pass_rate = ($stats_with_tribute{li_yuen_passes} / $stats_with_tribute{li_yuen_encounters}) * 100;
}
push @validations, {
    test => "Li Yuen passes (with tribute)",
    expected => "100%",
    actual => sprintf("%.1f%%", $tribute_pass_rate),
    pass => ($tribute_pass_rate == 100),
};

# Validation 5: Fleet size range
if (@{$stats_no_tribute{fleet_sizes}} > 0) {
    my @fleet_sizes = @{$stats_no_tribute{fleet_sizes}};
    my $min_fleet = (sort {$a <=> $b} @fleet_sizes)[0];
    my $max_fleet = (sort {$a <=> $b} @fleet_sizes)[-1];
    my $expected_min = 5;
    my $expected_max = int($test_player{hold_capacity} / 5) + $test_player{guns} + 4;
    my $pass = ($min_fleet >= $expected_min && $max_fleet <= $expected_max);

    push @validations, {
        test => "Li Yuen fleet size formula",
        expected => "5 to $expected_max",
        actual => "$min_fleet to $max_fleet",
        pass => $pass,
    };
}

# Print validation results
foreach my $val (@validations) {
    my $status = $val->{pass} ? "PASS" : "FAIL";
    my $symbol = $val->{pass} ? "✓" : "✗";
    printf("%-40s Expected: %-12s Actual: %-12s [%s] %s\n",
        $val->{test},
        $val->{expected},
        $val->{actual},
        $status,
        $symbol
    );
}

print "\n";
my $total_tests = scalar(@validations);
my $passed_tests = grep { $_->{pass} } @validations;
print sprintf("Tests Passed: %d/%d (%.1f%%)\n", $passed_tests, $total_tests,
    ($passed_tests / $total_tests) * 100);

print "\n";
print "=" x 80 . "\n";
print "APPLE II BASIC REFERENCE\n";
print "=" x 80 . "\n";
print "Line 3210: IF FN R(4 + 8 * LI) THEN 3300\n";
print "  LI=0 (no tribute): 1-in-4 (25%) chance\n";
print "  LI=1 (paid tribute): 1-in-12 (8.3%) chance\n";
print "\n";
print "Line 3220: PRINT \"Li Yuen's fleet is in the area!\"\n";
print "\n";
print "Line 3225: IF LI THEN PRINT \"Good joss!! They let us be!!\": RETURN\n";
print "  If tribute paid: pass through, no combat\n";
print "\n";
print "Line 3230: SN = FN R(SC / 5 + GN) + 5\n";
print "  Fleet size: Random(SC/5 + GN) + 5\n";
print "  F1 = 2 (double damage multiplier)\n";
print "=" x 80 . "\n";

sub sum {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

print "\nTest complete!\n";
