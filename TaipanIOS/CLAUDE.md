# CLAUDE.md - TaipanIOS Development Guide

This file provides guidance to Claude Code when working with the iOS Swift version of Taipan Cursed.

## Project Overview

**TaipanIOS** is a native iOS SwiftUI port of the Perl terminal game "Taipan Cursed". It's a faithful recreation of the 1982 Apple II game "Taipan!" set in the 1860s South China Sea. The player manages a merchant trading fleet, buying/selling goods, battling pirates, and building wealth across seven Asian ports.

**Parent Project**: This is a port of the Perl Cursed::UI version located in the parent directory (`../Taipan_2020_v2.1.1.pl`)

## Running the Game

### Requirements
- macOS with Xcode 14.0 or later
- iOS 16.0+ target device or simulator
- Apple Developer account (free tier works for personal device testing)

### Building & Running
```bash
# Open in Xcode
open TaipanCursed.xcodeproj

# Or build from command line
xcodebuild -project TaipanCursed.xcodeproj -scheme TaipanCursed -sdk iphoneos
```

### Installing on iPhone
See **README.md** in this directory for step-by-step user instructions.

## Architecture Overview

### SwiftUI MVVM Design
Unlike the Perl monolith, the iOS version uses SwiftUI's MVVM architecture:

**Model**: `GameModel.swift` (ObservableObject)
- Single source of truth for all game state
- Published properties trigger UI updates automatically
- Contains all game logic (trading, combat, banking, sailing)

**Views**: Separate view files
- `ContentView.swift`: Main game screen layout
- `ShipMenuView.swift`: Ship operations (buy ships, sail, repair, buy guns)
- `TradeMenuView.swift`: Trading operations (buy/sell/store/retrieve goods)
- `MoneyMenuView.swift`: Banking operations (deposit/withdraw/borrow/pay debt)
- `SystemMenuView.swift`: System operations (save/load/retire)
- `CombatView.swift`: Pirate combat interface

### Core Data Structures

**GameModel (ObservableObject)**
```swift
@Published var cash: Int = 20000          // Starting cash
@Published var debt: Int = 0              // Total debt across all ports
@Published var portDebt: [String: Int]    // Per-port debt tracking
@Published var bankBalance: Int = 0       // Hong Kong/Shanghai bank
@Published var ships: Int = 1             // Number of ships in fleet
@Published var guns: Int = 1              // Total guns (equipped across fleet)
@Published var damage: Int = 0            // Ship damage (0-100)
@Published var currentPort: Port          // Current location
@Published var cargo: [String: Int]       // Ship's hold inventory
@Published var warehouses: [String: [String: Int]]  // Multi-port storage
@Published var portPrices: [String: [String: CommodityPrice]]  // Price system
```

**Port Prices System**
```swift
struct CommodityPrice {
    var price: Double      // Current market price
    var trend: Double      // -1 (bearish) or 1 (bullish)
    var momentum: Double   // 0.3 to 0.7 (trend strength)
}

struct Commodity {
    let id: String
    var basePrice: Double
    var volatility: Double  // Price range factor (±volatility from base)
}
```

**Commodities (Matches Perl Original)**
```swift
"opium": Commodity(basePrice: 5000, volatility: 0.8)    // Range: ¥1,000-9,000
"arms": Commodity(basePrice: 1500, volatility: 0.667)   // Range: ¥500-2,500
"silk": Commodity(basePrice: 370, volatility: 0.378)    // Range: ¥230-510
"general": Commodity(basePrice: 50, volatility: 0.3)    // Range: ¥35-65
```

### Price Trend System

**CRITICAL**: The price system must exactly match the Perl original to maintain game balance.

**Algorithm (Lines 198-241 in GameModel.swift)**:
```swift
// 1. Calculate percentage change (max ±5% per update)
let changePercent = momentum * 0.05 * direction  // trend direction × strength
let noise = (Double.random(in: 0...1) - 0.5) * 0.02  // ±1% random noise
let totalChange = changePercent + noise

// 2. Apply to CURRENT price (not base price!)
var newPrice = currentPrice * (1 + totalChange)

// 3. Boundary reversal logic
if newPrice >= maxPrice {
    newPrice = maxPrice
    priceInfo.trend = -1  // Reverse to bearish
    priceInfo.momentum = 0.4 + Double.random(in: 0...0.3)
} else if newPrice <= minPrice {
    newPrice = minPrice
    priceInfo.trend = 1  // Reverse to bullish
    priceInfo.momentum = 0.4 + Double.random(in: 0...0.3)
}

// 4. Random reversal (10% chance)
if Double.random(in: 0...1) < 0.1 {
    priceInfo.trend *= -1
    priceInfo.momentum = 0.3 + Double.random(in: 0...0.4)
}
```

