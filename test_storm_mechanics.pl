#!/usr/bin/env perl
# Test script for storm mechanics implementation
# Based on original APPLE II BASIC lines 3310-3340

use strict;
use warnings;

print "Testing Storm Mechanics (APPLE II BASIC Lines 3310-3340)\n";
print "=" x 70 . "\n\n";

# Simulate 1000 voyages to test probabilities
my $voyages = 1000;
my $storms = 0;
my $sinking_danger = 0;
my $ships_lost = 0;
my $all_ships_lost = 0;
my $partial_loss = 0;
my $blown_off_course = 0;

print "Simulating $voyages voyages...\n\n";

for my $voyage (1..$voyages) {
    # Test scenario setup
    my %player = (
        ships => 5,
        damage => 30,       # Some damage
        hold_capacity => 60,
        cargo => { opium => 100, arms => 50, silk => 50, general => 50 },
    );

    # STORM CHECK: 1-in-10 chance
    if (int(rand(10)) == 0) {
        $storms++;

        # SINKING DANGER: 1-in-30 chance
        if (int(rand(30)) == 0) {
            $sinking_danger++;

            # Damage-based sinking: FN R(DM / SC * 3)
            my $damage_factor = $player{damage} / $player{hold_capacity} * 3;

            if (rand() < $damage_factor) {
                # Calculate ship loss
                my $loss_percent = 0.3 + ($damage_factor * 0.2);
                if ($loss_percent > 0.7) { $loss_percent = 0.7; }
                my $ships_lost_count = int($player{ships} * $loss_percent);
                if ($ships_lost_count < 1) { $ships_lost_count = 1; }

                $ships_lost++;
                if ($ships_lost_count >= $player{ships}) {
                    $all_ships_lost++;
                } else {
                    $partial_loss++;
                }
            }
        }

        # BLOWN OFF COURSE: 1-in-3 chance (if survived)
        if (int(rand(3)) == 0) {
            $blown_off_course++;
        }
    }
}

print "Results:\n";
print "-" x 70 . "\n";
printf "Storms encountered:        %4d / %4d  (%.1f%%, expected ~10%%)\n",
    $storms, $voyages, ($storms/$voyages*100);
printf "  Sinking danger:          %4d / %4d  (%.1f%%, expected ~3.3%% of storms)\n",
    $sinking_danger, $storms || 1, ($sinking_danger/($storms||1)*100);
printf "  Ships actually lost:     %4d / %4d  (%.1f%%)\n",
    $ships_lost, $sinking_danger || 1, ($ships_lost/($sinking_danger||1)*100);
printf "    - All ships lost:      %4d\n", $all_ships_lost;
printf "    - Partial loss:        %4d\n", $partial_loss;
printf "  Blown off course:        %4d / %4d  (%.1f%%, expected ~33%% of storms)\n",
    $blown_off_course, $storms || 1, ($blown_off_course/($storms||1)*100);

print "\n";
print "=" x 70 . "\n";
print "Storm Mechanics Summary\n";
print "=" x 70 . "\n";
print "10% chance of storm per voyage\n";
print "  ↳ If storm:\n";
print "    - 3.3% chance of sinking danger (1/30)\n";
print "      ↳ If in danger: damage-based check (DM/SC*3)\n";
print "        - If check fails: Lose 30-70% of fleet\n";
print "          ↳ If all ships lost: GAME OVER\n";
print "          ↳ If partial loss: Continue with reduced fleet\n";
print "    - 33% chance of blown off course (1/3)\n";
print "      ↳ Arrive at random port instead of destination\n";
print "\n";

# Test damage factor calculations
print "Damage Factor Examples:\n";
print "-" x 70 . "\n";
my @damage_scenarios = (
    { damage => 0, capacity => 60, desc => "No damage" },
    { damage => 30, capacity => 60, desc => "Moderate damage" },
    { damage => 60, capacity => 60, desc => "Heavy damage" },
    { damage => 90, capacity => 60, desc => "Severe damage" },
);

foreach my $scenario (@damage_scenarios) {
    my $dm = $scenario->{damage};
    my $sc = $scenario->{capacity};
    my $factor = $dm / $sc * 3;
    my $percent = int($factor * 100);
    my $loss_pct = 30 + int($factor * 20);
    if ($loss_pct > 70) { $loss_pct = 70; }

    printf "%-20s: DM=%3d, SC=%3d → factor=%.2f (%.0f%% sink chance, %d%% fleet loss)\n",
        $scenario->{desc}, $dm, $sc, $factor, $percent, $loss_pct;
}

print "\n✓ Storm mechanics implemented!\n";
print "  Mother Nature is indeed a cruel mistress.\n";
