# Implementation Plan for TaipanIOS v1.0.4

## Issues to Fix

### 1. ❌ Banking Restriction Broken
**Problem**: Despite UI code hiding Deposit/Withdraw buttons outside Hong Kong, the game functions (`deposit()` and `withdraw()`) don't enforce location.

**Root Cause**: Functions in GameModel.swift lines 323-341 lack `currentPort` checks.

**Fix**:
```swift
func deposit(_ amount: Double) -> Bool {
    guard currentPort == "Hong Kong" else {
        addLog("⚠️ Banking only available in Hong Kong")
        return false
    }
    if amount <= cash {
        cash -= amount
        bank += amount
        addLog("Deposited ¥\(Int(amount))")
        return true
    }
    return false
}

func withdraw(_ amount: Double) -> Bool {
    guard currentPort == "Hong Kong" else {
        addLog("⚠️ Banking only available in Hong Kong")
        return false
    }
    if amount <= bank {
        bank -= amount
        cash += amount
        addLog("Withdrew ¥\(Int(amount))")
        return true
    }
    return false
}
```

---

### 2. 💾 Save System Needs Redesign

**Current System**:
- Saves to Documents directory with date-stamped filenames
- Requires file picker to load
- User must manually save

**Requested System**:
- 4 fixed save slots: `savegame1.json` through `savegame4.json`
- Bundled with app (in app bundle or app support directory)
- Auto-save to slot 1 after every sail
- Manual save to any of 4 slots
- Load from any of 4 slots

**Implementation**:

**A. New Save Location** (App Support, not Documents):
```swift
func getAppSupportDirectory() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let gameDir = appSupport.appendingPathComponent("TaipanSaves")

    // Create directory if needed
    try? FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)

    return gameDir
}
```

**B. Save Slot Functions**:
```swift
func saveToSlot(_ slot: Int) throws {
    guard slot >= 1 && slot <= 4 else { throw SaveError.invalidSlot }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let saveData = SaveData(...) // existing save data
    let data = try encoder.encode(saveData)

    let saveDir = getAppSupportDirectory()
    let filename = "savegame\(slot).json"
    let fileURL = saveDir.appendingPathComponent(filename)

    try data.write(to: fileURL)
    addLog("Saved to Slot \(slot)")
}

func loadFromSlot(_ slot: Int) throws {
    guard slot >= 1 && slot <= 4 else { throw SaveError.invalidSlot }

    let saveDir = getAppSupportDirectory()
    let filename = "savegame\(slot).json"
    let fileURL = saveDir.appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw SaveError.slotEmpty
    }

    let data = try Data(contentsOf: fileURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let saveData = try decoder.decode(SaveData.self, from: data)

    // Load all properties...
    self.firmName = saveData.firmName
    // ... etc

    addLog("Loaded from Slot \(slot)")
}

func autoSave() {
    do {
        try saveToSlot(1)  // Always auto-save to slot 1
    } catch {
        addLog("⚠️ Auto-save failed: \(error.localizedDescription)")
    }
}
```

**C. Call Auto-Save After Sailing**:
In `sailTo()` function (GameModel.swift), add at the end:
```swift
func sailTo(_ destination: String) {
    // ... existing code ...

    addLog("Arrived at \(finalDestination) after \(travelDays) days")

    // AUTO-SAVE after every voyage
    autoSave()
}
```

**D. Update UI** (SystemMenuView.swift):
Replace file picker with slot buttons:
```swift
// Save Game Section
Section {
    VStack(spacing: 12) {
        ForEach(1...4, id: \.self) { slot in
            Button(action: {
                do {
                    try game.saveToSlot(slot)
                    saveMessage = "Saved to Slot \(slot)"
                } catch {
                    saveMessage = "Error: \(error.localizedDescription)"
                }
            }) {
                HStack {
                    Image(systemName: "opticaldiscdrive")
                    Text("Save Slot \(slot)")
                    Spacer()
                    if slot == 1 {
                        Text("(Auto-Save)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
} header: {
    Text("Save Game")
        .font(.headline)
}

// Load Game Section
Section {
    VStack(spacing: 12) {
        ForEach(1...4, id: \.self) { slot in
            Button(action: {
                do {
                    try game.loadFromSlot(slot)
                    loadMessage = "Loaded from Slot \(slot)"
                } catch {
                    loadMessage = slot == 1 ? "Slot \(slot) empty" : "Error loading slot \(slot)"
                }
            }) {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text("Load Slot \(slot)")
                    Spacer()
                    // Show slot info if exists
                    if game.slotHasSave(slot) {
                        Text(game.getSlotInfo(slot))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
} header: {
    Text("Load Game")
        .font(.headline)
}
```