**Why This Matters**:
- Creates realistic "runs and dips" like original game
- Allows strategic trading based on trends
- Prevents wild price swings that break game balance
- Market behavior: 5-15 updates per trend before reversal

### Combat System

Combat matches the original Apple II BASIC formulas exactly:

**Escape Probability** (Line 610):
```swift
let escapeChance = (ok + ik) / (s0 * (id + 1)) * ec
// ok = our ships, ik = their ships sunk, id = their initial ships
// s0 = speed factor, ec = escape constant
```

**Damage Calculation** (Line 650):
```swift
let damageAmount = e * (sn + 1) / es * ed * f1
// e = random factor, sn = remaining ships
// es = escape speed, ed = damage constant
// f1 = 2 for Li Yuen, 1 for normal pirates
```

**Booty Reward** (Line 720):
```swift
let booty = Int(Double.random(in: 0...1) * (ti / 4 * 1000 * pow(sn, 1.05)))
          + Int(Double.random(in: 0...1000)) + 250
// ti = their initial ships, sn = ships sunk
```

### Ship Cost Calculation

Ships have dynamic pricing based on armament (matches Perl line 1613):
```swift
var baseCost = 10000
if guns > 20 {
    let gunsOver20 = guns - 20
    let additionalCost = (gunsOver20 / 2) * 1000
    baseCost += additionalCost
}
```

Examples:
- 0-20 guns: ¥10,000 per ship
- 30 guns: ¥15,000 per ship
- 40 guns: ¥20,000 per ship

## Version History & Release Notes

### v1.0.5 - Li Yuen Tribute System (December 7, 2025)
**Status**: ✅ Complete and tested

#### Features Implemented

**Li Yuen Tribute/Protection System** (GameModel.swift:142-571):
- Complete implementation based on three historical sources:
  1. TRS-80 original (1979) - Sea Goddess donation system
  2. Apple II BASIC (1982) - Li Yuen encounter mechanics
  3. Perl v1.0.0 (2020) - Post-combat confiscation
- Representative approach in Hong Kong (5% chance when cash > ¥20,000)
- Donation to Sea Goddess (Tin Hau temple) - 10-25% of cash
- Pay/refuse tribute dialog with dramatic messaging
- Protection reduces Li Yuen encounter rate: 25% → 8.3%
- Escalating refusal penalty (each refusal increases encounter rate, max 50%)
- Protection decay (5% random chance per voyage)
- Post-combat confiscation if Li Yuen fleet survives:
  - Seizes ALL opium cargo
  - Demands 30-56% of cash
  - "You got off easy, Taipan!" message
- Tribute tracking (payments and refusals count)

**Save System Redesign** (GameModel.swift:927-1055):
- 4 fixed save slots (savegame1-4.json) in App Support directory
- Auto-save to slot 1 after every voyage (prevents crash data loss)
- Slot status display shows firm name and date
- Load game UI shows "Empty" or save info per slot
- Backward compatible with old saves (optional SaveData fields)

**Banking Restriction Fix** (GameModel.swift:326-349):
- Deposit/withdraw functions now have Hong Kong guard clauses
- Function-level enforcement (not just UI hiding)
- Matches 1979 original game mechanics
- "⚠️ Banking services only in Hong Kong" message

**UI Enhancements** (ContentView.swift:99-461):
- `LiYuenTributeDialogView` - Pay/refuse tribute decision
  - Green "Pay Tribute" button with amount display
  - Red "Refuse" button with "Risk Attack" warning
  - Dramatic dark silks representative dialog
  - Z-index 97 (below storm at 98, combat at 100)
- `LiYuenAlertView` - Post-combat confiscation messages
  - Red-tinted overlay for danger
  - Shows opium seized and cash demanded
  - Z-index 98
