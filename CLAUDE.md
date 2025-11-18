# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Taipan Cursed** is a Perl-based terminal trading game using Curses::UI. It's a remake of the 1982 Apple II game "Taipan!" set in the 1860s South China Sea. The player manages a merchant trading fleet, buying/selling goods, battling pirates, and building wealth across seven Asian ports.

## Running the Game

```bash
# Recommended: Use the launch script (handles local::lib)
./launch_taipan.sh

# Or run the latest version directly
./Taipan_2020_v2.1.1.pl

# Or with perl directly
perl Taipan_2020_v2.1.1.pl
```

**Prerequisites:**
- Perl 5 with modules: `Curses::UI`, `JSON`, `List::Util`, `POSIX`
- Terminal must be at least 120x40 characters
- ASCII map files (`ascii_taipan_map*.txt`) must be in same directory

**Note:** If you have Perl modules installed via `local::lib`, use `launch_taipan.sh` which sets up the environment correctly.

## Development Workflow

**IMPORTANT: Always follow this workflow when making code changes:**

1. Make code changes to current version (currently v2.1.1)
2. **Run syntax check:** `perl -c Taipan_2020_vX.X.X.pl`
3. Fix any syntax errors
4. Copy to new version: `cp Taipan_2020_vX.X.X.pl Taipan_2020_vX.X.Y.pl`
5. Test the new version thoroughly (launch_taipan.sh will auto-detect it)
6. Update CLAUDE.md version history if significant changes

**Note:** `launch_taipan.sh` automatically detects and launches the latest version, so no manual updates needed!

**Never skip the syntax check!** Running `perl -c` catches errors before runtime and saves debugging time.

### Testing

The repository includes test scripts for specific features:
- `test_usury.pl`: Tests the 20% maximum usury rate (interest cap)
- `test_multiport_borrowing.pl`: Tests debt limits across multiple ports
- `test_transaction_maximums.pl`: Tests transaction limits and validation
- `test_storm_mechanics.pl`: Tests storm probability, sinking, and blown off course
- `test_robberies.pl`: Tests cash robbery, bodyguard massacre, and Elder Wu mechanics
- `test_li_yuen.pl`: Tests Li Yuen encounter probability and combat mechanics

Run these after making changes to their respective systems.

## Architecture Overview

### Single-File Monolith Design
The entire game is in `Taipan_2020_v2.1.1.pl` (~3,100+ lines). This is intentional - it's a self-contained terminal game without external dependencies beyond Perl modules. Multiple versions exist in the repository for version tracking.

### Core Data Structures

**Player State (`%player` hash):**
- Contains all player data: cash, debt, bank_balance, ships, guns, cargo, port location, date, damage
- Modified by nearly all game functions
- Serialized to JSON for save/load

**Port Prices (`%port_prices` hash):**
- Structure: `{port_name}{good_name} = price`
- Regenerated on load (not saved) using trend system
- Updated by `generate_prices()` with momentum-based evolution

**Warehouses (`%warehouses` hash):**
- Multi-port storage: each of 7 ports has 10,000 capacity
- Structure: `{port_name}{good_name} = quantity`
- Subject to time-based spoilage and risk-based theft

**Price Trends (`%price_trends` hash):**
- Structure: `{port}{good} = {direction => 1/-1, momentum => 0.0-1.0}`
- Drives dynamic pricing with 10% chance of reversal
- Boundaries enforce ±volatility from base price

### UI Layout (Curses::UI)

The terminal is divided into 4 windows:
1. **top_left** (80x27): Known World ASCII map showing current port
2. **top_right** (40x20): Status panel (cash, ships, guns, date, etc.)
3. **bottom_top_left** (80x6): Four menu listboxes (Ship, Trade, Money, System)
4. **bottom_right** (40x20): Ship's Hold (left) + Opium Hot Deals Tracker (right)
5. **bottom_bottom_left** (80x8): Text input prompt and entry field

### Menu System Flow

Four menus accessed via TAB/cursor keys:
- **Ship Menu**: Buy Ships, Sail to Port, Repair Ship, Buy Guns
- **Trade Menu**: Buy Goods, Sell Goods, Store Goods, Retrieve Goods
- **Money Menu**: Bank Balance, Deposit, Withdraw, Borrow, Pay Debt
- **System Menu**: Save Game, Load Game, Retire

**Input Handling Pattern:**
1. User selects menu item → sets `$current_action` variable
2. Prompt appears in `$prompt_label` asking for input
3. User types in `$text_entry` and presses Enter
4. `main_loop()` reads `$current_action` and calls appropriate function

### Key Function Groups

**Initialization & Setup:**
- `initialize_trends()`: Sets up price trend system
- `generate_initial_prices()`: Creates starting prices
- `draw_map()`: Loads and displays ASCII maps with port indicators

