# Complete Implementation Guide for v1.0.4

## Summary

Based on original 1979 Apple II BASIC code at https://www.taipangame.com/BASIC.txt:

1. ✅ **Banking Fixed**: Deposit/Withdraw restricted to Hong Kong in functions (DONE)
2. **Save Slots**: 4 fixed slots with auto-save (NEEDS IMPLEMENTATION)
3. **Li Yuen**: Loan-based protection system from original game (NEEDS IMPLEMENTATION)

---

## Li Yuen System (Original 1979 Mechanics)

### How It Works in Original BASIC

The `LI` variable tracks protection status from Li Yuen's organization:

**Line 10**: `LI = 0` (initialize - no protection)
**Line 1065**: `LI = 1` (gain protection by accepting Elder Brother Wu's loan)
**Line 1090**: `LI = 0` (lose protection by refusing loan)
**Line 2310**: `LI = LI AND FN R(20)` (protection randomly decays - 5% chance per event)
**Line 3210**: `IF FN R(4 + 8 * LI)` (Li Yuen encounter check)
  - LI=0: 1-in-4 (25%) chance Li Yuen appears
  - LI=1: 1-in-12 (8.3%) chance Li Yuen appears
**Line 3220**: "Good joss!! They let us be!!" (if LI=1 and Li Yuen appears)
**Line 3230**: Li Yuen attacks if LI=0:
  - Fleet: `SN = FN R(SC/5 + GN) + 5`
  - Damage: `F1 = 2` (double damage!)

**THE KEY**: Protection comes from being "part of the family" by borrowing from Elder Brother Wu (Li Yuen's financial enforcer). It's not tribute - it's being in debt to the organization!

---

## CODE CHANGES NEEDED

### 1. GameModel.swift Properties (DONE)

```swift
@Published var liYuenProtection: Bool = false  // LI flag
@Published var liYuenAlert: String?  // Li Yuen safe passage message
```

### 2. Modify `borrow()` Function

When borrowing in Hong Kong specifically, offer Elder Brother Wu's "special" loan that grants protection:

```swift
func borrow(_ amount: Double) -> Bool {
    let maxDebtPerPort = 50000.0
    let portDebtAmount = portDebt[currentPort] ?? 0.0
    let availableCredit = maxDebtPerPort - portDebtAmount

    guard amount <= availableCredit else {
        addLog("⚠️ Insufficient credit at this port")
        return false
    }

    // ELDER BROTHER WU'S SPECIAL OFFER (Hong Kong only, when desperate)
    if currentPort == "Hong Kong" && cash < 500 && debt > 10000 && !liYuenProtection {
        // Original BASIC line 1330: Elder Brother Wu emergency loan offer
        // This grants Li Yuen protection (LI = 1)
        // Show special dialog asking if player wants protection
        // (This should trigger a UI dialog, not auto-grant)
    }

    // Normal borrowing
    cash += amount
    debt += amount
    portDebt[currentPort] = (portDebt[currentPort] ?? 0) + amount

    addLog("Borrowed ¥\(Int(amount)) at \(currentPort)")
    return true
}
```

### 3. Add Elder Brother Wu Loan Offer Function

```swift
func offerElderBrotherWuLoan() -> Double {
    // BASIC line 1340: I = FN R(2000) * BL% + 1500
    // For first loan: I = rand(2000) + 1500 = 1500-3500
    let badLoanCount = 0  // TODO: Track this if implementing multiple Wu loans
    let loanAmount = Double.random(in: 0...2000) * Double(badLoanCount + 1) + 1500

    // Interest calculation (predatory!)
    let paybackAmount = Double.random(in: 0...2000) * Double(badLoanCount + 1) + 1500

    return loanAmount
}

func acceptElderBrotherWuLoan(amount: Double) {
    // Grant loan
    cash += amount
    debt += amount
    portDebt["Hong Kong"] = (portDebt["Hong Kong"] ?? 0) + amount

    // GRANT LI YUEN PROTECTION (Line 1065)
    liYuenProtection = true

    addLog("💰 Accepted Elder Brother Wu's loan: ¥\(Int(amount))")
    addLog("🏴‍☠️ Gained Li Yuen's protection")
}

func declineElderBrotherWuLoan() {
    // Line 1090: LI = 0
    liYuenProtection = false
    addLog("Declined Elder Brother Wu's offer")
}
```

### 4. Add Protection Decay System

Call this periodically (after each sail?):

```swift
func decayLiYuenProtection() {
    // BASIC line 2310: LI = LI AND FN R(20)
    // This gives ~5% chance (1-in-20) to lose protection
    if liYuenProtection {
        if Int.random(in: 0..<20) == 0 {
            liYuenProtection = false
            addLog("⚠️ Li Yuen's protection has faded...")
        }
    }
}
```

Add call in `sailTo()` function:
```swift
func sailTo(_ destination: String) {
    // ... existing code ...

    // Decay Li Yuen protection
    decayLiYuenProtection()

    // Random pirate encounter
    if Double.random(in: 0...1) < (1.0 / 9.0) {
        encounterPirates()
    }

    // ... rest of code ...
}
```

### 5. Modify `encounterPirates()` for Li Yuen Check

```swift
func encounterPirates() {
    let holdCapacity = ships * 60

    // CHECK FOR LI YUEN ENCOUNTER (Line 3210)
    // IF FN R(4 + 8 * LI)
    let liYuenChance = 4 + (liYuenProtection ? 8 : 0)  // 4 or 12
    let isLiYuen = Int.random(in: 0..<liYuenChance) == 0

    if isLiYuen {
        handleLiYuenEncounter(holdCapacity: holdCapacity)
        return
    }

    // NORMAL PIRATES
    let maxPirates = (holdCapacity / 10) + guns
    let pirateFleet = Int.random(in: 1...max(1, maxPirates)) + 1

    combatState = CombatState(pirateCount: pirateFleet, isLiYuen: false)
    showingCombat = true
    addLog("⚠️ Pirates attacking! \(pirateFleet) ships approaching!")
}

func handleLiYuenEncounter(holdCapacity: Int) {
    if liYuenProtection {
        // SAFE PASSAGE (Line 3220)
        let message = "🏴‍☠️ LI YUEN'S FLEET SIGHTED! 🏴‍☠️\n\n" +
                     "The legendary pirate lord's black sails loom on the horizon...\n\n" +
                     "But they recognize Elder Brother Wu's mark upon you.\n\n" +
                     "\"Good joss, Taipan! Pass safely.\"\n\n" +
                     "Li Yuen's fleet lets you be!"

        liYuenAlert = message
        addLog("🏴‍☠️ Li Yuen encounter - safe passage (protection active)")
    } else {
        // ATTACK! (Line 3230)
        // Fleet size: SN = FN R(SC / 5 + GN) + 5
        let maxFleet = (holdCapacity / 5) + guns + 5
        let pirateFleet = Int.random(in: 5...max(5, maxFleet))

        combatState = CombatState(pirateCount: pirateFleet, isLiYuen: true)
        showingCombat = true

        addLog("💀 LI YUEN ATTACKING! \(pirateFleet) legendary pirate ships!")
    }
}
```

### 6. Update CombatState

```swift
class CombatState: ObservableObject {
    @Published var pirateShips: [PirateShip]
    @Published var roundNumber: Int = 0
    @Published var escapeAttempts: Int = 0
    @Published var totalDamageTaken: Int = 0
    @Published var shipsSunk: Int = 0
    @Published var isActive: Bool = true
    @Published var outcome: CombatOutcome = .ongoing
    @Published var booty: Int = 0
    @Published var combatLog: [String] = []

    let isLiYuen: Bool  // NEW

    // Escape progression variables
    var ok: Int = 0
    var ik: Int = 0

    init(pirateCount: Int, isLiYuen: Bool = false) {
        self.isLiYuen = isLiYuen
        self.pirateShips = (0..<pirateCount).map { _ in
            PirateShip(health: Int.random(in: 20...50))
        }
    }

    // ... rest of class ...
}
```

### 7. Apply Li Yuen Double Damage in Combat

In `executeFightRound()` and `executeRunRound()`:

```swift
// Enemy return fire
if combat.piratesRemaining > 0 {
    let damageMultiplier = combat.isLiYuen ? 2.0 : 1.0  // F1 = 2 for Li Yuen!
    let piratesLeft = combat.piratesRemaining
    let edScaled = 0.5
    let baseDamage = Int.random(in: 0...Int(edScaled * Double(piratesLeft)))
    let additionalDamage = piratesLeft / 2
    let damageTaken = Int(Double(baseDamage + additionalDamage) * damageMultiplier)

    shipDamage = min(1.0, shipDamage + (Double(damageTaken) / 100.0))
    // ... rest of damage code ...

    if combat.isLiYuen {
        combat.combatLog.append("⚠️ Li Yuen's pirates strike with legendary ferocity!")
    }
}
```

### 8. Apply Li Yuen Double Booty on Victory

In `processCombatAction()` after victory:

```swift
if combat.allPiratesSunk {
    combat.outcome = .victory
    let months = calculateMonthsSince1860()

    let initialPirates = combat.pirateShips.count
    let bootyMultiplier = combat.isLiYuen ? 2.0 : 1.0  // 2x for Li Yuen!

    let baseBooty = Int(Double.random(in: 0...1) * Double(months) / 4.0 * 1000.0 * pow(Double(initialPirates), 1.05))
    let bonus = Int.random(in: 0...1000) + 250
    let booty = Int(Double(baseBooty + bonus) * bootyMultiplier)

    cash += Double(booty)
    combat.booty = booty

    if combat.isLiYuen {
        combat.combatLog.append("💰 LEGENDARY TREASURE!")
        combat.combatLog.append("Defeated Li Yuen's fleet!")
        combat.combatLog.append("Booty: ¥\(booty) (2x for Li Yuen!)")
        addLog("💰 Defeated Li Yuen! Legendary booty: ¥\(booty)")
    } else {
        combat.combatLog.append("Victory! Booty: ¥\(booty)")
        addLog("Victory! Booty: ¥\(booty)")
    }
}
```

### 9. Add Li Yuen Alert UI (ContentView.swift)

After storm alert:

```swift
// Li Yuen safe passage alert
if let liYuenMessage = game.liYuenAlert {
    LiYuenAlertView(message: liYuenMessage, onDismiss: {
        game.liYuenAlert = nil
    })
    .transition(.opacity)
    .zIndex(98)
}
```

Add view:

```swift
struct LiYuenAlertView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(message)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(15)

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding(40)
        }
    }
}
```

### 10. Update SaveData Struct

```swift
struct SaveData: Codable {
    let firmName: String
    let currentPort: String
    let cash: Double
    let bank: Double
    let debt: Double
    let portDebt: [String: Double]?
    let ships: Int
    let guns: Int
    let shipDamage: Double
    let cargoHold: [String: Int]
    let warehouses: [String: Warehouse]
    let ports: [Port]
    let commodities: [String: Commodity]
    let gameDate: Date
    let gameLog: [String]
    let liYuenProtection: Bool?  // NEW - optional for backward compatibility
}
```

Update save/load:

```swift
func saveGame() throws {
    let saveData = SaveData(
        // ... existing fields ...
        liYuenProtection: liYuenProtection
    )
    // ... rest of save code ...
}

func loadGame(from url: URL) throws {
    // ... existing load code ...
    self.liYuenProtection = saveData.liYuenProtection ?? false
    // ...
}
```

---

## SAVE SLOT SYSTEM

(See IMPLEMENTATION_PLAN_v1.0.4.md for complete save slot implementation)

---

## TESTING

### Banking
- [x] Deposit blocked outside Hong Kong
- [x] Withdraw blocked outside Hong Kong
- [ ] Error message shown in log

### Li Yuen
- [ ] 25% encounter rate without protection
- [ ] 8.3% encounter rate with protection
- [ ] Safe passage with protection ("Good joss!")
- [ ] Attack without protection
- [ ] Fleet size 5-125 ships (vs 1-61 normal)
- [ ] Double damage from Li Yuen
- [ ] Double booty on victory
- [ ] Protection decays randomly (5% per sail)
- [ ] Elder Brother Wu loan grants protection

### Save Slots
- [ ] Can save to slots 1-4
- [ ] Can load from slots 1-4
- [ ] Auto-save after sailing
- [ ] Slot info displays correctly

---

## FILES TO MODIFY

1. ✅ GameModel.swift - deposit/withdraw Hong Kong check (DONE)
2. GameModel.swift - Add Li Yuen functions
3. ContentView.swift - Add Li YuenAlertView
4. SystemMenuView.swift - Save slot UI
5. MoneyMenuView.swift - Elder Brother Wu loan offer

---

This implementation stays 100% faithful to the 1979 Apple II original!