- Save slot UI in SystemMenuView.swift (lines 67-146):
  - 4 save buttons with slot numbers
  - Slot 1 marked "(Auto-Save)"
  - 4 load buttons with save info or "Empty"
  - Green background for occupied slots, gray for empty

#### Technical Details

**New GameModel Properties**:
```swift
@Published var liYuenProtection: Bool = false  // TR flag - protection status
@Published var liYuenAlert: String?  // Post-combat confiscation message
@Published var liYuenTributeDialog: LiYuenTributeOffer?  // Tribute offer from representative
@Published var liYuenTributesPaid: Int = 0  // Number of tributes paid
@Published var liYuenRefusals: Int = 0  // Number refused (escalates danger)
```

**New Struct**:
```swift
struct LiYuenTributeOffer {
    let amount: Int
    let message: String
}
```

**SaveData Updates**:
```swift
// All optional for backward compatibility
let liYuenProtection: Bool?
let liYuenTributesPaid: Int?
let liYuenRefusals: Int?
```

**Key Functions**:
- `checkForLiYuenRepresentative()` - 5% chance in Hong Kong (lines 512-547)
- `payLiYuenTribute(amount:)` - Grants protection, reduces refusals (lines 549-556)
- `refuseLiYuenTribute()` - Increases refusal count, removes protection (lines 558-563)
- `decayLiYuenProtection()` - 5% random expiry per voyage (lines 565-571)
- `applyLiYuenConfiscation(combat:)` - Post-combat seizure (lines 573-605)
- `saveToSlot(_:)` / `loadFromSlot(_:)` - 4-slot save system (lines 927-1055)
- `autoSave()` - Called after every sailTo() (line 501)

**Escalating Encounter Rate Algorithm**:
```swift
let baseChance = 4 + (liYuenProtection ? 8 : 0)  // 25% or 8.3%
let refusalPenalty = max(0, liYuenRefusals)
let adjustedChance = max(2, baseChance - refusalPenalty)  // Max 50%
```
- No protection, no refusals: 1-in-4 (25%)
- With protection: 1-in-12 (8.3%)
- 1 refusal: 1-in-3 (33%)
- 2 refusals: 1-in-2 (50%) - capped here

**Files Modified**:
- `GameModel.swift`: Li Yuen system + 4-slot saves + banking fix
- `ContentView.swift`: Tribute dialog UI + alert overlay
- `SystemMenuView.swift`: Save/load slot UI
- `LI_YUEN_COMPLETE_IMPLEMENTATION.md`: Full documentation
- `COMPLETE_v1.0.4_CHANGES.md`: Change summary
- `IMPLEMENTATION_PLAN_v1.0.4.md`: Planning docs

#### Research Sources
- **taipan_game_book.txt** (Archive.org CC0) - Lines 671-682, 9168-9213, 8363-8368
- **BASIC.txt** (1982 Apple II) - Lines 3110-3230 (Li Yuen encounters)
- **Taipan_2020_v1.0.0.pl** - Lines 1325-1354 (post-combat confiscation)
- Web searches for player strategy guides and mechanics

#### Testing Checklist v1.0.5

- [x] Tribute offer appears in Hong Kong (5% chance, cash > ¥20k)
- [x] Pay tribute grants protection, reduces refusal count
- [x] Refuse tribute warns of danger, increases refusal count
- [x] Protection provides safe passage (8.3% encounter rate)
- [x] No protection = attack (25% encounter, escalates with refusals)
- [x] Refusal count increases encounter rate (max 50%)
- [x] Post-combat confiscation if Li Yuen fleet survives
- [x] Protection decays randomly (5% per voyage)
- [x] Save/load preserves all Li Yuen data
- [x] Auto-save after every sail works correctly
- [x] 4-slot save system functional
- [x] Backward compatibility with old saves
- [x] Banking restricted to Hong Kong (function-level guards)

### v1.0.4 - Save System Overhaul
**Status**: ✅ Merged into v1.0.5

- Development version for save system work
- All features rolled into v1.0.5 release

### v1.0.3 - Storm System & Combat Rebalance (December 6, 2025)
**Status**: ✅ Complete and tested

#### Features Implemented

