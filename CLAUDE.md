# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Taipan Cursed** is a Perl-based terminal trading game using Curses::UI. It's a remake of the 1982 Apple II game "Taipan!" set in the 1860s South China Sea. The player manages a merchant trading fleet, buying/selling goods, battling pirates, and building wealth across seven Asian ports.

## Running the Game

```bash
# Run the latest version
./Taipan_2020_v1.1.0.pl

# Or with perl directly
perl Taipan_2020_v1.1.0.pl
```

**Prerequisites:**
- Perl 5 with modules: `Curses::UI`, `JSON`, `List::Util`, `POSIX`
- Terminal must be at least 120x40 characters
- ASCII map files (`ascii_taipan_map*.txt`) must be in same directory

## Development Workflow

**IMPORTANT: Always follow this workflow when making code changes:**

1. Make code changes to current version
2. **Run syntax check:** `perl -c Taipan_2020_vX.X.X.pl`
3. Fix any syntax errors
4. Copy to new version: `cp Taipan_2020_vX.X.X.pl Taipan_2020_vX.X.Y.pl`
5. Test the new version
6. Update CLAUDE.md version history if significant changes

**Never skip the syntax check!** Running `perl -c` catches errors before runtime and saves debugging time.

## Architecture Overview

### Single-File Monolith Design
The entire game is in `Taipan_2020_v1.1.0.pl` (~2,500 lines). This is intentional - it's a self-contained terminal game without external dependencies beyond Perl modules.

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
- `borrow()`, `pay_debt()`: Debt at 10% monthly compound interest (historically accurate!)

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

## Debugging

Debug logging enabled by default:
```perl
our $DEBUG_LOG = 'taipan_debug.log';  # Relative path - creates log in current directory
sub debug_log { ... }
```
Log file is created in the same directory as the script.

## Common Modifications

### Adding a New Menu Action
1. Add item to menu listbox values array (e.g., `draw_menu1()`)
2. Add elsif branch in menu's `onchange` handler to set `$current_action`
3. Add elsif branch in `main_loop()` to handle the action
4. Create the handler function

### Adjusting Game Balance
- **Base prices**: Modify `%goods` hash (line ~118)
- **Price volatility**: Adjust `volatility` values in `%goods`
- **Interest rates**: Modify `calculate_interest_rate()` (line ~2287)
- **Debt interest**: Change multiplier in `advance_date()` (line ~441, currently 0.1 = 10%)
- **Combat difficulty**: Adjust `$ec`, `$ed`, `$s0` constants (lines 146-149)
- **Warehouse risk**: Modify `%port_risk` hash (lines 83-91)

### Adding New Ports
1. Add to `@ports` array (line 67)
2. Add warehouse entry to `%warehouses` (lines 71-79)
3. Add risk level to `%port_risk` (lines 83-91)
4. Create new ASCII map file and add to `@filenames` (line 94)
5. Trends and prices auto-generate for new ports

## Gotchas & Known Issues

1. **Map files must be in script directory** - No path configuration
3. **Terminal size requirement** - Breaks on terminals <120x40
4. **Global state** - Heavy use of package globals makes testing difficult
5. **No input sanitization for port names** - Sailing requires exact case match
6. **Combat globals persist** - Combat state variables aren't reset between battles

## Version History

- **v1.1.1**: Fixed hardcoded debug log path (now relative), added debug logging, improved splash screen flow
- **v1.1.0**: Enhanced splash screen, load game dialog, dynamic ship pricing display
- **v1.0.1**: Previous stable release
- **v1.0.0**: First full release with all core features
- **v0.1.1**: Early alpha version
