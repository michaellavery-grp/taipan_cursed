# Critical Bug Report: Global Pricing System

**Date**: November 20, 2025
**Severity**: 🔴 **CRITICAL** - Game Breaking
**Component**: GameModel.swift - Pricing System

---

## Problem Summary

The iOS Swift version has a **fundamentally broken pricing system** that makes the game unplayable as a trading game. All ports have the **same prices for all commodities**, eliminating the core trading mechanic.

---

## Root Cause

### Current (Broken) Architecture

The Swift version stores prices **globally** per commodity:

```swift
// GameModel.swift line 110
@Published var commodities: [String: Commodity] = [:]

// Only ONE price per commodity across ALL ports
commodities["opium"]?.currentPrice   // Same price everywhere!
commodities["arms"]?.currentPrice    // Same price everywhere!
commodities["silk"]?.currentPrice    // Same price everywhere!
commodities["general"]?.currentPrice // Same price everywhere!
```

### Original Perl Architecture (Correct)

The Perl version stores prices **per-port, per-commodity**:

```perl
# Line 146: %port_prices hash structure
$port_prices{$port}{$good} = price

# Different prices in each port!
$port_prices{"Hong Kong"}{opium}   = 4500
$port_prices{"Shanghai"}{opium}    = 6200
$port_prices{"Nagasaki"}{opium}    = 5800
# etc...
```

---

## Impact on Gameplay

### What Should Happen (Perl Original)
1. Player arrives at Hong Kong, sees Opium at ¥4,500
2. Player sails to Shanghai, sees Opium at ¥6,200 (**+38% profit!**)
3. Player buys low in Hong Kong, sells high in Shanghai
4. Prices vary dynamically with trends per port
5. Trading strategy matters

### What Actually Happens (Swift iOS)
1. Player arrives at Hong Kong, sees Opium at ¥5,000
2. Player sails to Shanghai, sees Opium at ¥5,000 (**no difference**)
3. No reason to trade between ports
4. Price changes globally when `updatePrices()` is called
5. **Game is broken** - no trading strategy possible

---

## Evidence in Code

### Swift: Global Price Updates

```swift
// GameModel.swift lines 161-180
func updatePrices() {
    for (key, var commodity) in commodities {
        // ... price calculation ...
        commodity.currentPrice = newPrice  // ONE price for all ports!
        commodities[key] = commodity
    }
}
```

### Perl: Per-Port Price Updates

```perl
# Taipan_2020_v2.1.1.pl lines 206-250
sub generate_prices {
    foreach my $port (@ports) {          # For EACH port
        foreach my $good (@goods) {      # For EACH good
            # ... price calculation ...
            $port_prices{$port}{$good} = $new_price;  # Unique per port!
        }
    }
}
```

### Swift: Trading Uses Global Price

```swift
// GameModel.swift line 187
func buyCommodity(_ commodity: String, amount: Int) -> Bool {
    guard let price = commodities[commodity]?.currentPrice else { return false }
    // Uses same price regardless of current port!
}
```

### Perl: Trading Uses Port-Specific Price

```perl
# Taipan_2020_v2.1.1.pl line 2451
my $price = $port_prices{$player{port}}{$good} * $amount;
# Uses price specific to player's current port!
```

---

## Required Fix

### New Data Structure Needed

Change from:
```swift
// Current (wrong):
@Published var commodities: [String: Commodity] = [:]
// Structure: commodities[commodity_name] = Commodity(currentPrice)
```

To:
```swift
// Correct:
@Published var portPrices: [String: [String: Double]] = [:]
// Structure: portPrices[port_name][commodity_name] = price

// Or more type-safe:
@Published var portPrices: [String: [String: CommodityPrice]] = [:]

struct CommodityPrice: Codable {
    var price: Double
    var trend: Double
    var momentum: Double
}
```

### Changes Required