**Storm System** (GameModel.swift:488-568):
- 10% chance per voyage (matches Perl v1.2.8 lines 3310-3340)
- Ship damage reduces seaworthiness (0-100% scale)
- Sinking risk starts at 80% damage
  - Calculated sink chance: `(shipDamage - 0.8) / 0.2`
  - Can lose 1-N ships (partial loss) or entire fleet (game over)
- Storm damage: 10-30% per storm encounter
- Cargo jettison if ship capacity reduced below current cargo
- 33% chance of blown off course to random port
- Storm alert UI overlay (ContentView.swift:310-342)
- Published `stormAlert` property for UI binding

**Combat Scaling Fix** (GameModel.swift:572-581):
- **Issue**: Fixed pirate count (5-20) didn't scale with player strength
- **Original Formula**: `SN = FN R(SC / 10 + GN) + 1` (Perl line 1948)
  - SC = ship capacity (ships × 60)
  - GN = total guns
- **Implementation**:
  ```swift
  let holdCapacity = ships * 60
  let maxPirates = (holdCapacity / 10) + guns
  let pirateFleet = Int.random(in: 1...max(1, maxPirates)) + 1
  ```
- **Impact**:
  - 1 ship + 1 gun = 1-8 pirates (was 5-20)
  - 5 ships + 40 guns = 1-71 pirates (was 5-20)
  - 10 ships + 100 guns = 1-171 pirates (was 5-20)
- Combat difficulty now properly scales throughout game

**Banking Restriction** (MoneyMenuView.swift:86-135):
- Deposit/Withdraw buttons only shown in Hong Kong
- Matches Perl original behavior
- Borrow/Repay remain available at all ports
- Informational message shown when not in Hong Kong:
  > "💼 Banking services only available in Hong Kong"

#### Technical Details

**New GameModel Properties**:
```swift
@Published var stormAlert: String?  // Storm message to display in UI
```

**Storm System Algorithm**:
1. 10% random check in `sailTo()` function
2. Calculate storm damage (10-30% random)
3. Apply damage to `shipDamage` property
4. Check sinking risk if damage >= 80%
5. Calculate ships lost (partial or total)
6. Adjust cargo if capacity reduced
7. 33% chance determine blown off course
8. Set `stormAlert` message for UI display
9. Return actual destination (original or random port)

**UI Integration**:
- `StormAlertView` struct in ContentView.swift
- ZStack overlay with z-index 99 (below combat at 100)
- Black background with blue-tinted message box
- "Continue" button dismisses alert (sets `stormAlert = nil`)
- Transition opacity animation

**Files Modified**:
- `GameModel.swift`: Added storm system, fixed combat scaling
- `MoneyMenuView.swift`: Hong Kong banking restriction
- `ContentView.swift`: Storm alert overlay UI
- `CLAUDE.md`: This documentation
- `README.md`: User-facing feature documentation

#### Testing Checklist v1.0.3

- [x] Storm encounters occur ~10% of voyages
- [x] Storm damage reduces seaworthiness display
- [x] High damage (80%+) triggers sinking risk
- [x] Ship loss adjusts cargo capacity correctly
- [x] Blown off course to random port (33% of storms)
- [x] Storm alert UI displays and dismisses properly
- [x] Pirates scale with 1 ship: 1-8 enemies
- [x] Pirates scale with 5 ships + 40 guns: ~50-70 enemies
- [x] Pirates scale with 10 ships + 100 guns: ~100-170 enemies
- [x] Deposit/Withdraw only visible in Hong Kong
- [x] Borrow/Repay visible at all ports
- [x] Save/load preserves all new features

### v1.0.2 - Debt System Fixes (November 23, 2025)
**Status**: ✅ Complete

#### Bug Fixes
- Fixed per-port debt synchronization issues
- Enhanced debt payment distribution across ports
- Added safety checks for zero debt state

### v1.0.0 - Initial iOS Port (November 20, 2025)
**Status**: ✅ Complete and tested

#### Features Implemented
- Full SwiftUI interface with native iOS controls
- All seven ports (Hong Kong, Shanghai, Manila, Bangkok, Singapore, Rangoon, Saigon)
- Complete trading system (buy/sell/store/retrieve)
- Banking system with tiered interest rates
- Multi-port debt system with 20% usury cap
- Dynamic ship pricing based on armament
- Per-port warehouse system (10,000 capacity each)
- Combat system with original formulas
- Save/load game functionality (JSON)
- Retirement system with rank calculation

