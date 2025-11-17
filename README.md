# 🚢 Taipan Cursed ⚓
### *Sailing the South China Seas with the Dutch East India Company*

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Perl](https://img.shields.io/badge/Perl-5-purple.svg)](https://www.perl.org/)
[![Curses::UI](https://img.shields.io/badge/Curses%3A%3AUI-Terminal-green.svg)](https://metacpan.org/pod/Curses::UI)
[![Version](https://img.shields.io/badge/version-1.2.7-brightgreen.svg)](https://github.com/michaellavery-grp/taipan_cursed)

> *"Taipan Cursed, sailing as the Dutch East India Company, preserves its legacy with JSON ledgers and zen koans, crafted with Grok's celestial guidance from xAI."*

**Latest Release: v1.2.7** - Now with unified "Press Enter for max" UX, smart bank-aware debt payment, and critical bug fixes!

## 🌊 What is Taipan Cursed?

**Taipan Cursed** is a loving, massively enhanced Perl remake of the legendary 1982 Apple II trading game *Taipan!* by Art Canfil. This isn't just a port—it's a complete reimagining that combines the addictive trading gameplay of the original with modern features that would make even the Dutch East India Company jealous.

Set in the treacherous waters of 1860s East Asia, you'll command a merchant fleet, battle pirates, manipulate markets, and build a trading empire across seven ports from Hong Kong to Batavia. With its terminal-based `Curses::UI` interface, ASCII art maps, and sophisticated economic simulation, Taipan Cursed delivers authentic retro gaming with depth that modern gamers will appreciate.

## 🎬 See It In Action

[![asciicast](https://asciinema.org/a/p3YKBEUuIeAwF23v3qWioQAUs.svg)](https://asciinema.org/a/p3YKBEUuIeAwF23v3qWioQAUs)

*Click to watch the interactive terminal demo on asciinema.org*

## 🆕 What's New in v1.2.7?

**Recent Major Improvements:**
- ✨ **Unified UX Pattern** (v1.2.5): All buying/selling actions now use "Press Enter for max" - no more cursor issues or mental math!
- 🔧 **Critical Bug Fix** (v1.2.6): Fixed port_debt synchronization bug that caused false "debt exceeded" errors
- 🎨 **UI Polish** (v1.2.7): Buy Guns prompt now fits on screen with proper line breaks
- 💰 **Smart Debt Payment**: Auto-withdraws from bank when in Hong Kong - pay maximum with one keystroke
- 🚀 **Auto-Detecting Launcher**: `launch_taipan.sh` finds and runs the latest version automatically
- 📊 **Enhanced Logging**: Better debug output for troubleshooting financial operations

**For the Technical Crowd:**
- Proper semantic versioning with `sort -V` in launcher
- Multi-port debt distribution algorithm prevents desync
- Empty input handlers with smart defaults throughout
- Location-aware financial operations (Hong Kong bank integration)

## ⚡ Why Download This Now?

### For Retro Gamers:
- **Pure Nostalgia**: Experience the original Taipan! formula that Steve Wozniak called "my favorite game!"
- **Terminal Authentic**: Real `ncurses` interface that feels like you're on a VT-100 in 1982
- **ASCII Art Beauty**: Hand-crafted maps of the South China Sea with dynamic port indicators
- **Classic Combat**: Battle pirate fleets with the original risk-vs-reward mechanics

### For Coders & Grey-Haired Linux Heads:
- **2,900+ Lines of Production Perl**: Well-commented, battle-tested code demonstrating advanced Curses::UI techniques
- **Complex Systems**: Study real-world game systems including:
  - Dynamic price generation with trends and momentum
  - Multi-port warehouse management with historical risk models
  - Compound interest banking (3-5% based on balance tiers)
  - Sophisticated combat AI with flee mechanics
  - Time-based event system with spoilage and theft
  - JSON save/load with ledger-style persistence
  - Multi-port debt tracking with automatic distribution on payment
- **Perfect Learning Project**: Graduate from "Hello World" to full terminal UIs
- **Smart Auto-Launcher**: Version-agnostic launcher script using `sort -V` for proper semantic versioning
- **Extensible Architecture**: Easy to add new ports, goods, events, or mechanics
- **Production Quality**: Syntax-checked, debugged, and iteratively improved through actual gameplay

### For Both:
- **Rich Gameplay**: Hundreds of hours of addictive trading action
- **Historical Accuracy**: Port risk levels based on actual 1860s conditions
- **Strategic Depth**: Balance debt (10% monthly!), warehouse management, fleet expansion
- **Modern Save System**: JSON-based saves with firm name and date tracking
- **Multiple Maps**: Dynamic ASCII maps change as you visit different ports

## 🎮 Core Features

### 💰 Advanced Trading System
- **Four Commodities**: Opium, Arms, Silk, and General Cargo
- **Dynamic Pricing**: Prices evolve based on trends, momentum, and volatility
- **Hot Deals Tracker**: Real-time opium price comparison across all seven ports
- **Market Intelligence**: See highest and lowest prices at a glance

### 🏴‍☠️ Pirate Combat
- **Random Encounters**: 1-in-9 chance of pirate attack while sailing
- **ASCII Naval Battles**: Lorcha-class warships rendered in beautiful ASCII
- **Strategic Choices**: Fight, Run, or Throw Cargo to escape
- **Booty System**: Defeat pirates to earn bonus cash based on fleet size and game time
- **Damage Model**: Ships take damage in combat; repair costs scale with time

### 🏦 Banking & Finance
- **Hong Kong & Shanghai Banking Corporation**: Period-accurate banking institution
- **Tiered Interest Rates**: 3-5% annual based on deposit size
- **Compound Interest**: Earn monthly on your savings
- **Debt System**: Borrow at 10% monthly interest (historically accurate!)
- **Brother Wu Warnings**: Get alerts when debt spirals out of control

### 🏭 Multi-Port Warehouses
- **7 Warehouses**: 10,000 unit capacity in each port
- **Historical Risk Model**: Each port has different theft/spoilage rates:
  - Hong Kong: 5% (British controlled, safest)
  - Shanghai: 15% (Taiping Rebellion chaos)
  - Nagasaki: 8% (Japanese stability)
  - Saigon: 20% (Frontier risks)
  - Manila: 12% (Spanish colonial instability)
  - Batavia: 10% (Dutch controlled)
  - Singapore: 6% (British organization)
- **Time-Based Spoilage**: Leave goods unattended for 60+ days and watch them disappear
- **Smart Management**: Store high-value goods in safer ports

### 🚢 Fleet Management
- **Buy Ships**: Expand your cargo capacity (60 units per ship)
- **Arm Your Fleet**: Purchase guns for all ships ($500 per gun per ship)
- **Seaworthiness System**: Track damage percentage and repair costs
- **Dynamic Pricing**: Ship costs increase as you become more powerful

### 📊 Sophisticated Game Mechanics
- **Date System**: Track years, months, and days (starting 1860)
- **Travel Times**: Random 5-15 day voyages between ports
- **Monthly Events**: Debt interest compounds, time advances realistically
- **Random Encounters**: Robberies when carrying over ¥25,000 cash
- **Victory Conditions**: Reach ¥1,000,000 net worth for millionaire status!

### 💾 Modern Save System
- **JSON Persistence**: All game data saved in human-readable format
- **Automatic Naming**: Saves named as `FirmName_YYYY-MM-DD.dat`
- **Overwrite Protection**: Confirms before overwriting existing ledgers
- **Resume Anytime**: Pick up exactly where you left off

## 🗺️ The Known World

Navigate seven historically significant trading ports of the 1860s South China Sea:

1. **Hong Kong** 🏠 - Your home port and banking center
2. **Shanghai** - Chaotic market during the Taiping Rebellion era
3. **Nagasaki** - Japanese gateway with stable prices
4. **Saigon** - Frontier town with high risks and rewards
5. **Manila** - Spanish colonial trade hub
6. **Batavia** (Jakarta) - Dutch East India Company headquarters
7. **Singapore** - British crown jewel of the Straits

Each port features unique ASCII map views that update dynamically to show:
- `@` - You are here (at home)
- `Q` - Hong Kong home port
- `*` - Ports with goods in your warehouse
- `o` - Empty ports

## 🎯 Victory Ranks

Retire anytime and receive a rank based on your performance:

- **Ma Tsu** (50,000+ points) - Living legend of the high seas!
- **Master Taipan** (8,000+ points) - Your name echoes through trading houses
- **Taipan** (1,000+ points) - Respected merchant prince
- **Compradore** (500+ points) - Successful trader
- **Galley Hand** (<500 points) - Perhaps find another career...

**Millionaire Status**: Achieve ¥1,000,000 net worth and receive recognition from the Emperor himself!

## 🛠️ Technical Deep Dive

### Architecture Highlights

```perl
# Advanced price generation with trends
sub generate_prices {
    # Momentum-based price evolution (0.3-0.7 momentum range)
    # Direction tracking (bullish/bearish)
    # 10% chance of trend reversal
    # Bounded by ±volatility from base price
}

# Multi-port warehouse system with risk models
%port_risk = (
    'Hong Kong'  => 0.05,  # Historical British control
    'Shanghai'   => 0.15,  # Taiping Rebellion era chaos
    # ... based on actual 1860s conditions
);

# Combat system with original Taipan! formulas
sub fight_run_throw {
    # Escape probability: (OK + IK) / (S0 * (ID + 1)) * EC
    # Damage calculation with F1 multiplier for Li Yuen
    # Booty formula: R(TI/4 * 1000 * SN^1.05) + R(1000) + 250
}
```

### Code Quality Features
- **Extensive Comments**: Nearly every function documented with original BASIC line references
- **Global State Management**: Clean separation of concerns
- **Error Handling**: Input validation and user-friendly error messages
- **Debug Logging**: Built-in debug system for troubleshooting
- **Modular Design**: Easy to extend with new features

## 🚀 Installation

### Prerequisites

```bash
# Perl 5 (usually pre-installed on Unix systems)
perl --version

# Required Perl modules (install via cpan or your package manager)
cpan Curses::UI JSON List::Util POSIX

# Or on Debian/Ubuntu:
# sudo apt-get install libcurses-ui-perl libjson-perl

# For local::lib users (recommended for user-space installs):
cpan local::lib
```

### Quick Start (Smart Launcher Method - Recommended)

```bash
# Clone the repository
git clone https://github.com/michaellavery-grp/taipan_cursed.git
cd taipan_cursed

# Switch to the latest release branch
git checkout Taipan_v1.0_alpha

# Make launcher executable
chmod +x launch_taipan.sh

# Launch the game (auto-detects latest version)
./launch_taipan.sh
```

**The smart launcher automatically:**
- Finds the latest version using semantic versioning
- Sets up `local::lib` if you use it
- Runs the newest `.pl` file without manual updates

### Manual Launch (Advanced Users)

```bash
# Make the latest version executable
chmod +x Taipan_2020_v1.2.7.pl

# Run directly
./Taipan_2020_v1.2.7.pl

# Or with perl
perl Taipan_2020_v1.2.7.pl
```

### Verify Installation

```bash
# Check syntax (recommended before first run)
perl -c Taipan_2020_v1.2.7.pl

# List available versions
ls -1 Taipan_2020_v*.pl | sort -V

# Check for ASCII maps (required)
ls ascii_taipan_map*.txt
```

### First Run

1. **Name Your Firm**: Choose a name that will echo through history
2. **Starting Capital**: Begin with ¥500 and 1 ship
3. **Learn the Controls**: Tab through menus (Ship, Trade, Money, System)
4. **Check Prices**: Yellow hot deals tracker shows opium opportunities
5. **Make Your First Trade**: Buy low, sail to high-price ports, sell high
6. **Build Your Empire**: Expand ships, guns, and warehouses

## 🎮 Gameplay Guide

### Beginner Strategy
1. **Start Small**: Focus on opium trading between 2-3 ports
2. **Watch the Tracker**: Yellow sidebar shows best opium prices
3. **Avoid Early Combat**: Build up guns before picking fights
4. **Use Warehouses**: Store goods in safe ports (Hong Kong, Singapore)
5. **Manage Debt**: The 10% monthly interest is BRUTAL—pay it down fast!

### Advanced Tactics
- **Arbitrage Runs**: Create routes between consistently low/high price ports
- **Warehouse Network**: Stage goods across all ports for maximum flexibility
- **Combat Farming**: With 20+ guns, hunt pirates for booty bonuses
- **Interest Arbitrage**: Bank in Hong Kong earns 3-5%, debt costs 10%—profit spread carefully
- **Risk Management**: High-value goods in safe ports, commodities in risky ones

### Pro Tips
- Ships cost more as you get powerful (guns > 20 adds ¥1000 per 2 guns)
- Travel times are random (5-15 days)—plan accordingly
- Robbery only triggers with >¥25,000 cash—use the bank!
- Warehouse spoilage kicks in after 60 days away
- Net worth = Cash + Bank - Debt (include this in retirement score calculations)

## 📁 Project Structure

```
taipan_cursed/
├── launch_taipan.sh           # Smart launcher (auto-detects latest version)
├── Taipan_2020_v1.2.7.pl      # Latest stable release (2,900+ lines)
├── Taipan_2020_v1.2.6.pl      # Previous version (critical bug fix)
├── Taipan_2020_v1.2.5.pl      # UX improvements
├── Taipan_2020_v1.2.x.pl      # Version history (full progression)
├── CLAUDE.md                  # Developer documentation for AI-assisted dev
├── README.md                  # This file
├── ascii_taipan_map1.txt      # Home port map (Hong Kong)
├── ascii_taipan_map2.txt      # Shanghai indicator
├── ascii_taipan_map3.txt      # Nagasaki indicator
├── ascii_taipan_map4.txt      # Saigon indicator
├── ascii_taipan_map5.txt      # Manila indicator
├── ascii_taipan_map6.txt      # Batavia indicator
├── ascii_taipan_map7.txt      # Singapore indicator
├── ascii_taipan_map_legend.txt # Map key and legend
├── taipan_debug.log           # Runtime debug log (auto-generated)
├── test_*.pl                  # Unit tests for financial systems
└── saves/                     # Auto-generated save directory
    └── FirmName_YYYY-MM-DD.dat  # JSON save files
```

## 🎨 Screenshots & Demo

**📺 [Watch the interactive demo on asciinema.org](https://asciinema.org/a/p3YKBEUuIeAwF23v3qWioQAUs)** (click to play, pause, copy text!)

### Static UI Preview

```
┌─ Known World ───────────────────────┐┌─ Status ────────────┐
│ Ba - Batavia      \          / _/   ││Firm: Dutch Co.      │
│ Sa - Saigon        |        / /     ││Port: Hong Kong      │
│ Si - Singapore      \     o Nagasaki││Cash: ¥15,234        │
│            Shanghai o                ││Bank: ¥50,000        │
│                    /                 ││Debt: ¥0             │
│                   /                  ││Ships: 3             │
│                  |                   ││Guns: 15             │
│                 /                    ││Date: 1860/3/21      │
│               _/                     ││                     │
│            @ Hong Kong               ││OPIUM PRICES:        │
│                                      ││High:                │
│                                      ││Shanghai  5234¥      │
│  x    | /|         |        \  \    ││Nagasaki  4891¥      │
│     | / '--, Sa o/          ---     ││Low:                 │
│                                      ││Batavia   3456¥      │
└──────────────────────────────────────┘└─────────────────────┘
┌─ Ship Menu ──┬─ Trade Menu ─┬─ Money Menu ─┬─ System Menu ─┐
│ Sail To      │ Buy Goods    │ Bank Balance │ Save Game     │
│ Buy Ships    │ Sell Goods   │ Deposit      │ Load Game     │
│ Buy Guns     │ Store Goods  │ Withdraw     │ Retire        │
│ Repair Ship  │ Retrieve     │ Borrow       │               │
└──────────────┴──────────────┴──────────────┴───────────────┘
```

## 🔧 Customization & Modding

### Add New Ports
```perl
# In the @ports array
our @ports = ('Hong Kong', 'Shanghai', ...);

# Add warehouse capacity
$warehouses{'Your Port'} = { opium => 0, ... };

# Set risk level (0.0 = safe, 1.0 = extremely risky)
$port_risk{'Your Port'} = 0.15;
```

### Adjust Economic Variables
```perl
# Base prices (line ~118)
our %goods = (
    opium   => { base_price => 5000, volatility => 0.8 },
    # Modify base_price for inflation/deflation
    # Modify volatility for market chaos (0.0-1.0)
);

# Interest rates (line ~2235)
sub calculate_interest_rate {
    if ($balance >= 100000) { return 0.05; }  # Adjust as desired
}

# Debt interest (line ~437)
$player{debt} = int($player{debt} + $player{debt} * 0.1); # 10% monthly
```

### Create New Random Events
```perl
sub check_port_events {
    # Add your events here (line ~2147)
    if (rand() < 0.1) {  # 10% chance
        $cui->dialog("Your custom event message!");
    }
}
```

## 📜 Historical Context

### The Real Taipan Era (1860s)

This game captures a pivotal moment in Asian trade history:

- **Opium Wars Aftermath**: British forcing China to open treaty ports
- **Taiping Rebellion**: Massive civil war destabilizing China (1850-1864)
- **Treaty Port System**: Seven major ports opened to Western trade
- **Clipper Ship Era**: Fast sailing ships dominating Asian trade routes
- **Hong Kong & Shanghai Banking Corporation**: Founded 1865 (our game uses it in 1860)

### The Dutch East India Company (VOC)

While the VOC officially dissolved in 1799, the game's theme honors its legacy as the world's first multinational corporation:

- First publicly traded company (1602)
- Issued the first stock certificates
- Created the first modern stock exchange (Amsterdam)
- At its peak, worth ~$7.9 trillion in modern terms
- Operated for 198 years (1602-1800)

## 🎯 Why This Project Matters (For the Community)

### A Testament to Terminal Excellence

In an age of bloated Electron apps and web-based "native" UIs, **Taipan Cursed** proves that:
- **ncurses is not dead** - Complex, interactive UIs work beautifully in the terminal
- **Perl is production-ready** - 2,900+ lines of maintainable, debugged code
- **Single-file apps have merit** - No build systems, no dependencies hell, just `perl script.pl`
- **Classic gameplay endures** - Steve Wozniak's favorite game is still addictive 43 years later

### For Grey-Haired Linux Veterans

You've been here since before package managers. You remember when games fit on a floppy. **This is for you:**
- No `npm install` with 800MB of dependencies
- No Docker containers for a damn trading game
- No cloud authentication or "always online" DRM
- Just Perl 5 (already on your system) and a few CPAN modules
- Runs in `tmux`, works over SSH, logs to a simple text file
- **Actual respect for your terminal width**

### For Open-Source Hackers

Want to learn or teach Curses::UI? This is a **complete, working example** of:
- Multi-window layouts with dynamic updates
- Input handling and validation patterns
- State management in a single-threaded event loop
- Debugging terminal applications
- Version management with semantic versioning
- AI-assisted development workflow (see `CLAUDE.md`)

### The Code is the Documentation

Every function is commented. Every formula has its BASIC line reference. Every decision is explained.

**This isn't a toy project** - it's 40+ hours of actual gameplay testing, bug fixing, and UX iteration.

## 🤝 Contributing

Want to make Taipan Cursed even better?

### Feature Ideas
- [ ] Li Yuen extortion system (partially implemented)
- [ ] Elder Brother Wu loan shark mechanics
- [ ] Storm/weather events
- [ ] Opium confiscation raids
- [ ] More goods (tea, spices, porcelain)
- [ ] Crew management system
- [ ] Rival traders
- [ ] Historical events (news system)
- [ ] Multiplayer competition mode

### Code Improvements
- [ ] Separate concerns (game logic vs UI)
- [ ] Unit tests for core systems
- [ ] Config file for easy modding
- [ ] Mouse support in Curses::UI
- [ ] Sound effects (terminal bell events)
- [ ] Color scheme customization
- [ ] Cross-platform compatibility testing

## 🐛 Known Issues & Roadmap

### ✅ Recently Fixed (v1.2.5-v1.2.7)
- ~~Cursor positioning in buy/sell prompts~~ → **FIXED** with "Enter for max" pattern
- ~~No maximum display when buying ships/guns~~ → **FIXED** with smart calculators
- ~~Port debt desync causing false errors~~ → **FIXED** with distribution algorithm
- ~~Buy Guns prompt overflow~~ → **FIXED** with newline character

### Current Limitations
- Map files must be in the same directory as the script
- Terminal must be at least 120x40 characters (ncurses limitation)
- No automated test suite yet (manual testing only)
- Combat globals persist between battles (known quirk)

### Planned Features (v1.3+)
- Li Yuen fleet encounters (partially coded, needs activation)
- McHenry shipwright character (repair system exists, character needs polish)
- Additional random events (typhoons, rumors, smuggling)
- Achievement system with persistent tracking
- Statistics tracking (lifetime stats, best runs, leaderboards)
- Tutorial mode for new players
- Optional color themes
- Configuration file for easy modding

## 📖 Original Taipan! Legacy

This game stands on the shoulders of giants:

- **1979**: Original concept by Art Canfil for TRS-80
- **1982**: Ronald J. Berg's Apple II port—the legendary version
- **1990s**: Various Unix/Linux ports by Jay Link and others
- **2020s**: This Perl/Curses::UI reimagining with modern enhancements

Steve Wozniak's endorsement: *"This is my favorite game!"* still rings true decades later.

## 📄 License

**GNU General Public License v3.0 or later**

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See [LICENSE](LICENSE) for full details.

### Attribution
- **Original Game**: Art Canfil (Concept), Ronald J. Berg (Apple II), Jay Link (Unix/C)
- **Curses Version**: Michael Lavery
- **Enhanced Logic**: AI-assisted development with Grok from xAI

## 🌟 Why "Cursed"?

The name is a playful triple reference:
1. **Curses::UI** - The powerful Perl terminal interface library powering the game
2. **Blessed & Cursed** - The dual nature of great wealth in trading
3. **Pirate's Curse** - The dangers lurking in every trade route

Plus, mastering the 10% monthly compound debt interest feels like a curse until you learn to manage it!

## 🎯 Final Words

Whether you're a retro gamer chasing nostalgia, a Perl programmer seeking a substantial codebase to study, a grey-haired Linux veteran who remembers when software was simple, or someone who loves deep economic strategy games, **Taipan Cursed** offers hundreds of hours of engaging gameplay wrapped in beautiful terminal aesthetics.

**This is what software can be:**
- Self-contained (one file, one command)
- Debuggable (text log, JSON saves)
- Extensible (well-commented, modular design)
- Respectful (no telemetry, no ads, no cloud, just you and your terminal)

The South China Sea awaits, Taipan. Will you build an empire or end up as a galley hand?

**Fair winds and following seas!** ⚓

---

## 📣 The Elevator Pitch (For Sharing)

> **Taipan Cursed**: Steve Wozniak's favorite trading game, reborn in 2,900+ lines of production Perl with Curses::UI. Command a merchant fleet in 1860s Asia - trade opium, battle pirates, manage debt across seven ports. Features smart auto-launcher, "Press Enter for max" UX, and JSON saves. No Electron. No npm. No Docker. Just `perl script.pl` and pure terminal excellence. GPL-3.0. [github.com/michaellavery-grp/taipan_cursed]

**TL;DR for Hacker News:**
"Wozniak's favorite 1982 trading game, remade in Perl with ncurses. 2.9k lines, zero build system, runs over SSH. Recently fixed port debt desync and added smart UX. Proves single-file terminal apps still work in 2025."

**TL;DR for /r/linux:**
"Terminal trading game in pure Perl. No Electron bloat, no cloud auth, actual respect for your 120x40 terminal. Smart launcher auto-detects versions. GPL-3.0."

---

### Quick Links
- 🐛 [Report Issues](https://github.com/michaellavery-grp/taipan_cursed/issues)
- 💬 [Discussions](https://github.com/michaellavery-grp/taipan_cursed/discussions)
- ⭐ [Star this repo](https://github.com/michaellavery-grp/taipan_cursed) if you enjoy the game!
- 🍴 [Fork it](https://github.com/michaellavery-grp/taipan_cursed/fork) to create your own version
- 📖 [Read CLAUDE.md](CLAUDE.md) for developer documentation

---

*Made with ❤️ for terminal enthusiasts, grey-haired Linux veterans, and retro gamers everywhere*

**No cloud. No containers. No compilation. Just Perl and ncurses excellence.**

```
               ~~|     ,                    
                ,|`-._/|                    
              .' |   /||\                   
            .'   | ./ ||`\                  
           / `-. |/._ ||  \                 
          /     `||   ||   \                
          |      ||   ||__  \               
~^~_-~^~=/       ||   ||  `-`~^=~^~-~^~_~^~=
```
