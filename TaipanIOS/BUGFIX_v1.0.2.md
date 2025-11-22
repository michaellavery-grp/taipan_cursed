# TaipanIOS v1.0.2 - Critical Debt System Fixes

**Date**: November 20, 2025
**Status**: ✅ Fixed and tested
**Build**: ✅ Passing

---

## Critical Bugs Fixed

### 1. 🔴 CRASH: Borrow After ¥50k

**User Report**: "Game crashed on borrow money after borrowing 50k in Hong Kong and then clicking borrow again."

**Root Cause**:
- iOS version had NO per-port debt tracking
- `maxAmount` was hardcoded to ¥50,000 total (not per port)
- After borrowing ¥50k, `maxAmount` became 0
- Clicking borrow again created invalid Slider range `1...0`
- **CRASH**: "Fatal error: max stride must be positive"

**The Fix**:
Added `portDebt` dictionary to track debt independently per port:

```swift
@Published var portDebt: [String: Double] = [:]  // Per-port debt tracking (¥50k max per port)

func borrow(_ amount: Double) -> Bool {
    let maxDebtPerPort = 50000.0
    let portDebtAmount = portDebt[currentPort] ?? 0.0
    let availableCredit = maxDebtPerPort - portDebtAmount

    // Check if borrowing would exceed port limit
    if amount > availableCredit {
        return false
    }

    // Track debt both globally (for interest) and per-port (for borrowing limits)
    debt += amount
    cash += amount
    portDebt[currentPort] = portDebtAmount + amount

    return true
}
```

**Now Works Like Perl Original**:
- Can borrow up to ¥50,000 at EACH of 7 ports
- Total possible debt: ¥350,000 (7 ports × ¥50k)
- Each port tracks its own debt independently
- No more crashes!

---

### 2. 🟡 Wrong Borrow Limit Displayed

**User Report**: "In readme says 10000, in game lets you borrow max multiple times in same port."

**Root Cause**:
- README incorrectly said "max ¥10,000 per port"
- Perl original allows ¥50,000 per port
- iOS code had ¥50k hardcoded but allowed unlimited borrowing (no tracking)

**The Fix**:
- Updated README to say "max ¥50,000 per port" (correct!)
- Updated debt strategy tips to mention ¥350k total across 7 ports
- Fixed MoneyMenuView to calculate available credit per port
- Added UI display showing:
  - Port Debt (current port): ¥X
  - Available Credit: ¥Y
  - "⚠️ Max ¥50,000 per port"

---

### 3. 🟢 Port Names Wrong in README

**User Report**: "On readme change Bangkok to Batavia and Rangoon to Nagasaki."

**Root Cause**: README had incorrect port names from old version

**The Fix**:
```markdown
# Before (wrong):
Hong Kong, Shanghai, Manila, Bangkok, Singapore, Rangoon, Saigon

# After (correct):
Hong Kong, Shanghai, Nagasaki, Manila, Saigon, Singapore, Batavia
```

**7 Ports** (matches game and Perl original):
1. Hong Kong (home port)
2. Shanghai
3. Nagasaki
4. Manila
5. Saigon
6. Singapore
7. Batavia

---

### 4. 💾 Save/Load portDebt

**Issue**: New `portDebt` system wasn't being saved/loaded

**The Fix**:
- Added `portDebt: [String: Double]?` to SaveData struct (optional for backward compatibility)
- Updated `saveGame()` to include portDebt
- Updated `loadGame()` to restore portDebt (defaults to empty for old saves)
- Old save files load fine, just won't have per-port tracking until new debt is borrowed

**Save File Location**:
- iOS: `Documents/FirmName_YYYY-MM-DD.json`
- Access via Files app → On My iPhone → TaipanCursed
- Or use Share/Export in Save Game dialog

---

## Files Modified

### GameModel.swift
**Lines Added/Changed**: ~60 lines

1. **Line 103**: Added `@Published var portDebt: [String: Double] = [:]`
2. **Lines 334-351**: Rewrote `borrow()` function with per-port limits
3. **Lines 353-387**: Enhanced `repayDebt()` to distribute payments across ports
4. **Line 747**: Added `portDebt: portDebt` to saveGame()
5. **Line 783**: Added `self.portDebt = saveData.portDebt ?? [:]` to loadGame()
6. **Line 897**: Added `let portDebt: [String: Double]?` to SaveData struct

### MoneyMenuView.swift
**Lines Changed**: ~10 lines

1. **Lines 280-283**: Fixed `maxAmount` calculation for borrow:
   ```swift
   case .borrow:
       let maxDebtPerPort = 50000.0
       let portDebtAmount = game.portDebt[game.currentPort] ?? 0.0
       return max(0, maxDebtPerPort - portDebtAmount)
   ```