#### Critical Bugs Fixed

**Bug #1: Starting Guns Count (Fixed Nov 20, 2025)**
- **Issue**: Player started with 0 guns instead of 1
- **Symptom**: Started game, bought 19 guns, display showed 19 total instead of 20
- **Root Cause**: GameModel.swift line 104 had `guns: Int = 0`
- **Fix**: Changed to `guns: Int = 1` to match Perl original
- **Impact**: Players now have minimal defense from start
- **Files Modified**: GameModel.swift:104
- **Documentation**: BUG_FIX_GUNS.md

**Bug #2: Wild Price Volatility (Fixed Nov 20, 2025)**
- **Issue**: Prices jumping ±50-100% per update instead of smooth trends
- **Symptom**: "Price of opium and other goods are changing too rapidly"
- **Root Causes**:
  1. Calculated from basePrice instead of currentPrice
  2. Used 30% trend + 50% random = ±64% swings (vs ±5% correct)
  3. Momentum decayed toward 0.5, killing trends
  4. No boundary reversal logic
- **Fix**: Complete rewrite of updatePrices() function:
  - Percentage-based: `newPrice = currentPrice * (1 + totalChange)`
  - Reduced to max 5% change per update
  - Removed momentum decay (trends persist)
  - Added boundary reversal at min/max
  - 10% random reversal chance
- **Impact**: Markets now show realistic runs, dips, spikes, and reversals
- **Files Modified**: GameModel.swift:198-241 (updatePrices), 170-196 (generateInitialPrices)
- **Test Files**: test_price_trends.swift
- **Documentation**: PRICE_TREND_FIX.md

**Bug #3: Incorrect Commodity Price Ranges (Fixed Nov 20, 2025)**
- **Issue**: Arms and general prices too low compared to Perl original
- **Symptom**: "The arms and general in particular are very low comparatively"
- **Root Cause**: Wrong base prices in commodity initialization
  - Arms: ¥50 instead of ¥1500 (30x too low!)
  - Silk: ¥500 instead of ¥370 (1.35x too high)
  - General: ¥10 instead of ¥50 (5x too low!)
- **Fix**: Updated all commodity base prices and volatilities:
  ```swift
  "opium": Commodity(basePrice: 5000, volatility: 0.8)    // ✅ Was correct
  "arms": Commodity(basePrice: 1500, volatility: 0.667)   // Fixed: was 50
  "silk": Commodity(basePrice: 370, volatility: 0.378)    // Fixed: was 500
  "general": Commodity(basePrice: 50, volatility: 0.3)    // Fixed: was 10
  ```
- **Impact**: Trading economics now match original game
- **Files Modified**: GameModel.swift:146-153
- **Test Files**: test_commodity_ranges.swift
- **Documentation**: Included in PRICE_TREND_FIX.md

#### Known Differences from Perl Version

**Intentional Changes**:
1. **No ASCII Map**: iOS uses native UI instead of Curses ASCII art
2. **Touch Controls**: Buttons/pickers instead of keyboard menu navigation
3. **No Terminal Size Requirement**: Adapts to screen size
4. **SwiftUI Animations**: Smooth transitions vs. terminal redraws

**Not Yet Implemented**:
1. **Li Yuen the Pirate Lord**: Special pirate encounter system (Perl v1.3.0)
2. **Robberies & Cutthroats**: Cash robbery and bodyguard massacre (Perl v1.2.9)
3. **Elder Brother Wu**: Emergency loans and escort system (Perl v1.2.9)
4. ~~**Storm System**: Ship sinking and blown off course (Perl v1.2.8)~~ ✅ DONE in v1.0.3!
5. **Bodyguards**: Not yet in player state
6. **Time-based Events**: Warehouse spoilage after 60 days
7. **Bank Interest**: Not yet calculated on deposits

## Testing

### Test Files Included
- `test_price_trends.swift`: Validates smooth trending behavior over 50 updates
- `test_port_prices.swift`: Verifies per-port pricing independence
- `test_commodity_ranges.swift`: Confirms price ranges match Perl values