**Game Loop:**
- `main_loop()`: Central input handler, dispatches based on `$current_action`
- `clear_splash_screen()`: Shows New Game/Load Game dialog after splash

**Trading & Economy:**
- `buy_good()`, `sell_good()`: Commodity trading with input validation
- `generate_prices()`: Momentum-based price evolution (±5% per cycle)
- `update_hot_deals()`: Finds opium prices >1 std dev from median
- `store_good()`, `retrieve_good()`: Warehouse management
- `check_port_events()`: Time-based warehouse spoilage (60+ days) and theft

**Banking & Finance:**
- `deposit()`, `withdraw()`: Hong Kong/Shanghai bank operations
- `apply_bank_interest()`: Tiered rates (3-5% annual, compounded monthly)
- `borrow()`, `pay_debt()`: Debt with 20% maximum usury rate cap per port
- Multi-port borrowing: Can borrow up to debt limit (e.g., 10k) at each port independently

**Ship Management:**
- `buy_ships()`: Dynamic pricing - base ¥10,000 + ¥1,000 per 2 guns over 20
- `buy_guns()`: ¥500 per gun × number of ships (equips entire fleet)
- `repair_ship()`: Damage repair based on BR formula from original game
- `calculate_seaworthiness()`: Returns damage percentage (100% - damage/ships)

**Combat System:**
- `init_combat()`: Initializes pirate encounter (1-in-9 chance when sailing)
- `combat_loop()`: Handles fight/run/throw decisions
- `fight_run_throw()`: Core combat logic with original Taipan! formulas
  - Escape: `(OK + IK) / (S0 * (ID + 1)) * EC`
  - Damage: `E(SN + 1) / ES * ED * F1` where F1=2 for Li Yuen
  - Booty: `R(TI/4 * 1000 * SN^1.05) + R(1000) + 250`
- `draw_lorcha()`, `sink_lorcha()`: ASCII ship rendering in combat

**Save/Load:**
- `save_game()`: JSON serialization to `saves/FirmName_YYYY-MM-DD.dat`
- `load_game()`: Deserializes player data, regenerates prices, updates all UI

**UI Updates:**
- `update_status()`: Refreshes status panel, calls `update_hold()` and `update_prices()`
- `update_prices()`: Updates price labels in Ship's Hold window
- `update_hold()`: Shows cargo + warehouse contents for current port
- `update_hot_deals()`: Regenerates opium price comparison sidebar

## Important Implementation Details

### Ship Cost Calculation
Ships have dynamic pricing based on player's armament:
```perl
my $base_cost = 10000;
if ($player{guns} > 20) {
    my $guns_over_20 = $player{guns} - 20;
    my $additional_cost = int($guns_over_20 / 2) * 1000;
    $base_cost += $additional_cost;
}
```
**Critical:** The prompt text must calculate this dynamically (lines 1613-1620) to match actual cost.

### UI Refresh After Load
When loading a saved game, you must call:
```perl
update_status();  # Updates status, hold, and prices
draw_map();       # Updates ASCII map with current port
```
Otherwise the UI shows stale data from the previous session.

### Date/Time System
- Date stored as `{year, month, day}` in `%player`
- `advance_date($days)`: Increments date, applies monthly debt interest
- Months are 30 days each for simplicity
- Warehouse spoilage checks use `date_before()` to compare dates

### Combat State Management
Combat uses global variables (`$num_ships`, `$orders`, `$ok`, `$ik`, etc.) that persist between combat rounds. After combat ends, these are NOT reset, which can cause issues if not careful.

### ASCII Map System
Seven map files show different port indicators:
- Map 1: Home port (Hong Kong marked with `@`)
- Maps 2-7: Each highlights a different visited port
- `draw_map()` cycles through maps based on `$player{map}` index
- Map legend in `ascii_taipan_map_legend.txt`

### Robbery & Elder Brother Wu Mechanics
Based on original APPLE II BASIC lines 2501, 1460, 1220, 1330:

**Cash Robbery (Line 2501):**
- Triggers when `cash > ¥25,000` AND 5% chance (1-in-20)
- Steals random amount up to `cash / 1.4` (max 71% of cash)
- Message: "You've been beaten up and robbed"

**Bodyguard Massacre (Line 1460):**
- Triggers when `debt > ¥20,000` AND 20% chance (1-in-5)
- Kills 1-3 bodyguards (random)
- Steals ALL cash
- Message: "Bad joss!! X bodyguards killed by cutthroats"
- Player starts with 5 bodyguards