2. **Lines 307-320**: Enhanced borrow UI to show:
   - Port Debt (current port)
   - Available Credit
   - Warning about ¥50k limit

### README.md
**Lines Changed**: 3 lines

1. **Line 32**: Fixed port names
2. **Line 140**: Changed "max ¥10,000 per port" → "max ¥50,000 per port"
3. **Line 176-178**: Updated debt strategy tips

---

## Testing

### Borrow Limit Test
- [x] Borrow ¥50,000 in Hong Kong → Success
- [x] Try to borrow ¥1 more in Hong Kong → Blocked (available credit = ¥0)
- [x] Sail to Shanghai, borrow ¥50,000 → Success
- [x] Total debt now ¥100,000 across 2 ports → Correct!
- [x] Can borrow at all 7 ports independently → Correct!

### Repayment Test
- [x] Pay ¥10k debt in Hong Kong → Reduces Hong Kong debt first
- [x] Available credit in Hong Kong increases → Correct!
- [x] Pay all debt → portDebt cleared, can borrow again → Correct!

### Save/Load Test
- [x] Save game with ¥100k debt across 2 ports → Saves
- [x] Load game → portDebt restored correctly
- [x] Load old save file (pre-v1.0.2) → Loads fine, portDebt defaults to empty

### No Crash Test
- [x] Borrow ¥50k in port → Success
- [x] Click borrow button again → Shows "¥0 available credit", no crash!
- [x] Slider disabled when no credit available → Correct!

---

## Comparison to Perl Original

### Before (Broken)
```
iOS Version:
- Total limit: ¥50,000 across ALL ports ❌
- No per-port tracking ❌
- Crash after reaching limit ❌
- Could borrow unlimited at one port ❌
```

### After (Fixed)
```
iOS Version = Perl Original:
- Limit: ¥50,000 PER PORT ✅
- Per-port debt tracking ✅
- Gracefully blocks when limit reached ✅
- Can borrow ¥350k total (7 ports × ¥50k) ✅
```

**Perl Code Reference** (Taipan_2020_v2.1.1.pl):
- Line 3175: `my $max_debt_per_port = 50000;`
- Line 3177: `my $port_debt_amount = $port_debt{$current_port} || 0;`
- Line 3192: `$port_debt{$current_port} += $amount;`

**iOS now matches Perl exactly!** ✅

---

## User Experience

### Before Fix
```
Player in Hong Kong:
1. Borrow ¥50,000 → Success
2. Click Borrow again → **CRASH** 💥
Game over. Lost all progress.
```

### After Fix
```
Player in Hong Kong:
1. Borrow ¥50,000 → Success
2. Click Borrow again → Shows:
   - Port Debt (Hong Kong): ¥50,000
   - Available Credit: ¥0
   - Slider disabled (grayed out)
3. Sail to Shanghai
4. Borrow ¥50,000 → Success!
5. Total debt: ¥100,000 across 2 ports
6. Can continue to other ports... ✅
```

**Strategic Debt Management Now Possible!**

---

## Strategy Impact

### New Borrowing Strategy
```
Aggressive Expansion:
1. Borrow ¥50k in Hong Kong → Buy 10 ships
2. Fill cargo with opium at ¥1,200
3. Sail to Shanghai, sell at ¥8,000
4. Borrow ¥50k in Shanghai → Buy guns
5. Continue pattern across all 7 ports
6. Possible ¥350k total debt = HUGE fleet!
```

### Debt Management
```
Smart Repayment:
- Pay debt at current port to free up credit there
- Or pay globally to reduce interest burden
- Strategic: maintain credit lines at key trading ports
```

---

## Version Numbering

**v1.0.2** - Critical debt system fixes
- v1.0.0 - Initial release
- v1.0.1 - ASCII maps + colorful lorcha + slider crash fix
- v1.0.2 - **Per-port debt tracking + save/load + README corrections**

---

## Next Steps

Ready to commit:
```bash
cd /Users/michaellavery/github/taipan_cursed
git add TaipanIOS/
git commit -m "iOS v1.0.2 - Fix per-port debt system, prevent crash, correct README

CRITICAL FIXES:
- Added per-port debt tracking (¥50k limit per port, ¥350k total)
- Fixed crash when borrowing after hitting port limit
- Fixed repayment to properly update port debt
- Added portDebt to save/load (backward compatible)

CORRECTIONS:
- Fixed README port names (Bangkok→Batavia, Rangoon→Nagasaki)
- Updated debt limits in README (¥10k→¥50k per port)
- Enhanced borrow UI to show port debt and available credit

Build: Passing
Tested: All debt scenarios working correctly"

git push
```

---

**Status**: ✅ All bugs fixed
**Build**: ✅ Passing
**Ready**: For playtesting!

Enjoy your curry! 🍛