### Running Tests
```bash
# Price trend test (shows 50 updates with trend analysis)
swift test_price_trends.swift

# Commodity range verification
swift test_commodity_ranges.swift

# Port price independence test
swift test_port_prices.swift
```

### Manual Testing Checklist
- [ ] Start new game, verify 1 gun and ¥20,000 cash
- [ ] Buy 19 guns, verify 20 total guns shown
- [ ] Sail between ports 10 times, verify prices trend smoothly (1-5% changes)
- [ ] Check Arms prices range ¥500-2,500 (not ¥25-75)
- [ ] Check Silk prices range ¥230-510 (not ¥300-700)
- [ ] Check General prices range ¥35-65 (not ¥7-13)
- [ ] Verify multi-port debt system (borrow at each port independently)
- [ ] Test combat escape/fight/throw mechanics
- [ ] Save and load game, verify state persists
- [ ] Test retirement with various wealth levels

## Development Workflow

**IMPORTANT: Always follow this workflow when making code changes:**

1. Make changes to source files in `TaipanCursed/`
2. Build in Xcode: Cmd+B (or Product → Build)
3. Fix any Swift compiler errors
4. Test on simulator or device
5. Run relevant test scripts if modifying game logic
6. Update this CLAUDE.md with changes
7. Commit to git with descriptive message

### Common Build Issues

**"Cannot find type 'Port' in scope"**
- Ensure `GameModel.swift` is in the Xcode project target
- Check that `Port` enum is defined before usage

**"@Published var must be used within ObservableObject"**
- Ensure `GameModel` conforms to `ObservableObject`
- Add `import Combine` at top of file

**"No such module 'SwiftUI'"**
- Verify deployment target is iOS 16.0+
- Check Xcode version is 14.0 or later

## File Structure

```
TaipanIOS/
├── CLAUDE.md                          # This file - development guide
├── README.md                          # User installation instructions
├── TaipanCursed.xcodeproj/           # Xcode project file
├── TaipanCursed/                     # Source code
│   ├── TaipanCursedApp.swift         # App entry point
│   ├── GameModel.swift               # Core game logic (ObservableObject)
│   ├── ContentView.swift             # Main game screen
│   ├── ShipMenuView.swift            # Ship operations UI
│   ├── TradeMenuView.swift           # Trading UI
│   ├── MoneyMenuView.swift           # Banking UI
│   ├── SystemMenuView.swift          # Save/load/retire UI
│   ├── CombatView.swift              # Combat interface
│   └── Assets.xcassets/              # App icons and images
├── test_price_trends.swift           # Price trend validation
├── test_commodity_ranges.swift       # Commodity range verification
├── test_port_prices.swift            # Port price independence test
└── Documentation/                    # Bug reports and fix documentation
    ├── BUG_FIX_GUNS.md
    ├── PRICE_TREND_FIX.md
    ├── BUG_REPORT_COMBAT.md
    ├── BUG_REPORT_PRICING.md
    ├── COMBAT_SYSTEM_IMPLEMENTATION.md
    ├── PER_PORT_PRICING_FIX.md
    └── (other .md files)
```

## Common Modifications

### Adding a New Commodity
1. Add to `commodities` dictionary in GameModel.swift (around line 146)
2. Define base price and volatility (check Perl original for values)
3. Add to cargo dictionary initialization
4. Add UI elements in TradeMenuView.swift

### Adjusting Game Balance
- **Base prices**: Modify `commodities` dictionary in GameModel.swift
- **Price volatility**: Adjust `volatility` values (controls ±range)
- **Price change rate**: Modify `0.05` multiplier in updatePrices() (currently max 5%)
- **Interest rates**: Modify calculateInterestRate() function
- **Usury cap**: Modify the 20% maximum in borrow() function
- **Combat difficulty**: Adjust `ec`, `ed`, `s0` constants in combat functions
- **Starting cash**: Change `cash: Int = 20000` in GameModel

### Adding Storm System (Future Enhancement)
Reference Perl v1.2.8 (lines 3310-3340):
- 10% chance per voyage
- Ship sinking based on damage percentage
- 33% chance blown off course to random port
- See `test_storm_mechanics.pl` in parent directory