**Elder Brother Wu Escort (Line 1220):**
- Triggers in Hong Kong when `debt > ¥30,000` AND `bodyguards < 3` (once per game)
- Wu sends 50-150 braves to escort you
- Provides 5 replacement bodyguards
- Sets `wu_escort` flag

**Elder Brother Wu Emergency Loans (Line 1330):**
- Triggers in Hong Kong when `cash < ¥500` AND `debt > ¥10,000`
- Offers loan of ¥500-2,000
- Payback formula: `random(2000) * bad_loan_count + 1500`
- Each loan increases `bad_loan_count` (BL% in original)
- Interest rates increase with each loan (predatory lending)
- Example: Loan #1: 75-200% interest, Loan #3: 150-400% interest

### Li Yuen the Pirate Lord Mechanics
Based on original APPLE II BASIC lines 3110-3230:

**Li Yuen Encounters (Line 3210):**
- Probability: `FN R(4 + 8 * LI)` where LI is tribute flag
- No tribute (LI=0): 25% chance (1-in-4) of Li Yuen encounter
- Paid tribute (LI=1): 8.3% chance (1-in-12) of Li Yuen encounter
- Only triggers during pirate encounters (1-in-9 base chance when sailing)

**Li Yuen Combat (Line 3230):**
- Fleet size: `SN = FN R(SC / 5 + GN) + 5` (larger than normal pirates)
- Damage multiplier: `F1 = 2` (Li Yuen does DOUBLE damage)
- Booty: 2x normal pirate booty if defeated
- Attack guaranteed if no tribute paid
- "Good joss!!" pass through if tribute paid (Line 3225)

**Player State:**
- `li_yuen_tribute`: Flag indicating tribute payment status (0 or 1)
- Li Yuen flag is set when player pays tribute to avoid future attacks
- Tribute reduces encounter probability from 25% to 8.3%
- Tribute provides guaranteed safe passage if encountered

**Implementation Notes:**
- Li Yuen check happens after storm check in `random_event()`
- F1 multiplier must be reset to 1 after Li Yuen combat for normal pirates
- Booty calculation uses F1=2 to double the reward for defeating Li Yuen
- Fleet size averages ~65 ships with SC=400, GN=40 (vs ~25 for normal pirates)

## Debugging

Debug logging enabled by default:
```perl
our $DEBUG_LOG = 'taipan_debug.log';  # Relative path - creates log in current directory
sub debug_log { ... }
```
Log file is created in the same directory as the script.

**Checking logs:**
```bash
tail -f taipan_debug.log  # Watch logs in real-time
grep "ERROR" taipan_debug.log  # Search for errors
```

## Launcher Script

The `launch_taipan.sh` script handles environment setup and **automatically detects the latest version**:
```bash
#!/bin/bash
# Auto-detect and launch the latest version of Taipan

eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
cd ~/taipan_cursed

# Find the latest version by sorting version numbers
LATEST_VERSION=$(ls -1 Taipan_2020_v*.pl 2>/dev/null | \
    grep -v "massive_updates" | \
    sed 's/Taipan_2020_v//' | \
    sed 's/.pl$//' | \
    sort -V | \
    tail -1)

TAIPAN_SCRIPT="Taipan_2020_v${LATEST_VERSION}.pl"
echo "Launching $TAIPAN_SCRIPT..."
perl "$TAIPAN_SCRIPT"
```

**Benefits:**
- **No manual updates needed** - Script automatically finds and launches the newest version
- Uses version sorting (`sort -V`) to correctly handle version numbers (e.g., 1.2.10 > 1.2.9)
- Excludes `Taipan_massive_updates.pl` from version detection
- The script sets up `local::lib` for Perl modules installed in user directory
- Change the `cd` path if the game is installed elsewhere

## Common Modifications

### Adding a New Menu Action
1. Add item to menu listbox values array (e.g., `draw_menu1()`)
2. Add elsif branch in menu's `onchange` handler to set `$current_action`
3. Add elsif branch in `main_loop()` to handle the action
4. Create the handler function

### Adjusting Game Balance
- **Base prices**: Modify `%goods` hash (search for "our %goods")
- **Price volatility**: Adjust `volatility` values in `%goods`
- **Interest rates**: Modify `calculate_interest_rate()` function
- **Usury cap**: Modify the 20% maximum usury rate in borrow logic
- **Debt limits**: Adjust per-port debt limits (currently 10k per port)
- **Combat difficulty**: Adjust `$ec`, `$ed`, `$s0` constants
- **Warehouse risk**: Modify `%port_risk` hash

**Note:** Line numbers may shift between versions. Use `grep` or search functionality to locate specific code sections.

### Adding New Ports
1. Add to `@ports` array (search for "our @ports")
2. Add warehouse entry to `%warehouses` hash
3. Add risk level to `%port_risk` hash
4. Create new ASCII map file and add to `@filenames` array
5. Trends and prices auto-generate for new ports