**E. Helper Functions**:
```swift
func slotHasSave(_ slot: Int) -> Bool {
    let saveDir = getAppSupportDirectory()
    let filename = "savegame\(slot).json"
    let fileURL = saveDir.appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: fileURL.path)
}

func getSlotInfo(_ slot: Int) -> String {
    guard slotHasSave(slot) else { return "Empty" }

    do {
        let saveDir = getAppSupportDirectory()
        let filename = "savegame\(slot).json"
        let fileURL = saveDir.appendingPathComponent(filename)

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let saveData = try decoder.decode(SaveData.self, from: data)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        let dateStr = dateFormatter.string(from: saveData.gameDate)

        return "\(saveData.firmName) - \(dateStr)"
    } catch {
        return "Error"
    }
}

enum SaveError: Error {
    case invalidSlot
    case slotEmpty
    case encodingFailed
    case decodingFailed
}
```

---

### 3. 🏴‍☠️ Li Yuen the Pirate Lord

**Research Summary** (from Perl v1.3.0 and test_li_yuen.pl):

**Li Yuen Mechanics** (APPLE II BASIC lines 3110-3230):
1. **Encounter Probability**:
   - Without tribute (LI=0): 25% of pirate encounters (1-in-4)
   - With tribute (LI=1): 8.3% of pirate encounters (1-in-12)
   - Formula: `IF FN R(4 + 8 * LI) THEN 3300`

2. **Tribute System**:
   - Player has flag `li_yuen_tribute` (0 or 1)
   - If tribute paid and Li Yuen encountered: "Good joss!!" - safe passage
   - If NO tribute: Li Yuen attacks with massive fleet

3. **Li Yuen Combat**:
   - Fleet size: `SN = FN R(SC / 5 + GN) + 5`
     - Example: 400 capacity + 40 guns = rand(80 + 40) + 5 = 5-125 ships
     - vs normal pirates: `SN = FN R(SC / 10 + GN) + 1` = 1-61 ships
   - **Double damage**: F1 = 2 (Li Yuen does 2x damage!)
   - **Double booty**: If defeated, 2x treasure

4. **Tribute Payment** (UNKNOWN - Not found in Perl code!):
   - **Question**: When/how does player pay tribute?
   - **Best guess**: Offer tribute after first Li Yuen defeat? Or extortion demand?
   - **Need clarification**: Where in original BASIC does Li Yuen ask for tribute?

**Implementation (without tribute mechanic for now)**:

**A. Add to GameModel**:
```swift
@Published var liYuenTribute: Bool = false  // Whether tribute has been paid
```

**B. Update SaveData struct**:
```swift
struct SaveData: Codable {
    // ... existing fields ...
    let liYuenTribute: Bool?  // Optional for backward compatibility
}
```

**C. Modify encounterPirates()** (GameModel.swift):
```swift
func encounterPirates() {
    // Original formula: SN = FN R(SC / 10 + GN) + 1
    let holdCapacity = ships * 60

    // Check if it's Li Yuen (25% without tribute, 8.3% with tribute)
    let liYuenChance = 4 + (liYuenTribute ? 8 : 0)  // 4 or 12
    let isLiYuen = Int.random(in: 0..<liYuenChance) == 0

    if isLiYuen {
        handleLiYuenEncounter(holdCapacity: holdCapacity)
    } else {
        // Normal pirates
        let maxPirates = (holdCapacity / 10) + guns
        let pirateFleet = Int.random(in: 1...max(1, maxPirates)) + 1

        combatState = CombatState(pirateCount: pirateFleet, isLiYuen: false)
        showingCombat = true
        addLog("⚠️ Pirates attacking! \(pirateFleet) ships approaching!")
    }
}

func handleLiYuenEncounter(holdCapacity: Int) {
    if liYuenTribute {
        // PAID TRIBUTE - Safe passage!
        let message = "🏴‍☠️ Li Yuen's Fleet Sighted! 🏴‍☠️\n\n" +
                     "The legendary pirate lord's black sails appear...\n\n" +
                     "'Good joss, Taipan! You have paid tribute.\n" +
                     "Pass safely. The gods smile upon you.'\n\n" +
                     "Li Yuen's fleet lets you be!"

        // TODO: Show alert (not combat)
        addLog("Li Yuen encounter - tribute recognized, safe passage")
        return
    } else {
        // NO TRIBUTE - ATTACK!
        // Fleet size: SC / 5 + GN + 5 (MUCH larger than normal!)
        let maxPirates = (holdCapacity / 5) + guns + 5
        let pirateFleet = Int.random(in: 5...max(5, maxPirates))

        combatState = CombatState(pirateCount: pirateFleet, isLiYuen: true)
        showingCombat = true

        addLog("⚠️💀 LI YUEN ATTACKING! \(pirateFleet) legendary pirate ships!")
    }
}
```