### ~~Adding Li Yuen~~ ✅ IMPLEMENTED in v1.0.5!
Complete tribute/protection system implemented with:
- Sea Goddess donation system (TRS-80 original)
- Representative approach in Hong Kong
- Pay/refuse tribute dialog
- Protection: 25% → 8.3% encounter reduction
- Escalating refusals (up to 50% encounter rate)
- Protection decay (5% per voyage)
- Post-combat confiscation mechanics
- See `LI_YUEN_COMPLETE_IMPLEMENTATION.md` for details

## Gotchas & Known Issues

1. **SwiftUI State Management**: Always use `@Published` for properties that affect UI
2. **Struct Mutation**: Swift structs are value types - must reassign after mutation
3. **Dictionary Updates**: Can't modify nested dictionaries directly, must extract/modify/reassign
4. **Floating Point Math**: Use `Double` for prices, convert to `Int` for display only
5. **Random Number Generation**: `Double.random(in:)` differs from Perl's `rand()` - verified equivalent
6. **No Global State**: Unlike Perl's package globals, must pass GameModel to all views

## Parity with Perl Original

### ✅ Features Matching Perl v2.2.2
- Commodity base prices and volatilities
- Price trend system (±5% changes, momentum, reversals)
- Multi-port debt with 20% usury cap
- Dynamic ship pricing based on armament
- Combat formulas (escape, damage, booty) ✅ FIXED v1.0.3: Now scales with fleet!
- Banking operations (deposit/withdraw in Hong Kong only) ✅ FIXED v1.0.3
- Warehouse system (10,000 capacity per port)
- Save/load game state (✅ ENHANCED v1.0.5: 4 slots + auto-save)
- Retirement ranking system
- **Storm system** (10% chance, sinking, blown off course) ✅ NEW in v1.0.3!
- **Li Yuen tribute system** (Sea Goddess donation, protection, refusals) ✅ NEW in v1.0.5!

### 🚀 Features EXCEEDING Perl Original
- **Escalating refusals**: iOS tracks refusal count and increases Li Yuen encounter rate (Perl doesn't)
- **Post-combat confiscation**: iOS implements Perl v1.0.0 mechanics (not in v2.2.2)
- **Auto-save**: iOS auto-saves after every voyage (Perl requires manual save)
- **4-slot save system**: iOS has fixed slots with status display (Perl uses date-stamped files)

### ⏳ Features Not Yet Implemented (from Perl v1.2.9-v2.1.1)
- Cash robberies (5% chance when cash > ¥25,000)
- Bodyguard massacre (20% chance when debt > ¥20,000)
- Elder Brother Wu (escort and emergency loans)
- Time-based warehouse spoilage (60+ days)
- Bank interest accrual (3-5% annual, compounded monthly)
- Date/time system (game time tracked but not used for events yet)

### 🎯 Next Priority Features
1. **Robberies & Bodyguards**: Cash robbery and bodyguard massacre events (Perl v1.2.9)
2. **Elder Brother Wu**: Emergency loans and escort system (Perl v1.2.9)
3. **Bank Interest**: Apply 3-5% annual interest monthly
4. **Date/Time System**: Use game time for bank interest and warehouse events

## Performance Notes

- SwiftUI automatically optimizes rendering
- Price updates only happen on sailing (not every frame)
- Save/load uses JSON encoding (fast on iOS)
- Combat calculations are lightweight (original 1982 formulas)
- No known performance issues on iOS 16+ devices

## Debugging

Enable debug output in Xcode:
- Product → Scheme → Edit Scheme → Run → Arguments
- Add environment variable: `DEBUG_MODE = 1`

Or add print statements:
```swift
print("DEBUG: Price update - \(commodityName) from ¥\(Int(oldPrice)) to ¥\(Int(newPrice))")
```

View console: Xcode → View → Debug Area → Show Debug Area (Cmd+Shift+Y)

## Credits

- **Original Game**: Art Canfil (1982 Apple II BASIC)
- **Perl Version**: Michael Lavery (2020-2025)
- **iOS Port**: Claude Code AI (November 2025)
- **Bug Reports & Testing**: Michael Lavery

## License

Same as parent Perl project - check parent directory for LICENSE file.

---

**Last Updated**: December 6, 2025
**iOS Version**: 1.0.3
**Perl Reference Version**: v2.2.1
**Min iOS**: 16.0
**Xcode**: 14.0+