**Note:** Search for these variables in the code rather than relying on line numbers, as they shift between versions.

## Gotchas & Known Issues

1. **Map files must be in script directory** - No path configuration
3. **Terminal size requirement** - Breaks on terminals <120x40
4. **Global state** - Heavy use of package globals makes testing difficult
5. **No input sanitization for port names** - Sailing requires exact case match
6. **Combat globals persist** - Combat state variables aren't reset between battles

## Version History

- **v2.1.1**: Quality of Life Polish (latest)
  - Real-time seaworthiness display during combat damage (Fight and Run)
  - Real-time status updates after storm damage (partial loss and survival)
  - Smart retirement dialog: one-time offer with `retire_offered` flag
  - "The seas await, Taipan! We sail on!" confirmation when declining retirement
  - Backward compatibility defaults for all new player fields (retire_offered, etc.)
  - Added `$cui->draw(1)` after `update_status()` in combat for immediate visual feedback
- **v2.1.0**: Major UI/UX & Combat Overhaul
  - Added ship and gun costs to Hold window (dynamic pricing display)
  - Implemented enemy attack phase when Run fails in combat (damage + seaworthiness checks)
  - Rebalanced commodity markets: Arms ¥500-2500 (was ~125-375), Silk ¥230-510 (was ~180-420)
  - Fixed combat dialog sequence: Added "Pirates sighted off the port bow!" before combat screen
  - Enhanced update_hold() function with real-time purchase cost calculations
  - Improved tactical depth: Failed escapes now have consequences
  - Better UX: Players always know ship/gun costs before purchasing
- **v1.3.0**: Li Yuen the Pirate Lord
  - Implemented Li Yuen encounters from APPLE II BASIC (lines 3110-3230)
  - Tribute system: 25% encounter rate without tribute, 8.3% with tribute
  - "Good joss!!" safe passage when tribute is paid
  - Larger fleet size: SC/5 + GN + 5 ships (avg ~65 vs ~25 normal pirates)
  - Double damage multiplier (F1=2) and 2x booty for Li Yuen combat
  - Added li_yuen_tribute flag to player state
  - Added comprehensive test harness (test_li_yuen.pl) with 1000 iterations
- **v1.2.9**: Robbery & Elder Brother Wu mechanics
  - Implemented cash robbery (BASIC line 2501): 5% chance when cash > ¥25,000
  - Implemented bodyguard massacre (BASIC line 1460): 20% chance when debt > ¥20,000
  - Added Elder Brother Wu escort system (BASIC line 1220): Wu sends 50-150 braves
  - Added Elder Brother Wu emergency loans (BASIC line 1330): Predatory lending system
  - Added bodyguards, bad_loan_count, and wu_escort to player state
  - Added comprehensive test harness (test_robberies.pl) with 1000 iterations
- **v1.2.8**: Storm mechanics
  - Implemented storm system from original APPLE II BASIC (lines 3310-3340)
  - 10% chance of storm per voyage
  - Ship sinking danger based on damage (partial or total fleet loss)
  - Blown off course to random port (33% of storms)
  - Added test harness (test_storm_mechanics.pl)
- **v1.2.7**: UI polish
  - Fixed Buy Guns prompt overflow by adding newline (prompt was running off screen)
- **v1.2.6**: **CRITICAL BUG FIX**
  - Fixed critical `port_debt` synchronization bug that caused false "debt exceeded" errors
  - When paying debt at one port that exceeds that port's portion, payment now properly distributes to other ports
  - Added safety check to zero all port_debt values when total debt reaches 0
  - Enhanced debug logging for debt payment distribution
- **v1.2.5**: UX improvements for all purchase/payment actions
  - Fixed cursor positioning issue in buy/sell goods (switched to "Enter for max" pattern)
  - Added maximum calculation and display for buying ships
  - Added maximum calculation and display for buying guns
  - Added smart debt payment with auto-withdraw from bank in Hong Kong
  - Unified "Press Enter for maximum" pattern across all transactions
- **v1.2.4**: Previous stable version
- **v1.2.3**: Usury rate implementation and multi-port borrowing
- **v1.2.2**: Transaction maximum improvements
- **v1.2.1**: Enhanced financial system validation
- **v1.2.0**: Major financial system overhaul
- **v1.1.9-v1.1.1**: Various splash screen and UI improvements
- **v1.1.0**: Enhanced splash screen, load game dialog, dynamic ship pricing display
- **v1.0.1**: Previous stable release
- **v1.0.0**: First full release with all core features
- **v0.1.1**: Early alpha version

**Current Active Version:** v2.1.1 (see `launch_taipan.sh` for currently configured version)