1. **GameModel.swift**:
   - Add `portPrices: [String: [String: CommodityPrice]]` to replace global `commodities`
   - Keep `commodities` for base prices and volatility only
   - Rewrite `updatePrices()` to update each port separately
   - Rewrite `buyCommodity()` to use `portPrices[currentPort][commodity]`
   - Rewrite `sellCommodity()` to use `portPrices[currentPort][commodity]`

2. **TradeMenuView.swift**:
   - Change `game.commodities[commodity]?.currentPrice`
   - To: `game.portPrices[game.currentPort]?[commodity]?.price`
   - Update all price display logic

3. **ContentView.swift**:
   - Update any price display logic
   - Show port-specific prices in status area

4. **Price Generation**:
   - Initialize prices for each port independently
   - Update prices for each port with independent trends
   - Each port's price evolves separately over time

---

## Testing the Bug

You can verify this bug by:

1. Launch the app
2. Note the Opium price in Hong Kong (e.g., ¥5,000)
3. Sail to Shanghai
4. Check the Opium price - **it will be exactly the same ¥5,000**
5. Check ALL commodities in ALL ports - **all prices are identical everywhere**

In the original Perl game:
- Prices vary by ±80% for Opium (5000 ± 4000 = 1000-9000 range)
- Prices differ significantly between ports
- This creates trading opportunities

---

## Why This Happened

The Swift conversion likely misunderstood the Perl data structure:

```perl
# Perl: Two-dimensional hash
%port_prices = (
    "Hong Kong" => { opium => 4500, arms => 45, silk => 450, general => 9 },
    "Shanghai"  => { opium => 6200, arms => 62, silk => 520, general => 12 },
    # ...
);
```

Was incorrectly translated to:

```swift
// Swift: One-dimensional dictionary (wrong!)
commodities = [
    "opium": Commodity(currentPrice: 5000),
    "arms": Commodity(currentPrice: 50),
    # ...
]
```

Should have been:

```swift
// Swift: Two-dimensional dictionary (correct!)
portPrices = [
    "Hong Kong": ["opium": 4500, "arms": 45, "silk": 450, "general": 9],
    "Shanghai": ["opium": 6200, "arms": 62, "silk": 520, "general": 12],
    # ...
]
```

---

## Additional Issues

### Hot Deals System Also Broken

The Perl game has a "hot deals" tracker that shows opium prices across all ports (lines 263-277):

```perl
sub calculate_median_opium_price {
    my ($good) = @_;
    my @prices = sort { $a <=> $b } map { $port_prices{$_}{$good} } @ports;
    # Calculates median from DIFFERENT prices per port
}
```

In Swift, this would show **the same price 7 times** since all ports have identical prices!

### Price Trends System Partially Broken

The Perl game tracks trends **per-port, per-commodity**:

```perl
# Line 149
$price_trends{$port}{$good} = {direction => 1/-1, momentum => 0.0-1.0}
```

The Swift version only tracks trends **per-commodity globally**:

```swift
// Line 12-13 in Commodity struct
var trend: Double
var momentum: Double
```

This means all ports have the same trend direction, further reducing price diversity.

---

## Recommendation

**This bug requires a significant refactoring** of the pricing system to match the original Perl architecture. The changes affect:

- GameModel.swift (~50-100 lines of changes)
- TradeMenuView.swift (~10-20 lines of changes)
- Any view displaying prices

**Estimated effort**: 2-3 hours of development + testing

**Priority**: Should be fixed before any other features are added, as it breaks the core game mechanic.

---

## Related Files

- `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/GameModel.swift`
- `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/TradeMenuView.swift`
- `/Users/michaellavery/github/taipan_cursed/Taipan_2020_v2.1.1.pl` (reference implementation)

---

## Next Steps

1. Review this bug report
2. Decide on data structure approach (simple `[String: [String: Double]]` vs more complex type-safe approach)
3. Create a new version of GameModel.swift with per-port pricing
4. Update all views to use per-port prices
5. Test that prices vary correctly between ports
6. Test that price trends work independently per port
7. Test save/load with new data structure
