# Bug Fix: Negative Days Elapsed

**Date**: November 20, 2025
**Severity**: 🟡 Display Bug
**Status**: ✅ Fixed

---

## Problem

**User Report**: "Why would Days Elapsed be -40107?"

**Displayed**: Days Elapsed: -40,107

**Expected**: Days Elapsed: 0 (on day 1), then 1, 2, 3... as game progresses

---

## Root Cause

**SystemMenuView.swift Line 192** was calculating days from **Unix epoch (1970-01-01)** to game date (1860):

```swift
// WRONG: Calculating backward in time!
let days = Calendar.current.dateComponents([.day],
    from: Date(timeIntervalSince1970: 0),  // Jan 1, 1970
    to: game.gameDate).day ?? 0             // 1860/01/01
```

**Math**:
- 1970 - 1860 = 110 years backward
- 110 years × 365.25 days/year ≈ 40,177 days
- Result: **-40,107 days** (approximately -110 years)

---

## The Fix

### 1. Added gameStartDate Property

**GameModel.swift** (Line 130):
```swift
let gameStartDate: Date = {
    var components = DateComponents()
    components.year = 1860
    components.month = 1
    components.day = 1
    return Calendar.current.date(from: components) ?? Date()
}()
```

This stores the game start date (1860/01/01) as a fixed reference point.

### 2. Fixed Days Calculation

**SystemMenuView.swift** (Line 192):
```swift
// CORRECT: Days from game start to current game date
let days = Calendar.current.dateComponents([.day],
    from: game.gameStartDate,  // 1860/01/01 (game start)
    to: game.gameDate).day ?? 0  // Current game date
```

**Now**:
- Start: 1860/01/01 → Days Elapsed: 0
- After 1 voyage (5 days): 1860/01/06 → Days Elapsed: 5
- After 1 month: 1860/02/01 → Days Elapsed: 31
- After 1 year: 1861/01/01 → Days Elapsed: 365

---

## Bonus Fix: Credits Updated

**SystemMenuView.swift** (Lines 218-228):

### Before (Wrong)
```swift
Text("Original game by Art Canfil (1979)")  // ❌ Wrong year
Text("iOS version 2024")                     // ❌ Missing credits
```

### After (Correct)
```swift
Text("Original game by Art Canfil (1982)")  // ✅ Correct year
Text("Perl Curses::UI version by Michael Lavery (2020-2025)")  // ✅ Added
Text("iOS version 2025 by Claude Code")     // ✅ Proper credits
```

**Credits Now Show**:
1. **Art Canfil (1982)** - Original Apple II BASIC game
2. **Michael Lavery (2020-2025)** - Perl Curses::UI version
3. **Claude Code (2025)** - iOS SwiftUI port

---

## Files Modified

### GameModel.swift
**Line 130-136**: Added `gameStartDate` constant
```swift
let gameStartDate: Date = {
    var components = DateComponents()
    components.year = 1860
    components.month = 1
    components.day = 1
    return Calendar.current.date(from: components) ?? Date()
}()
```

### SystemMenuView.swift
**Line 192**: Fixed days calculation
```swift
// Before:
from: Date(timeIntervalSince1970: 0)
// After:
from: game.gameStartDate
```

**Lines 218-228**: Updated credits
- Fixed Art Canfil year: 1979 → 1982
- Added Michael Lavery credit for Perl version
- Updated iOS version: 2024 → 2025 by Claude Code

---

## Testing

### Day Counter Test
- [x] New game started → Days Elapsed: 0 ✅
- [x] Sail to Shanghai (5 days) → Days Elapsed: 5 ✅
- [x] Continue sailing → Days incrementing correctly ✅
- [x] No negative numbers! ✅

### Credits Display
- [x] Shows Art Canfil (1982) ✅
- [x] Shows Michael Lavery (2020-2025) for Perl version ✅
- [x] Shows Claude Code (2025) for iOS version ✅

---

## Why This Happened

**Likely copied from template code** that calculated "years since" or "days since release" using Unix epoch as reference. For a game set in 1860, this doesn't work!

**Proper Reference Points**:
- ✅ Game start date (1860/01/01) for "Days Elapsed"
- ❌ Unix epoch (1970/01/01) - only useful for modern timestamps

---

## Impact

### Before Fix
```
Statistics Screen:
- Ports Visited: 3/7
- Days Elapsed: -40107  ← WTF?! 😕
```

### After Fix
```
Statistics Screen:
- Ports Visited: 3/7
- Days Elapsed: 18  ← Makes sense! ✅
```

---

## Build Status

```
** BUILD SUCCEEDED **
No errors, no warnings
```

---

## Version

**Part of v1.0.2** - Included with debt system fixes

---

**Status**: ✅ Fixed
**Build**: ✅ Passing
**Credits**: ✅ Properly attributed!

---

*Days now count UP from 0 like they should! The year is 1860, not a time machine to 1970.* ⏰✅