**D. Update CombatState**:
```swift
class CombatState: ObservableObject {
    @Published var pirateShips: [PirateShip]
    let isLiYuen: Bool  // NEW: Track if this is Li Yuen
    // ... other fields ...

    init(pirateCount: Int, isLiYuen: Bool = false) {
        self.isLiYuen = isLiYuen
        self.pirateShips = (0..<pirateCount).map { _ in
            PirateShip(health: Int.random(in: 20...50))
        }
    }
}
```

**E. Double Damage for Li Yuen**:
In combat processing (GameModel.swift), multiply damage by 2 if Li Yuen:
```swift
func executeFightRound(combat: CombatState) {
    // ... player attacks ...

    // Enemy return fire
    if combat.piratesRemaining > 0 {
        let damageMultiplier = combat.isLiYuen ? 2.0 : 1.0  // Li Yuen does 2x!
        let baseDamage = Int.random(in: 0...Int(edScaled * Double(piratesLeft)))
        let damageTaken = Int(Double(baseDamage + additionalDamage) * damageMultiplier)

        // ... apply damage ...
    }
}
```

**F. Double Booty for Li Yuen**:
After victory:
```swift
if combat.allPiratesSunk {
    let months = calculateMonthsSince1860()
    let bootyMultiplier = combat.isLiYuen ? 2.0 : 1.0  // Li Yuen treasure!
    let booty = Int(Double.random(in: 0...1) * (months / 4 * 1000 * pow(initialPirates, 1.05)) * bootyMultiplier)
                + Int.random(in: 0...1000)) + 250

    cash += booty

    if combat.isLiYuen {
        addLog("💰 Defeated Li Yuen! Legendary treasure: ¥\(booty)!")
    } else {
        addLog("Booty captured: ¥\(booty)")
    }
}
```

**G. Tribute Payment** (PLACEHOLDER - needs design):
```swift
// Option 1: After defeating Li Yuen, offer tribute to prevent future attacks?
// Option 2: Li Yuen demands tribute after first encounter?
// Option 3: Can pay tribute proactively in Hong Kong?

func offerTributeTo(...){
    //TODO: Figure out when/how tribute is offered in original game
}
```

---

## Testing Checklist v1.0.4

### Banking Restriction
- [ ] Deposit function returns false outside Hong Kong
- [ ] Withdraw function returns false outside Hong Kong
- [ ] UI buttons hidden outside Hong Kong
- [ ] Borrow/Repay work at all ports

### Save Slots
- [ ] Can save to slots 1-4
- [ ] Can load from slots 1-4
- [ ] Auto-save triggers after sailing
- [ ] Slot info shows correctly (firm name + date)
- [ ] Empty slots show "Empty"
- [ ] Saves persist across app restarts

### Li Yuen
- [ ] Li Yuen encounters ~25% without tribute
- [ ] Li Yuen encounters ~8.3% with tribute
- [ ] Fleet size 5-125 (vs 1-61 normal)
- [ ] Li Yuen does 2x damage in combat
- [ ] Defeating Li Yuen gives 2x booty
- [ ] Tribute grants safe passage
- [ ] Normal pirates still work correctly

---

## Files to Modify

1. **GameModel.swift**:
   - Fix `deposit()` and `withdraw()` (add Hong Kong checks)
   - Add `liYuenTribute` property
   - Add save slot functions (`saveToSlot()`, `loadFromSlot()`, `autoSave()`)
   - Add Li Yuen encounter logic (`handleLiYuenEncounter()`)
   - Modify `encounterPirates()` for Li Yuen checks
   - Update combat damage/booty for Li Yuen multipliers

2. **SystemMenuView.swift**:
   - Replace file picker with 4 save slot buttons
   - Replace file picker with 4 load slot buttons
   - Show slot information

3. **CombatState** (in GameModel.swift):
   - Add `isLiYuen: Bool` field
   - Update initializer

4. **SaveData struct** (in GameModel.swift):
   - Add `liYuenTribute: Bool?` field

---

## Questions for User

1. **Li Yuen Tribute**: How/when does player pay tribute in original game?
   - After defeating Li Yuen?
   - Li Yuen demands it after first encounter?
   - Player can proactively pay in a port?
   - What's the cost?

2. **Save Slots**: Should slot 1 be read-only (auto-save only)?
   - Or can user manually save to slot 1 too?

3. **Li Yuen Alert**: Since tribute grants safe passage, should this show:
   - A dialog like storms?
   - Just a log message?
   - A special "Li Yuen Tribute" view?

---

## Version Number

This will be **v1.0.4** with changelog:
- Fixed: Banking restricted to Hong Kong only (deposit/withdraw)
- Changed: Save system now uses 4 fixed slots with auto-save
- Added: Li Yuen the Pirate Lord encounters
- Added: Li Yuen tribute system (reduces encounter rate)
- Added: Li Yuen double damage and double booty

---

**Ready to implement once Li Yuen tribute mechanic is clarified!**
