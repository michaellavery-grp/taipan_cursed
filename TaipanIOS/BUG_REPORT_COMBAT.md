# Critical Bug Report: Combat System Too Simplistic

**Date**: November 20, 2025
**Severity**: 🔴 **CRITICAL** - Breaks Core Gameplay
**Component**: GameModel.swift - Combat System

---

## Problem Summary

The iOS Swift version has a **completely broken combat system** that:
1. **Resolves instantly** in one comparison (no multi-round combat)
2. **No combat loop** - player gets one choice and combat ends
3. **Excessive damage** - 40% damage from single encounter
4. **No iterative fighting** - can't whittle down enemy fleet
5. **Unrealistic outcomes** - binary win/lose with no strategy

---

## User Report

> "Combat seemed very rudimentary. Only one round and the ship was destroyed down to 40% reliability."

This is accurate - the Swift version does NOT implement the combat loop from the original game.

---

## Root Cause

### Current (Broken) Swift Implementation

```swift
func fight() -> CombatResult {
    var result = combat

    if guns > combat.pirateFleet * 2 {
        // Instant victory
        result.outcome = .victory
    } else if guns > combat.pirateFleet {
        // Instant victory with damage
        result.outcome = .victory
        shipDamage = min(1.0, shipDamage + 0.2)  // 20% damage
    } else {
        // Instant defeat
        result.outcome = .defeat
        shipDamage = min(1.0, shipDamage + 0.4)  // 40% damage ← USER'S ISSUE
    }

    return result  // Combat ends immediately!
}
```

**Problem**: This is a **single comparison** that instantly resolves combat. No loop, no rounds, no strategy!

### Original Perl Implementation (Correct)

```perl
sub combat_loop {
    # Combat continues while there are enemy ships
    while ($num_ships > 0) {
        # Prompt player for action
        # (F)ight, (R)un, or (T)hrow cargo?

        # Wait for user input
        # Process action (fight_run_throw)
        # Update combat state
        # Repeat until escape or all enemies defeated
    }
}

sub fight_run_throw {
    if ($orders == 1) {  # Fight
        # Calculate volley size based on guns
        while ($shots_fired < $total_firepower && $num_ships > 0) {
            # Fire volley of shots
            # Apply damage to random targets
            # Sink ships with health <= 0
            # Animate blasts and sinking
            # Replenish on-screen ships from remaining fleet
        }

        # Enemy return fire (ONCE per round)
        if ($num_ships > 0) {
            $damage_taken = int(rand($ed_scaled * $num_ships * $f1)) + int($num_ships / 2);
            $player{damage} += $damage_taken;
        }
    }
    elsif ($orders == 2) {  # Run
        # Escape formula: OK and IK increase each attempt
        $ok += $ik++;
        if (rand() * $ok > rand() * $num_ships) {
            # Escaped!
            $num_ships = 0;
        } else {
            # Failed - enemy attacks
            $damage_taken = int(rand($ed_scaled * $num_ships * $f1)) + int($num_ships / 2);
        }
    }
    elsif ($orders == 3) {  # Throw cargo
        # Throw 1/3 of cargo, pirates leave
        $num_ships = 0;
    }
}
```

**Key Difference**: The Perl version has a **WHILE LOOP** that continues until `$num_ships == 0`. The player can fight multiple rounds, gradually reducing the enemy fleet.

---

## What Should Happen (Original Game)

### Scenario: 5 Pirates Attack, Player Has 20 Guns

**Round 1**:
- Player: "Fight"
- Player fires 20 guns (multiple volleys)
- **Sink 2 pirate ships** (20 guns × volleys with random damage)
- Enemy return fire: Take 15 damage
- **3 pirates remain** → Combat continues

**Round 2**:
- Player: "Fight again"
- Player fires 20 guns
- **Sink 1 more pirate ship**
- Enemy return fire: Take 10 damage
- **2 pirates remain** → Combat continues

**Round 3**:
- Player: "Run" (damage is getting bad)
- Escape chance calculation
- **Successfully escape!**
- Combat ends with 2 pirates still alive

**Result**: Gradual attrition, strategic decisions each round, manageable damage

---

## What Actually Happens (Swift iOS)

### Same Scenario: 5 Pirates Attack, Player Has 20 Guns

**Single Comparison**:
- `guns (20) > pirateFleet (5)` → TRUE
- Instant victory
- Take 20% damage
- **Combat immediately ends**

OR if player had 10 guns instead:

**Single Comparison**:
- `guns (10) < pirateFleet (5)` → TRUE (wait, no this is false, but let's say 3 guns)
- `guns (3) < pirateFleet (5)` → TRUE
- Instant defeat
- **Take 40% damage** ← THIS IS THE ISSUE
- Lose half of cargo
- **Combat immediately ends**

**Result**: No strategy, no rounds, massive damage, no fun

---

## Combat Flow Comparison

### Original Perl Game Flow

```
Encounter Pirates (5 ships)
    ↓
┌─> Combat Round 1
│   ├─ Prompt: (F)ight, (R)un, (T)hrow?
│   ├─ Player: Fight
│   ├─ Fire guns (sink 0-3 ships depending on luck)
│   ├─ Enemy return fire (take damage)
│   ├─ Update display
│   └─ Pirates remaining? YES → Loop back
│
├─> Combat Round 2
│   ├─ Prompt: (F)ight, (R)un, (T)hrow?
│   ├─ Player: Fight
│   ├─ Fire guns (sink more ships)
│   ├─ Enemy return fire
│   ├─ Pirates remaining? YES → Loop back
│
├─> Combat Round 3
│   ├─ Prompt: (F)ight, (R)un, (T)hrow?
│   ├─ Player: Run
│   ├─ Escape check (success!)
│   └─ Combat ends
│
End Combat
```

### Swift iOS "Game" Flow

```
Encounter Pirates (5 ships)
    ↓
One comparison: guns vs pirates
    ├─ If guns > pirates × 2: Win
    ├─ If guns > pirates: Win + 20% damage
    └─ If guns <= pirates: Lose + 40% damage
    ↓
Combat ends immediately
```

---

## Detailed Issues

### 1. No Combat Loop
**Missing**: The `while ($num_ships > 0)` loop that allows multiple rounds

**Impact**: Player can't gradually defeat enemies or make tactical decisions per round

### 2. No Volley System
**Missing**: The volley firing system that shoots guns in batches

```perl
while ($shots_fired < $total_firepower && $num_ships > 0) {
    # Fire volley
    # Sink ships
    # Replenish enemies
}
```

**Impact**: Combat isn't satisfying - no sense of each gun firing

### 3. No Progressive Sinking
**Missing**: Ships have health that degrades over multiple shots:

```perl
$ships_on_screen[$targeted] -= int(rand(30) + 10);  # Each hit does 10-40 damage
if ($ships_on_screen[$slot] <= 0) {  # Ship sinks when health <= 0
    sink_ship();
}
```

**Impact**: Can't gradually wear down enemy fleet

### 4. Excessive Damage Formula
**Wrong**:
```swift
shipDamage = min(1.0, shipDamage + 0.4)  // 40% damage from ONE encounter!
```

**Correct**:
```perl
# Damage per round (not per encounter):
$damage_taken = int(rand($ed_scaled * $num_ships * $f1)) + int($num_ships / 2);
# Where $ed_scaled = $ed / 20.0 (scaled down)
```

**Impact**: Player takes catastrophic damage from single encounter instead of gradual damage per round

### 5. No Escape Progression
**Wrong**:
```swift
let escapeChance = Double(guns) / Double(combat.pirateFleet * 5)
let escaped = Double.random(in: 0...1) < escapeChance
```

**Correct**:
```perl
$ok += $ik++;  # Escape chance INCREASES with each attempt
if (rand() * $ok > rand() * $num_ships) {
    # Escaped!
}
```

**Impact**: Can't try multiple times to escape with better odds

### 6. No Visual Feedback
**Missing**:
- Ship health indicators
- Volley animations
- Sinking animations
- Running combat statistics

**Impact**: No dramatic tension or visual storytelling

---

## Required Changes

### 1. Add Combat State Management

```swift
class CombatState {
    var pirateShips: [PirateShip] = []  // Track individual ships
    var roundNumber: Int = 0
    var escapeAttempts: Int = 0
    var totalDamageTaken: Double = 0
    var shipsSunk: Int = 0
}

struct PirateShip {
    var health: Int  // 20-50 HP
    var sunk: Bool = false
}
```

### 2. Implement Combat Loop

```swift
func startCombat(pirateCount: Int) {
    let combatState = initializeCombat(pirateCount: pirateCount)

    // Show combat view with (F)ight, (R)un, (T)hrow buttons
    // Combat view remains open until combat resolves
}

func processCombatRound(action: CombatAction, state: CombatState) {
    switch action {
    case .fight:
        // Fire guns in volleys
        // Sink ships
        // Enemy return fire
        // Check if pirates remain
        if state.piratesRemaining() > 0 {
            // Continue combat - prompt for next action
        } else {
            // Victory!
            endCombat(result: .victory)
        }

    case .run:
        state.escapeAttempts += 1
        let escaped = attemptEscape(state: state)
        if escaped {
            endCombat(result: .escaped)
        } else {
            // Failed escape - enemy attacks
            // Continue combat - prompt for next action
        }

    case .throwCargo:
        // Throw cargo, end combat
        endCombat(result: .bribed)
    }
}
```

### 3. Implement Proper Damage Formula

```swift
func calculateDamage(pirateCount: Int) -> Int {
    let edScaled = 0.5  // Damage severity (original: ED / 20)
    let baseDamage = Int.random(in: 0...Int(edScaled * Double(pirateCount)))
    let additionalDamage = pirateCount / 2
    return baseDamage + additionalDamage
}
```

### 4. Add Ship Health System

```swift
func initializePirateFleet(count: Int) -> [PirateShip] {
    return (0..<count).map { _ in
        PirateShip(health: Int.random(in: 20...50))
    }
}

func fireVolley(at pirates: inout [PirateShip], guns: Int) -> Int {
    var sunk = 0
    let shotsPerVolley = min(guns / 2, 10)

    for _ in 0..<guns {
        guard let targetIndex = pirates.indices.randomElement(),
              !pirates[targetIndex].sunk else { continue }

        let damage = Int.random(in: 10...40)
        pirates[targetIndex].health -= damage

        if pirates[targetIndex].health <= 0 {
            pirates[targetIndex].sunk = true
            sunk += 1
        }
    }

    return sunk
}
```

### 5. Improve Escape System

```swift
var ok: Int = 0  // Opportunity to escape
var ik: Int = 0  // Incremental knowledge

func attemptEscape(pirateCount: Int) -> Bool {
    ok += ik
    ik += 1

    let playerEscapeValue = Double.random(in: 0...Double(ok))
    let pirateChaseValue = Double.random(in: 0...Double(pirateCount))

    return playerEscapeValue > pirateChaseValue
}
```

---

## Impact on Gameplay

### Current Problems

1. **No Strategy**: One decision, instant result
2. **Too Punishing**: 40% damage from single encounter
3. **Not Fun**: No tension, no drama
4. **Not Faithful**: Completely different from original
5. **No Progression**: Can't gradually defeat enemies

### After Fix

1. **Strategic Depth**: Decide each round whether to fight, run, or throw
2. **Manageable Risk**: Damage accumulates over multiple rounds
3. **Engaging**: Watch ships sink, see damage accumulate
4. **Authentic**: Matches original Taipan! experience
5. **Rewarding**: Feel accomplishment sinking ships one by one

---

## Example Combat Session (Fixed)

```
ENCOUNTER: 8 pirate ships approach!

ROUND 1:
Player: Fight
> Firing 40 guns across 5 ships!
> Sunk 3 pirate ships!
> Enemy return fire: 12 damage
> 5 pirates remain
> Ship integrity: 88%

ROUND 2:
Player: Fight
> Firing 40 guns!
> Sunk 2 more pirate ships!
> Enemy return fire: 8 damage
> 3 pirates remain
> Ship integrity: 80%

ROUND 3:
Player: Run (damage getting bad)
> Attempting to escape...
> Failed! They're still on us!
> Enemy return fire: 6 damage
> 3 pirates remain
> Ship integrity: 74%

ROUND 4:
Player: Run (try again)
> Attempting to escape...
> Success! We lost them!
> Combat ends

RESULT:
- Sunk 5 of 8 pirates
- 26 damage taken (74% seaworthy)
- Survived with cargo intact
```

---

## Testing the Bug

To verify the current broken behavior:

1. Launch app
2. Sail to any port
3. Encounter pirates (random chance)
4. Choose "Fight"
5. **Observe**: Combat ends immediately
6. **Observe**: Take massive damage (20-40%)
7. **Observe**: No opportunity for multiple rounds

Expected (after fix):
- Combat continues with multiple rounds
- Choose action each round
- Gradually defeat enemies
- Reasonable damage accumulation

---

## Priority

**CRITICAL** - The game is supposed to be about trading AND pirate combat. Currently, combat is:
- Not fun
- Not strategic
- Not fair
- Not like the original

This needs to be fixed for the game to be playable.

---

## Estimated Effort

- **Combat state management**: 1-2 hours
- **Combat loop UI**: 2-3 hours
- **Volley system**: 1-2 hours
- **Damage formulas**: 1 hour
- **Testing**: 1-2 hours

**Total**: 6-10 hours of development

---

## Related Files

- `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/GameModel.swift` (lines 406-477)
- `/Users/michaellavery/github/taipan_cursed/Taipan_2020_v2.1.1.pl` (lines 763-1046, 1704-1750)
- Need to create: `CombatView.swift` for combat UI

---

## Conclusion

The Swift iOS combat system is a **placeholder** that does not implement the actual Taipan! combat mechanics. It needs a complete rewrite to add:

1. ✅ Combat loop (multiple rounds)
2. ✅ Per-ship health tracking
3. ✅ Volley firing system
4. ✅ Progressive escape attempts
5. ✅ Proper damage formulas
6. ✅ Combat UI with real-time updates

Without these, the game cannot be considered a proper Taipan! implementation.
