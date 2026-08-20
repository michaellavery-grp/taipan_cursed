# Li Yuen Complete Implementation - v1.0.5

## Summary

Successfully implemented the complete Li Yuen tribute/protection system based on **three sources**:

1. **Original 1979 TRS-80 game mechanics** (from game book)
2. **1982 Apple II BASIC code** (BASIC.txt)
3. **Perl v1.0.0** (post-combat confiscation)

## Research Sources

### 1. Taipan Game Book (CC0 Public Domain)
**Source**: `taipan_game_book.txt` from Archive.org

**Key Findings** (Lines 671-682, 9168-9213):
- Li Yuen runs "private maritime protective agency"
- Clients donate to "Tin Hau temple building fund" (Sea Goddess)
- TR flag: 0 = not paid, 1 = paid protection
- DN variable = up to half player's cash
- Offer appears in Hong Kong when: `cash > 100 AND TR = 0`
- Protection expires randomly (5% of voyages - Line 170)

### 2. Player Strategy Guides
**Source**: Web search ([Ric Size Taipan Guide](https://ricsize.com/taipan-1982-gameplay-basics-tips/))

**Strategic Info**:
- Pay tribute until 40+ cannons
- Carrying excess cash increases tribute demands
- Refusing = eventual 48+ ship Li Yuen fleet attack

### 3. Perl v1.0.0 Implementation
**Source**: `Taipan_2020_v1.0.0.pl` lines 1325-1354

**Post-Combat Confiscation**:
- If Li Yuen fleet survives combat
- Seizes ALL opium
- Demands 30-56% of cash
- "You got off easy, Taipan!"

---

## iOS Implementation (TaipanIOS v1.0.5)

### Files Modified

#### 1. GameModel.swift

**New Properties** (lines 142-146):
```swift
@Published var liYuenProtection: Bool = false
@Published var liYuenAlert: String?
@Published var liYuenTributeDialog: LiYuenTributeOffer?
@Published var liYuenTributesPaid: Int = 0
@Published var liYuenRefusals: Int = 0
```

**New Structs** (lines 1226-1229):
```swift
struct LiYuenTributeOffer {
    let amount: Int
    let message: String
}
```

**Tribute System Functions** (lines 512-571):
- `checkForLiYuenRepresentative()` - 5% chance in Hong Kong when cash > ¥20,000
- `payLiYuenTribute(amount:)` - Grants protection, reduces refusals
- `refuseLiYuenTribute()` - Increases refusal count, removes protection
- `applyLiYuenConfiscation(combat:)` - Post-combat seizure

**Escalating Encounter Rate** (lines 591-605):
```swift
let baseChance = 4 + (liYuenProtection ? 8 : 0)  // 25% or 8.3%
let refusalPenalty = max(0, liYuenRefusals)
let adjustedChance = max(2, baseChance - refusalPenalty)  // Max 50%
```

**SaveData Updates** (lines 1363-1365):
```swift
let liYuenProtection: Bool?
let liYuenTributesPaid: Int?
let liYuenRefusals: Int?
```

#### 2. ContentView.swift

**Tribute Dialog UI** (lines 99-112, 404-461):
- `LiYuenTributeDialogView` - Pay/Refuse buttons with dramatic messaging
- Z-index 97 (below safe passage alerts)
- Green "Pay Tribute" button shows amount
- Red "Refuse" button warns of risk

#### 3. SaveData Integration
- Backward compatible (defaults: false, 0, 0)
- All functions updated (saveToSlot, loadFromSlot, saveGame, loadGame)

---

## Perl v2.2.1 Implementation

### Files Modified

#### Taipan_2020_v2.2.1.pl

**Sea Goddess Donation Offer** (lines 2888-2941):
```perl
# Triggers: Hong Kong + cash > ¥100 + TR = 0
# DN = int(rand(cash / 2))  # Up to half cash
# Dialog: Tin Hau temple donation with Li Yuen representative
# Accept: cash -= DN, TR = 1 (protection granted)
# Refuse: TR = 0 (no protection, warning given)
```

**Tribute Expiry** (lines 653-659):
```perl
# Book Line 170: TR = 0 at end of 5% of voyages
if ($player{li_yuen_tribute} && int(rand(20)) == 0) {
    $player{li_yuen_tribute} = 0;  # Protection expires
}
```

**Existing Systems** (already implemented):
- Li Yuen encounter (25% vs 8.3%) - lines 2030-2069
- Double damage (F1=2) - line 2063
- Safe passage when protected - lines 2041-2046
- Attack without protection - lines 2048-2069

---

## Game Mechanics Summary

### Tribute Payment System

**Trigger Conditions**:
- Location: Hong Kong only
- Cash requirement: > ¥20,000 (iOS) / > ¥100 (Perl)
- Protection status: Not currently protected
- Random chance: 5% per arrival

**Tribute Amount**:
- iOS: 10-25% of current cash
- Perl: Up to 50% of current cash (DN = rand(cash/2))

**Effects of Paying**:
- ✅ Protection activated (TR = 1)
- ✅ Li Yuen encounter rate: 25% → 8.3%
- ✅ Safe passage if encountered
- ✅ May protect from rival pirates (5% chance they drive them off)
- ✅ iOS: Reduces refusal count

**Effects of Refusing**:
- ❌ No protection (TR = 0)
- ❌ Li Yuen encounter rate: 25% (or higher with refusals)
- ❌ Guaranteed attack if encountered
- ❌ iOS: Increases refusal count (escalates to 50% max encounter rate)

### Protection Expiry

**Random Decay**:
- 5% chance per voyage
- Happens during date advancement
- No warning given (player discovers on next Li Yuen encounter)

**iOS Additional Decay**:
- Paying tribute reduces refusal count by 1
- Refusing increases refusal count by 1
- Refusal count affects encounter rate

### Li Yuen Encounter

**Without Protection**:
- 25% of pirate encounters (1-in-4)
- iOS: Increases to 50% max with refusals
- Fleet size: 5-125 ships (SC/5 + GN + 5)
- Double damage (F1=2)
- Double booty if defeated

**With Protection**:
- 8.3% of pirate encounters (1-in-12)
- Safe passage ("Good joss!")
- May drive off rival pirates (5% chance)

### Post-Combat Confiscation (iOS Only - currently)

**If Li Yuen fleet survives combat**:
- Seizes ALL opium cargo
- Demands 30-56% of cash
- Message: "You got off easy, Taipan!"
- Displayed via liYuenAlert

---

## Testing Checklist

### iOS v1.0.5

- [ ] Tribute offer appears in Hong Kong (5% chance, cash > ¥20k)
- [ ] Paying tribute grants protection
- [ ] Refusing tribute warns of danger
- [ ] Protection provides safe passage (8.3% encounter)
- [ ] No protection = attack (25% encounter, escalates with refusals)
- [ ] Refusal count increases encounter rate
- [ ] Post-combat confiscation if fleet survives
- [ ] Protection decays randomly (5% per sail)
- [ ] Save/load preserves all Li Yuen data
- [ ] Backward compatibility with old saves

### Perl v2.2.1

- [ ] Donation offer appears in Hong Kong (cash > ¥100, TR=0)
- [ ] Paying donation grants protection (TR=1)
- [ ] Refusing donation warns of danger
- [ ] Protection expires randomly (5% of voyages)
- [ ] Safe passage when protected (8.3% encounter)
- [ ] Attack without protection (25% encounter)
- [ ] Double damage from Li Yuen fleet
- [ ] Save/load preserves li_yuen_tribute flag

---

## Version Numbers

- **iOS**: v1.0.5 (Li Yuen Complete System)
- **Perl**: v2.2.1 (Sea Goddess Donation Added)

---

## Credits

- **Original Game**: Art Canfil (1979 TRS-80, 1982 Apple II)
- **Game Book**: Art Canfil, Jim McClenahan, Karl Albrecht (1986)
- **Research**: Archive.org (CC0 Public Domain book)
- **iOS Implementation**: Claude Code AI (2025)
- **Perl Implementation**: Michael Lavery + Claude Code AI (2020-2025)

---

## Notes

This implementation combines the best of all versions:
- **TRS-80 mechanics** (Sea Goddess donation system)
- **Apple II mechanics** (encounter rates, fleet sizes, damage)
- **Perl v1.0.0 mechanics** (post-combat confiscation)
- **iOS enhancement** (escalating refusal penalty system)

The result is the most complete Li Yuen implementation ever created for Taipan!
