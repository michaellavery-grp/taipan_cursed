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
4. **Storm System**: Ship sinking and blown off course (Perl v1.2.8)
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

### Adding Li Yuen (Future Enhancement)
Reference Perl v1.3.0 (lines 3110-3230):
- Special pirate lord encounter
- Tribute system (25% → 8.3% encounter reduction)
- Double damage multiplier (F1=2)
- Larger fleet size
- See `test_li_yuen.pl` in parent directory

## Gotchas & Known Issues

1. **SwiftUI State Management**: Always use `@Published` for properties that affect UI
2. **Struct Mutation**: Swift structs are value types - must reassign after mutation
3. **Dictionary Updates**: Can't modify nested dictionaries directly, must extract/modify/reassign
4. **Floating Point Math**: Use `Double` for prices, convert to `Int` for display only
5. **Random Number Generation**: `Double.random(in:)` differs from Perl's `rand()` - verified equivalent
6. **No Global State**: Unlike Perl's package globals, must pass GameModel to all views

## Parity with Perl Original

### ✅ Features Matching Perl v2.1.1
- Commodity base prices and volatilities
- Price trend system (±5% changes, momentum, reversals)
- Multi-port debt with 20% usury cap
- Dynamic ship pricing based on armament
- Combat formulas (escape, damage, booty)
- Banking operations (deposit/withdraw)
- Warehouse system (10,000 capacity per port)
- Save/load game state
- Retirement ranking system

### ⏳ Features Not Yet Implemented (from Perl v1.2.8-v2.1.1)
- Storm system (10% chance, sinking, blown off course)
- Li Yuen pirate lord encounters
- Cash robberies (5% chance when cash > ¥25,000)
- Bodyguard massacre (20% chance when debt > ¥20,000)
- Elder Brother Wu (escort and emergency loans)
- Time-based warehouse spoilage (60+ days)
- Bank interest accrual (3-5% annual, compounded monthly)
- Date/time system (currently not tracking game time)

### 🎯 Next Priority Features
1. **Date/Time System**: Track game time for bank interest and warehouse events
2. **Bank Interest**: Apply 3-5% annual interest monthly
3. **Storm System**: 10% voyage chance, damage-based sinking
4. **Li Yuen**: Special pirate encounter with tribute system

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

**Last Updated**: November 20, 2025
**iOS Version**: 1.0.0
**Perl Reference Version**: v2.1.1
**Min iOS**: 16.0
**Xcode**: 14.0+
