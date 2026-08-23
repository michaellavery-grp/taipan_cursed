# Taipan Cursed v2.2.0 - Animated Splash Edition

A Perl Curses::UI remake of the classic 1982 Apple II game "Taipan!" set in the 1860s South China Sea trade routes.

## What's New in v2.2.0

### 🏴‍☠️ Animated Pirate Ship Splash Screen
- **Fullscreen animated splash** with 60 frames of smooth pirate ship animation
- Converted from Lottie vector graphics to 100x40 character ASCII art
- Runs at 10 fps using Curses::UI timer system
- Press ANY key to start the game

### 📁 Portable Paths
- **Run from anywhere!** The game now finds all its resources relative to the script location
- Map files, saves directory, debug logs, and animation frames automatically located
- No more "file not found" errors when running from different directories

## Installation

### Prerequisites

```bash
# Install Perl modules
cpan Curses::UI JSON List::Util POSIX

# Or if using local::lib:
cpan -l ~/perl5 Curses::UI JSON List::Util POSIX
```

### Download & Run

```bash
# Clone or download the repository
cd /path/to/taipan_cursed

# Run the game from anywhere
perl Taipan_2020_v2.2.0.pl

# Or use the auto-detect launcher (runs latest version):
./launch_taipan.sh
```

## How to Play

### Starting the Game

1. **Animated Splash Screen** - Watch the pirate ship sail across the screen
2. **Press ANY key** to continue
3. **Choose (N)ew Game or (L)oad Game**
4. Enter your firm name
5. Start trading!

### Game Structure

```
Taipan Cursed File Structure:
├── Taipan_2020_v2.2.0.pl          # Main game executable
├── launch_taipan.sh                # Auto-detect launcher
├── ascii_taipan_map1.txt           # ASCII maps (7 files)
├── ascii_taipan_map2.txt
├── ...
├── ascii_ship_animation/           # Animation resources
│   ├── ship_animation.pl           # Animation module
│   └── ascii_frames/               # 60 ASCII art frames
│       ├── taipan_frame00.txt
│       ├── taipan_frame01.txt
│       └── ...
├── saves/                          # Save games (auto-created)
│   └── YourFirm_1860-01-15.dat
└── taipan_debug.log                # Debug log (auto-created)
```

### Navigation

- **TAB** - Move between menus
- **Arrow Keys** - Navigate menu items
- **ENTER** - Select/confirm
- **Type numbers/text** in bottom input field
- **ESC** - Access top menu bar

### Trading Basics

1. **Buy Goods** - Purchase opium, arms, silk, or general goods
2. **Sail to Port** - Enter port name (e.g., "Shanghai")
3. **Sell Goods** - Sell at higher prices
4. **Watch Trends** - Prices evolve with momentum-based trends

### Ship Management

- **Buy Ships** - Increase cargo capacity (60 units each)
  - Base cost: ¥10,000
  - +¥1,000 per 2 guns over 20
- **Buy Guns** - Protection from pirates (¥500 × ships)
- **Repair Damage** - Fix damage from battles and storms

### Banking

- **Deposit** - Store money at Hong Kong/Shanghai banks
- **Withdraw** - Get your money back
- **Borrow** - Take loans from Elder Brother Wu (20% max interest)
- **Pay Debt** - Reduce debt to avoid robbery/cutthroats

### Warehouses

- **Store Goods** - 10,000 capacity per port
- **Retrieve Goods** - Get stored goods
- **Risk** - Goods may spoil or be stolen if left too long

### Combat

- **Fight** - Attack pirates
- **Run** - Try to escape (may take damage if failed)
- **Throw Cargo** - Sacrifice goods to lighten ship and escape

### Goal

Build your trading empire and achieve a net worth of **¥1,000,000** to become a **FUHÁO** (富豪 - Tycoon)!

## Seven Ports

1. **Hong Kong** - British controlled, safest warehouses
2. **Shanghai** - Chaotic, Taiping Rebellion era
3. **Nagasaki** - Japanese controlled
4. **Saigon** - Frontier town, high theft risk
5. **Manila** - Spanish colonial instability
6. **Batavia** - Dutch controlled
7. **Singapore** - British, well organized

## Save/Load Games

- **Save**: System Menu → Save Game
- **Load**: Choose (L)oad at startup or System Menu → Load Game
- Files saved in `saves/` directory as: `FirmName_YYYY-MM-DD.dat`
- JSON format for easy editing/debugging

## Running from Different Locations

The game now automatically finds all its files relative to where the script is located:

```bash
# These all work now:
cd /Users/you/taipan_cursed && perl Taipan_2020_v2.2.0.pl
cd /tmp && perl /Users/you/taipan_cursed/Taipan_2020_v2.2.0.pl
cd ~ && /Users/you/taipan_cursed/launch_taipan.sh
```

All resources (maps, saves, animation) are found automatically!

## Terminal Requirements

- **Minimum size**: 120 columns × 40 rows
- **Color support** recommended
- **UTF-8 encoding** for proper character display

## Features

### Economy
- Dynamic price trends with momentum
- 4 commodities: Opium, Arms, Silk, General Goods
- Multi-port warehouse system
- Banking with tiered interest rates
- Multi-port debt with usury cap

### Combat
- Pirates attack with 1-in-9 chance when sailing
- Li Yuen the Pirate Lord (special encounter)
- Original Apple II combat formulas
- Booty rewards for victories

### Random Events
- **Storms** (10% chance) - Ship damage, sinking, blown off course
- **Cash Robbery** (5% when cash > ¥25,000)
- **Bodyguard Massacre** (20% when debt > ¥20,000)
- **Elder Brother Wu** - Emergency loans, escorts

### Quality of Life
- Real-time seaworthiness display during combat
- Dynamic ship/gun pricing shown in hold
- Smart retirement dialog
- Comprehensive status tracking
- Hot deals tracker for opium prices

## Credits

- **Original Game**: Art Canfil (1982 Apple II BASIC)
- **Original Programming**: Jay Link (jaylink1971@gmail.com)
- **Perl Curses Version**: Michael Lavery (2020-2025)
- **iOS Version**: Claude Code (2025)
- **Animated Splash**: Lottie animation converted to ASCII (2025)

## Technical Details

- **Language**: Perl 5
- **UI Framework**: Curses::UI
- **Save Format**: JSON
- **Animation**: 60-frame ASCII art at 10 fps
- **Path Handling**: File::Spec for cross-platform compatibility

## License

GPLv3 or later

## Changelog

### v2.2.0 (2025-12-01)
- Added fullscreen animated pirate ship splash screen
- Implemented portable path resolution (run from anywhere)
- Removed redundant static splash screen
- All resources now located relative to script directory

### v2.1.2
- Previous stable version

See CLAUDE.md for full version history.

## Troubleshooting

### Maps not loading
- Ensure all `ascii_taipan_map*.txt` files are in the same directory as the script
- Check `taipan_debug.log` for path issues

### Saves not found
- The `saves/` directory is created automatically in the script directory
- Check you have write permissions

### Animation not showing
- Ensure `ascii_ship_animation/` directory exists with `ship_animation.pl` and `ascii_frames/` subdirectory
- Check that all 60 `taipan_frame##.txt` files exist

### Terminal too small
- Resize your terminal to at least 120×40
- Some terminal emulators may need font size adjustment

## Support

For bugs, features, or questions:
- Check `taipan_debug.log` for error messages
- Ensure all prerequisites are installed
- Try running `perl -c Taipan_2020_v2.2.0.pl` to check syntax

---

**Fair winds and following seas, Taipan!** ⚓🏴‍☠️
