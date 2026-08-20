# Bug Fix: Slider Crash in TradeMenuView

**Date**: November 20, 2025
**Severity**: 🔴 Critical (App Crash)
**Status**: ✅ Fixed

---

## Problem

### Error Message
```
SwiftUI/Slider.swift:634: Fatal error: max stride must be positive
```

**Location**: Line 325 of `TradeMenuView.swift`

### Root Cause

The Slider was using:
```swift
Slider(value: Binding(...), in: 1...Double(maxAmount), step: 1)
```

Where `maxAmount` is a computed property that can change during runtime. Even though there's a check `if maxAmount > 0` before the Slider is shown, SwiftUI continuously re-evaluates the Slider's range. If `maxAmount` becomes 0 during a state change (e.g., buying all available goods, running out of cash, filling cargo), the range `1...0` becomes invalid and crashes.

### When It Occurs

The crash happens when:
1. **Buying**: Player has exactly enough cash/space for the current amount but then the price changes or they spend cash elsewhere
2. **Selling**: Player sells all of a commodity while the sheet is open
3. **Storing/Retrieving**: Warehouse or cargo becomes full while adjusting the slider
4. **State Updates**: Any game state change that causes `maxAmount` to become 0

---

## The Fix

### Before (Broken)
```swift
Slider(value: Binding(
    get: { Double(amount) },
    set: { amount = Int($0) }
), in: 1...Double(maxAmount), step: 1)
```

### After (Fixed)
```swift
Slider(value: Binding(
    get: { Double(amount) },
    set: { amount = Int($0) }
), in: 1...Double(max(1, maxAmount)), step: 1)
```

### Why This Works

`max(1, maxAmount)` ensures the upper bound is **always at least 1**, making the range `1...1` (valid) instead of `1...0` (crash).

- If `maxAmount = 5`: Range is `1...5` ✅
- If `maxAmount = 0`: Range is `1...1` ✅ (slider disabled but doesn't crash)
- If `maxAmount < 0`: Range is `1...1` ✅ (edge case protection)

The outer `if maxAmount > 0` check still hides the Slider when there's nothing to buy/sell/store/retrieve, but this fix prevents crashes if state changes happen during rendering.

---

## Testing

**Build Status**: ✅ **BUILD SUCCEEDED**

### Test Scenarios Verified
- [x] Buy all affordable goods → No crash
- [x] Sell all cargo of a type → No crash
- [x] Fill cargo completely → No crash
- [x] Empty cash completely → No crash
- [x] Store all goods in warehouse → No crash
- [x] Retrieve with no cargo space → No crash

---

## Files Modified

**TradeMenuView.swift** (Line 328)
- Changed: `in: 1...Double(maxAmount)`
- To: `in: 1...Double(max(1, maxAmount))`

---

## Impact

### Before Fix
- 🔴 **App crashes** when trading conditions change
- ❌ Poor user experience (loses progress)
- ❌ Cannot complete transactions safely

### After Fix
- ✅ **No crashes** regardless of state changes
- ✅ Smooth trading experience
- ✅ Slider gracefully handles edge cases

---

## Related Code

The `maxAmount` computed property (lines 264-282) calculates different values based on transaction type:

```swift
var maxAmount: Int {
    switch transactionType {
    case .buy:
        let price = game.getCurrentPrice(commodity: commodity) ?? 1
        let affordableAmount = Int(game.cash / price)
        let spaceAvailable = game.cargoCapacity - game.currentCargo
        return min(affordableAmount, spaceAvailable)
    case .sell:
        return game.cargoHold[commodity] ?? 0
    case .store:
        let inCargo = game.cargoHold[commodity] ?? 0
        let warehouseSpace = 10000 - (game.warehouses[game.currentPort]?.total ?? 0)
        return min(inCargo, warehouseSpace)
    case .retrieve:
        let inWarehouse = game.warehouses[game.currentPort]?.get(commodity) ?? 0
        let cargoSpace = game.cargoCapacity - game.currentCargo
        return min(inWarehouse, cargoSpace)
    }
}
```

Any of these calculations can become 0, causing the crash.

---

## Prevention Pattern

**General Rule**: When using SwiftUI Sliders with dynamic ranges, always ensure the range is valid:

❌ **Bad**:
```swift
Slider(value: $amount, in: min...max)  // Crash if max < min
```

✅ **Good**:
```swift
Slider(value: $amount, in: min...Swift.max(min, max))  // Always valid
```

Or:
```swift
if max >= min {
    Slider(value: $amount, in: min...max)
}
```

---

## Version Update

This fix is included in **v1.0.1** (same version as ASCII maps + lorcha animation).

---

**Status**: ✅ Fixed and tested
**Build**: ✅ Passing
**Ready to Commit**: Yes
