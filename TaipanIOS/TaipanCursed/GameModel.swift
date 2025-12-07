import Foundation
import SwiftUI
import Combine

// MARK: - Game Data Structures

struct Commodity: Identifiable, Codable {
    let id: String
    var basePrice: Double
    var volatility: Double

    init(id: String, basePrice: Double, volatility: Double) {
        self.id = id
        self.basePrice = basePrice
        self.volatility = volatility
    }
}

struct CommodityPrice: Codable, Equatable {
    var price: Double
    var trend: Double
    var momentum: Double

    init(price: Double, trend: Double = 0.0, momentum: Double = 0.5) {
        self.price = price
        self.trend = trend
        self.momentum = momentum
    }
}

struct Port: Identifiable, Codable {
    let id: String
    let name: String
    let riskLevel: Double  // 0.0 to 1.0
    var visited: Bool = false
    
    static let allPorts = [
        Port(id: "hongkong", name: "Hong Kong", riskLevel: 0.05),
        Port(id: "shanghai", name: "Shanghai", riskLevel: 0.15),
        Port(id: "nagasaki", name: "Nagasaki", riskLevel: 0.08),
        Port(id: "saigon", name: "Saigon", riskLevel: 0.20),
        Port(id: "manila", name: "Manila", riskLevel: 0.12),
        Port(id: "batavia", name: "Batavia", riskLevel: 0.10),
        Port(id: "singapore", name: "Singapore", riskLevel: 0.06)
    ]
}

struct Warehouse: Codable {
    var opium: Int = 0
    var arms: Int = 0
    var silk: Int = 0
    var general: Int = 0
    var lastVisit: Date = Date()
    
    var total: Int {
        opium + arms + silk + general
    }
    
    mutating func add(_ commodity: String, amount: Int) {
        switch commodity {
        case "opium": opium += amount
        case "arms": arms += amount
        case "silk": silk += amount
        case "general": general += amount
        default: break
        }
    }
    
    mutating func remove(_ commodity: String, amount: Int) -> Bool {
        switch commodity {
        case "opium":
            if opium >= amount { opium -= amount; return true }
        case "arms":
            if arms >= amount { arms -= amount; return true }
        case "silk":
            if silk >= amount { silk -= amount; return true }
        case "general":
            if general >= amount { general -= amount; return true }
        default: break
        }
        return false
    }
    
    func get(_ commodity: String) -> Int {
        switch commodity {
        case "opium": return opium
        case "arms": return arms
        case "silk": return silk
        case "general": return general
        default: return 0
        }
    }
}

// MARK: - Game Model

class GameModel: ObservableObject {
    @Published var firmName: String = ""
    @Published var currentPort: String = "Hong Kong"
    @Published var cash: Double = 500.0
    @Published var bank: Double = 0.0
    @Published var debt: Double = 0.0
    @Published var portDebt: [String: Double] = [:]  // Per-port debt tracking (¥50k max per port)
    @Published var ships: Int = 1
    @Published var guns: Int = 1  // Player starts with 1 gun per ship
    @Published var shipDamage: Double = 0.0  // 0.0 to 1.0
    
    @Published var cargoHold: [String: Int] = [
        "opium": 0,
        "arms": 0,
        "silk": 0,
        "general": 0
    ]
    
    @Published var warehouses: [String: Warehouse] = [:]
    @Published var ports: [Port] = Port.allPorts
    @Published var commodities: [String: Commodity] = [:]

    // Per-port pricing: portPrices[portName][commodityName] = CommodityPrice
    @Published var portPrices: [String: [String: CommodityPrice]] = [:]
    
    @Published var gameDate: Date = {
        var components = DateComponents()
        components.year = 1860
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    let gameStartDate: Date = {
        var components = DateComponents()
        components.year = 1860
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    @Published var gameLog: [String] = []
    @Published var showingCombat: Bool = false
    @Published var combatState: CombatState?
    @Published var stormAlert: String?  // Storm message to display
    @Published var liYuenProtection: Bool = false  // LI flag - protection from tribute payments
    @Published var liYuenAlert: String?  // Li Yuen encounter message
    @Published var liYuenTributeDialog: LiYuenTributeOffer?  // Tribute request from representative
    @Published var liYuenTributesPaid: Int = 0  // Number of tributes paid
    @Published var liYuenRefusals: Int = 0  // Number of tributes refused (escalates danger)

    var cargoCapacity: Int {
        ships * 60
    }
    
    var currentCargo: Int {
        cargoHold.values.reduce(0, +)
    }
    
    var netWorth: Double {
        cash + bank - debt
    }
    
    init() {
        // Initialize commodities (base prices and volatility only)
        // Matches original Perl game values
        commodities = [
            "opium": Commodity(id: "opium", basePrice: 5000, volatility: 0.8),      // Range: 1000-9000
            "arms": Commodity(id: "arms", basePrice: 1500, volatility: 0.667),      // Range: 500-2500
            "silk": Commodity(id: "silk", basePrice: 370, volatility: 0.378),       // Range: 230-510
            "general": Commodity(id: "general", basePrice: 50, volatility: 0.3)     // Range: 35-65
        ]

        // Initialize warehouses for all ports
        for port in Port.allPorts {
            warehouses[port.name] = Warehouse()
        }

        // Initialize per-port prices
        generateInitialPrices()

        // Mark Hong Kong as visited
        if let index = ports.firstIndex(where: { $0.name == "Hong Kong" }) {
            ports[index].visited = true
        }
    }
    
    // MARK: - Price Generation

    func generateInitialPrices() {
        // Generate random starting prices for each port independently
        // Based on Perl logic for initial price distribution
        for port in Port.allPorts {
            var portCommodityPrices: [String: CommodityPrice] = [:]

            for (commodityName, commodity) in commodities {
                // Random initial price within volatility range (centered around base)
                let randomFactor = (Double.random(in: 0...1) - 0.5) * commodity.volatility
                let initialPrice = commodity.basePrice * (1 + randomFactor)

                // Initial trend direction (up or down)
                let direction: Double = Double.random(in: 0...1) < 0.5 ? -1 : 1

                // Initial momentum (0.3 to 0.7 range for moderate changes)
                let momentum = 0.3 + Double.random(in: 0...0.4)

                portCommodityPrices[commodityName] = CommodityPrice(
                    price: initialPrice,
                    trend: direction,
                    momentum: momentum
                )
            }

            portPrices[port.name] = portCommodityPrices
        }
    }

    func updatePrices() {
        // Update prices for each port independently with trend evolution
        // Based on original Perl logic for smooth, trending price movements
        for port in Port.allPorts {
            guard var portCommodityPrices = portPrices[port.name] else { continue }

            for (commodityName, commodity) in commodities {
                guard var priceInfo = portCommodityPrices[commodityName] else { continue }

                let currentPrice = priceInfo.price
                let direction = priceInfo.trend
                let momentum = priceInfo.momentum

                // Calculate price change based on trend
                // Small variation (1-5%) in the direction of the trend
                let changePercent = momentum * 0.05 * direction  // Max 5% change per update
                let noise = (Double.random(in: 0...1) - 0.5) * 0.02  // +/- 1% random noise
                let totalChange = changePercent + noise

                // Apply the change to CURRENT price (not base price)
                var newPrice = currentPrice * (1 + totalChange)

                // Keep prices within bounds based on volatility
                let minPrice = commodity.basePrice * (1 - commodity.volatility)
                let maxPrice = commodity.basePrice * (1 + commodity.volatility)

                // Reverse trend if hitting bounds (with bounce-back)
                if newPrice >= maxPrice {
                    newPrice = maxPrice
                    priceInfo.trend = -1  // Start going down
                    priceInfo.momentum = 0.4 + Double.random(in: 0...0.3)  // New momentum
                } else if newPrice <= minPrice {
                    newPrice = minPrice
                    priceInfo.trend = 1  // Start going up
                    priceInfo.momentum = 0.4 + Double.random(in: 0...0.3)  // New momentum
                } else {
                    // Occasionally reverse trend or change momentum (10% chance)
                    if Double.random(in: 0...1) < 0.1 {
                        priceInfo.trend *= -1  // Reverse direction
                        priceInfo.momentum = 0.3 + Double.random(in: 0...0.4)  // New momentum
                    }
                    // Otherwise momentum stays the same (no decay toward 0.5)
                }

                priceInfo.price = newPrice
                portCommodityPrices[commodityName] = priceInfo
            }

            portPrices[port.name] = portCommodityPrices
        }
    }

    // Helper to get current port's price for a commodity
    func getCurrentPrice(commodity: String) -> Double? {
        return portPrices[currentPort]?[commodity]?.price
    }
    
    // MARK: - Trading Functions

    func buyGoods(_ commodity: String, amount: Int) -> Bool {
        guard let price = getCurrentPrice(commodity: commodity) else { return false }
        let totalCost = price * Double(amount)

        if cash >= totalCost && (currentCargo + amount) <= cargoCapacity {
            cash -= totalCost
            cargoHold[commodity, default: 0] += amount
            addLog("Bought \(amount) \(commodity) for ¥\(Int(totalCost))")
            return true
        }
        return false
    }

    func sellGoods(_ commodity: String, amount: Int) -> Bool {
        guard let price = getCurrentPrice(commodity: commodity) else { return false }
        guard cargoHold[commodity, default: 0] >= amount else { return false }

        let totalValue = price * Double(amount)
        cash += totalValue
        cargoHold[commodity, default: 0] -= amount
        addLog("Sold \(amount) \(commodity) for ¥\(Int(totalValue))")
        return true
    }
    
    func storeGoods(_ commodity: String, amount: Int) -> Bool {
        guard cargoHold[commodity, default: 0] >= amount else { return false }
        
        if var warehouse = warehouses[currentPort] {
            if warehouse.total + amount <= 10000 {
                warehouse.add(commodity, amount: amount)
                warehouse.lastVisit = Date()
                warehouses[currentPort] = warehouse
                cargoHold[commodity, default: 0] -= amount
                addLog("Stored \(amount) \(commodity) in \(currentPort) warehouse")
                return true
            }
        }
        return false
    }
    
    func retrieveGoods(_ commodity: String, amount: Int) -> Bool {
        guard var warehouse = warehouses[currentPort] else { return false }
        guard (currentCargo + amount) <= cargoCapacity else { return false }
        
        if warehouse.remove(commodity, amount: amount) {
            warehouses[currentPort] = warehouse
            cargoHold[commodity, default: 0] += amount
            addLog("Retrieved \(amount) \(commodity) from warehouse")
            return true
        }
        return false
    }
    
    // MARK: - Banking
    
    func deposit(_ amount: Double) -> Bool {
        guard currentPort == "Hong Kong" else {
            addLog("⚠️ Banking services only in Hong Kong")
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
            addLog("⚠️ Banking services only in Hong Kong")
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
    
    func borrow(_ amount: Double) -> Bool {
        let maxDebtPerPort = 50000.0
        let portDebtAmount = portDebt[currentPort] ?? 0.0
        let availableCredit = maxDebtPerPort - portDebtAmount

        // Check if borrowing would exceed port limit
        if amount > availableCredit {
            return false
        }

        // Track debt both globally (for interest) and per-port (for borrowing limits)
        debt += amount
        cash += amount
        portDebt[currentPort] = portDebtAmount + amount

        addLog("Borrowed ¥\(Int(amount)) at 10% monthly interest in \(currentPort)")
        return true
    }
    
    func repayDebt(_ amount: Double) -> Bool {
        if amount <= cash && amount <= debt {
            cash -= amount
            debt -= amount

            // Pay down current port's debt first, then distribute to other ports
            var remainingPayment = amount
            let currentPortDebt = portDebt[currentPort] ?? 0.0

            if currentPortDebt > 0 {
                let portPayment = min(remainingPayment, currentPortDebt)
                portDebt[currentPort] = currentPortDebt - portPayment
                remainingPayment -= portPayment
            }

            // Distribute remaining payment across other ports with debt
            if remainingPayment > 0 {
                for (port, portDebtAmount) in portDebt where portDebtAmount > 0 && port != currentPort {
                    let portPayment = min(remainingPayment, portDebtAmount)
                    portDebt[port] = portDebtAmount - portPayment
                    remainingPayment -= portPayment
                    if remainingPayment <= 0 { break }
                }
            }

            // Clean up zero debt entries
            if debt <= 0 {
                portDebt.removeAll()
            }

            addLog("Repaid ¥\(Int(amount)) debt")
            return true
        }
        return false
    }
    
    func calculateInterestRate() -> Double {
        if bank >= 100000 { return 0.05 }
        else if bank >= 50000 { return 0.04 }
        else { return 0.03 }
    }
    
    // MARK: - Ship Management
    
    func buyShip() -> Bool {
        let baseCost = 5000.0
        let gunPenalty = guns > 20 ? Double((guns - 20) / 2) * 1000 : 0
        let cost = baseCost + gunPenalty
        
        if cash >= cost {
            cash -= cost
            ships += 1
            addLog("Purchased ship for ¥\(Int(cost))")
            return true
        }
        return false
    }
    
    func buyGuns(_ amount: Int) -> Bool {
        let costPerGun = 500.0 * Double(ships)
        let totalCost = costPerGun * Double(amount)
        
        if cash >= totalCost {
            cash -= totalCost
            guns += amount
            addLog("Purchased \(amount) guns for ¥\(Int(totalCost))")
            return true
        }
        return false
    }
    
    func repairShip() -> Bool {
        if shipDamage > 0 {
            let years = Calendar.current.dateComponents([.year], from: gameDate, to: Date()).year ?? 0
            let repairCost = shipDamage * 1000 * Double(ships) * (1 + Double(years) * 0.1)
            
            if cash >= repairCost {
                cash -= repairCost
                shipDamage = 0
                addLog("Repaired ships for ¥\(Int(repairCost))")
                return true
            }
        }
        return false
    }
    
    // MARK: - Travel
    
    func sailTo(_ destination: String) {
        // Apply warehouse spoilage for current port
        applyWarehouseSpoilage()

        // Random travel time
        let travelDays = Int.random(in: 5...15)
        advanceTime(days: travelDays)

        // Decay Li Yuen protection (5% chance per voyage)
        decayLiYuenProtection()

        // Random pirate encounter (1 in 9 chance)
        if Double.random(in: 0...1) < (1.0 / 9.0) {
            encounterPirates()
        }

        // Random storm encounter (10% chance) - Based on Perl v1.2.8 lines 3310-3340
        var finalDestination = destination
        if Double.random(in: 0...1) < 0.1 {
            finalDestination = handleStorm(intendedDestination: destination)
        }

        // Update current port
        currentPort = finalDestination
        if let index = ports.firstIndex(where: { $0.name == finalDestination }) {
            ports[index].visited = true
        }

        // Generate new prices
        updatePrices()

        // Random robbery if carrying too much cash
        if cash > 25000 && Double.random(in: 0...1) < 0.3 {
            let stolen = Double.random(in: 5000...15000)
            cash = max(0, cash - stolen)
            addLog("⚠️ Robbed! Lost ¥\(Int(stolen))")
        }

        addLog("Arrived at \(finalDestination) after \(travelDays) days")

        // Li Yuen representative may approach in Hong Kong
        checkForLiYuenRepresentative()

        // AUTO-SAVE after every voyage to slot 1
        autoSave()
    }

    // MARK: - Li Yuen Representative System

    func checkForLiYuenRepresentative() {
        // Only in Hong Kong
        guard currentPort == "Hong Kong" else { return }

        // Require significant cash to trigger (TRS-80 style)
        guard cash > 20000 else { return }

        // 5% chance when arriving with high cash
        guard Double.random(in: 0...1) < 0.05 else { return }

        // Calculate tribute amount (10-25% of cash)
        let tributePercent = Double.random(in: 0.10...0.25)
        let tributeAmount = Int(cash * tributePercent)

        let message = """
        🏴‍☠️ A VISITOR APPROACHES 🏴‍☠️

        A well-dressed man in dark silks steps from the shadows of the dock.

        "Greetings, Taipan. I represent... certain interests in these waters."

        He glances at your laden ships.

        "The Sea Goddess smiles upon those who show... gratitude. A donation of ¥\(tributeAmount) would ensure her continued favor."

        His eyes gleam in the lamplight.

        "Of course, the choice is yours. But the South China Sea can be... unpredictable... for those who refuse her blessings."
        """

        liYuenTributeDialog = LiYuenTributeOffer(amount: tributeAmount, message: message)
        addLog("🏴‍☠️ Li Yuen's representative approaches...")
    }

    func payLiYuenTribute(amount: Int) {
        guard cash >= Double(amount) else {
            addLog("⚠️ Insufficient cash for tribute")
            return
        }

        cash -= Double(amount)
        liYuenTributesPaid += 1
        liYuenProtection = true
        liYuenRefusals = max(0, liYuenRefusals - 1)  // Reduce refusal count

        addLog("💰 Paid ¥\(amount) tribute to Li Yuen")
        addLog("🏴‍☠️ Gained Li Yuen's protection")

        liYuenTributeDialog = nil
    }

    func refuseLiYuenTribute() {
        liYuenRefusals += 1
        liYuenProtection = false

        addLog("⚠️ Refused Li Yuen's tribute demand")
        addLog("💀 Li Yuen will remember this... (refusals: \(liYuenRefusals))")

        liYuenTributeDialog = nil
    }

    // Li Yuen post-combat confiscation (if player didn't destroy entire fleet)
    func applyLiYuenConfiscation(combat: CombatState) {
        // Only applies to Li Yuen encounters
        guard combat.isLiYuen else { return }

        // Only if pirates still remain
        guard combat.piratesRemaining > 0 else { return }

        let opiumSeized = cargoHold["opium"] ?? 0
        let cashDemanded = Int(cash * Double.random(in: 0.3...0.56))  // 30-56% of cash

        if opiumSeized > 0 || cashDemanded > 0 {
            var confiscationMessage = "🏴‍☠️ LI YUEN'S BOARDING PARTY 🏴‍☠️\n\n"
            confiscationMessage += "The remaining pirate ships close in. Li Yuen's men swarm aboard!\n\n"

            if opiumSeized > 0 {
                cargoHold["opium"] = 0
                confiscationMessage += "💀 They confiscate ALL your opium (\(opiumSeized) units)!\n\n"
                addLog("💀 Li Yuen seized \(opiumSeized) units of opium!")
            }

            if cashDemanded > 0 && cash >= Double(cashDemanded) {
                cash -= Double(cashDemanded)
                confiscationMessage += "💰 Li Yuen demands ¥\(cashDemanded) as tribute!\n\n"
                addLog("💰 Li Yuen demanded ¥\(cashDemanded) tribute!")
            }

            confiscationMessage += "'You got off easy, Taipan!' laughs Li Yuen's captain.\n\n"
            confiscationMessage += "The pirates withdraw to their ships and sail away."

            liYuenAlert = confiscationMessage
        }
    }

    // MARK: - Storm System

    func handleStorm(intendedDestination: String) -> String {
        var message = "🌊⛈️ STORM! ⛈️🌊\n\n"
        var actualDestination = intendedDestination

        // Calculate damage based on current ship damage (seaworthiness)
        // Original Perl formula: Damage increases risk of sinking
        let seaworthiness = 1.0 - shipDamage
        let stormDamage = Double.random(in: 0.1...0.3)  // Storm does 10-30% damage

        // Apply storm damage
        shipDamage = min(1.0, shipDamage + stormDamage)
        let newSeaworthiness = Int((1.0 - shipDamage) * 100)

        message += "Waves crash over the deck!\n"
        message += "Storm damage: \(Int(stormDamage * 100))%\n"
        message += "Seaworthiness: \(newSeaworthiness)%\n\n"

        // Check for sinking (based on new damage level)
        if shipDamage >= 0.8 {  // Critical damage
            // Calculate ships lost based on damage severity
            let sinkChance = (shipDamage - 0.8) / 0.2  // 0% at 80% damage, 100% at 100% damage
            let shipsAtRisk = ships

            if Double.random(in: 0...1) < sinkChance {
                // Partial or total fleet loss
                let shipsLost = Int.random(in: 1...max(1, ships))

                if shipsLost >= ships {
                    // TOTAL LOSS - Game Over
                    message += "💀 YOUR ENTIRE FLEET HAS SUNK! 💀\n\n"
                    message += "The storm was too powerful.\n"
                    message += "All hands lost at sea.\n\n"
                    message += "GAME OVER"
                    ships = 0
                    stormAlert = message
                    addLog("⚠️ FLEET SUNK IN STORM - GAME OVER")
                    return intendedDestination
                } else {
                    // PARTIAL LOSS
                    ships -= shipsLost
                    message += "⚠️ \(shipsLost) ship\(shipsLost == 1 ? "" : "s") lost to the storm!\n"
                    message += "\(ships) ship\(ships == 1 ? "" : "s") remain\(ships == 1 ? "s" : "").\n\n"

                    // Adjust cargo capacity
                    let newCapacity = ships * 60
                    if currentCargo > newCapacity {
                        // Must jettison cargo
                        let cargoLost = currentCargo - newCapacity
                        message += "Cargo lost overboard: \(cargoLost) units\n\n"

                        // Proportionally reduce cargo
                        var totalCargo = currentCargo
                        for (commodity, amount) in cargoHold {
                            let proportionalLoss = Int(Double(amount) / Double(totalCargo) * Double(cargoLost))
                            cargoHold[commodity] = max(0, amount - proportionalLoss)
                        }
                    }
                }
            }
        }

        // 33% chance of being blown off course
        if Double.random(in: 0...1) < 0.33 {
            // Random port (not current or intended destination)
            let availablePorts = ports.map { $0.name }.filter { $0 != currentPort && $0 != intendedDestination }
            if let randomPort = availablePorts.randomElement() {
                actualDestination = randomPort
                message += "🌀 BLOWN OFF COURSE! 🌀\n"
                message += "We've been driven to \(randomPort)!\n"
            }
        } else {
            message += "The storm subsides. We continue to \(intendedDestination).\n"
        }

        stormAlert = message
        addLog("⚠️ STORM! Damage: \(Int(stormDamage * 100))%, Seaworthiness: \(newSeaworthiness)%")

        return actualDestination
    }

    // MARK: - Combat

    func encounterPirates() {
        let holdCapacity = ships * 60  // SC = ship capacity

        // CHECK FOR LI YUEN ENCOUNTER with escalating refusal penalty
        // Base: LI=0 (no protection): 1-in-4 (25%) chance
        //       LI=1 (protection): 1-in-12 (8.3%) chance
        // Each refusal increases chance: +5% per refusal (max 50%)
        let baseChance = 4 + (liYuenProtection ? 8 : 0)

        // Calculate refusal penalty: each refusal reduces the denominator
        // Making Li Yuen MORE likely (smaller number = higher probability)
        let refusalPenalty = max(0, liYuenRefusals)
        let adjustedChance = max(2, baseChance - refusalPenalty)  // Minimum 1-in-2 (50%)

        let isLiYuen = Int.random(in: 0..<adjustedChance) == 0

        if isLiYuen {
            handleLiYuenEncounter(holdCapacity: holdCapacity)
            return
        }

        // NORMAL PIRATES (BASIC line 3120)
        // SN = FN R(SC / 10 + GN) + 1
        let maxPirates = (holdCapacity / 10) + guns
        let pirateFleet = Int.random(in: 1...max(1, maxPirates)) + 1

        combatState = CombatState(pirateCount: pirateFleet, isLiYuen: false)
        showingCombat = true
        addLog("⚠️ Pirates attacking! \(pirateFleet) ships approaching!")
    }

    func handleLiYuenEncounter(holdCapacity: Int) {
        if liYuenProtection {
            // SAFE PASSAGE (BASIC line 3220: "Good joss!! They let us be!!")
            let message = "🏴‍☠️ LI YUEN'S FLEET SIGHTED! 🏴‍☠️\n\n" +
                         "The legendary pirate lord's black sails loom on the horizon...\n\n" +
                         "But they recognize Elder Brother Wu's mark upon you.\n\n" +
                         "\"Good joss, Taipan! Pass safely.\"\n\n" +
                         "Li Yuen's fleet lets you be!"

            liYuenAlert = message
            addLog("🏴‍☠️ Li Yuen encounter - safe passage (Elder Brother Wu's protection)")
        } else {
            // ATTACK! (BASIC line 3230)
            // SN = FN R(SC / 5 + GN) + 5 (MUCH larger fleet than normal pirates!)
            // F1 = 2 (double damage!)
            let maxFleet = (holdCapacity / 5) + guns + 5
            let pirateFleet = Int.random(in: 5...max(5, maxFleet))

            combatState = CombatState(pirateCount: pirateFleet, isLiYuen: true)
            showingCombat = true

            addLog("💀 LI YUEN ATTACKING! \(pirateFleet) legendary pirate ships!")
        }
    }

    // BASIC line 2310: LI = LI AND FN R(20)
    // Protection decay - 5% chance (1-in-20) to lose Li Yuen protection
    func decayLiYuenProtection() {
        if liYuenProtection {
            if Int.random(in: 0..<20) == 0 {
                liYuenProtection = false
                addLog("⚠️ Li Yuen's protection has faded...")
            }
        }
    }

    // Process one round of combat based on player action
    func processCombatAction(_ action: CombatAction) {
        guard let combat = combatState else { return }

        combat.roundNumber += 1

        switch action {
        case .fight:
            executeFightRound(combat: combat)
        case .run:
            executeRunAttempt(combat: combat)
        case .throwCargo:
            executeThrowCargo(combat: combat)
        }

        // Check if combat should end
        if combat.allPiratesSunk {
            endCombatVictory(combat: combat)
        } else if combat.outcome != .ongoing {
            endCombat(combat: combat)
        }
    }

    private func executeFightRound(combat: CombatState) {
        // Calculate total firepower
        let totalFirepower = ships * guns

        if totalFirepower == 0 {
            combat.combatLog.append("No guns to fight with!")
            return
        }

        combat.combatLog.append("Round \(combat.roundNumber): FIGHT!")
        combat.combatLog.append("Firing \(totalFirepower) guns!")

        // Fire volleys and sink ships
        var sunkThisRound = 0

        for _ in 0..<totalFirepower {
            // Find a random non-sunk pirate ship
            let aliveIndices = combat.pirateShips.indices.filter { !combat.pirateShips[$0].sunk }
            guard let targetIndex = aliveIndices.randomElement() else { break }

            let damage = Int.random(in: 10...40)
            combat.pirateShips[targetIndex].takeDamage(damage)

            if combat.pirateShips[targetIndex].sunk {
                sunkThisRound += 1
            }
        }

        combat.shipsSunk += sunkThisRound

        if sunkThisRound > 0 {
            combat.combatLog.append("Sunk \(sunkThisRound) pirate ship\(sunkThisRound == 1 ? "" : "s")!")
        } else {
            combat.combatLog.append("Hit them but didn't sink any!")
        }

        // Enemy return fire if any pirates remain
        if !combat.allPiratesSunk {
            let piratesLeft = combat.piratesRemaining
            let edScaled = 0.5  // Damage severity

            // BASIC line 3230: F1 = 2 for Li Yuen (double damage!)
            let damageMultiplier = combat.isLiYuen ? 2.0 : 1.0

            let baseDamage = Int.random(in: 0...Int(edScaled * Double(piratesLeft)))
            let additionalDamage = piratesLeft / 2
            let damageTaken = Int(Double(baseDamage + additionalDamage) * damageMultiplier)

            shipDamage = min(1.0, shipDamage + (Double(damageTaken) / 100.0))
            combat.totalDamageTaken += damageTaken

            let seaworthiness = Int((1.0 - shipDamage) * 100)

            if combat.isLiYuen {
                combat.combatLog.append("⚠️ Li Yuen's pirates strike with legendary ferocity!")
            }
            combat.combatLog.append("Enemy return fire! Took \(damageTaken) damage")
            combat.combatLog.append("Seaworthiness: \(seaworthiness)%")

            // Check if we're sinking
            if shipDamage >= 1.0 {
                combat.outcome = .defeat
                combat.combatLog.append("YOUR FLEET IS SINKING!")
                // Game over handled in UI
            }
        }
    }

    private func executeRunAttempt(combat: CombatState) {
        combat.escapeAttempts += 1
        combat.combatLog.append("Round \(combat.roundNumber): Attempting to RUN!")

        // Original formula: OK and IK increase with each attempt
        combat.ok += combat.ik
        combat.ik += 1

        let playerEscapeValue = Double.random(in: 0...Double(combat.ok))
        let pirateChaseValue = Double.random(in: 0...Double(combat.piratesRemaining))

        if playerEscapeValue > pirateChaseValue {
            combat.outcome = .escaped
            combat.combatLog.append("Successfully escaped!")
            addLog("Escaped from pirates!")

            // Li Yuen post-combat confiscation (Perl v1.0.0 style)
            applyLiYuenConfiscation(combat: combat)
        } else {
            combat.combatLog.append("Couldn't lose them!")

            // Enemy attacks when run fails
            let piratesLeft = combat.piratesRemaining
            let edScaled = 0.5

            // BASIC line 3230: F1 = 2 for Li Yuen (double damage!)
            let damageMultiplier = combat.isLiYuen ? 2.0 : 1.0

            let baseDamage = Int.random(in: 0...Int(edScaled * Double(piratesLeft)))
            let additionalDamage = piratesLeft / 2
            let damageTaken = Int(Double(baseDamage + additionalDamage) * damageMultiplier)

            shipDamage = min(1.0, shipDamage + (Double(damageTaken) / 100.0))
            combat.totalDamageTaken += damageTaken

            let seaworthiness = Int((1.0 - shipDamage) * 100)

            if combat.isLiYuen {
                combat.combatLog.append("⚠️ Li Yuen's pirates strike with legendary ferocity!")
            }
            combat.combatLog.append("They fired on us! Took \(damageTaken) damage")
            combat.combatLog.append("Seaworthiness: \(seaworthiness)%")

            // Check if we're sinking
            if shipDamage >= 1.0 {
                combat.outcome = .defeat
                combat.combatLog.append("YOUR FLEET IS SINKING!")
            }
        }
    }

    private func executeThrowCargo(combat: CombatState) {
        let thrownAmount = currentCargo / 3

        if thrownAmount > 0 {
            for (key, _) in cargoHold {
                cargoHold[key] = (cargoHold[key, default: 0] * 2) / 3
            }
            combat.outcome = .threwCargo
            combat.combatLog.append("Threw \(thrownAmount) units of cargo overboard")
            combat.combatLog.append("Pirates are satisfied and leave")
            addLog("Threw \(thrownAmount) cargo to appease pirates")
        } else {
            combat.combatLog.append("No cargo to throw!")
        }
    }

    private func endCombatVictory(combat: CombatState) {
        combat.outcome = .victory

        // Calculate booty based on original formula
        // BT = FN R(TI / 4 * 1000 * SN ^ 1.05) + FN R(1000) + 250
        // Li Yuen gives 2x booty!
        let months = max(1, calculateMonthsSince1860())
        let bootyBase = Double(months) / 4.0 * 1000.0 * pow(Double(ships), 1.05)
        let bootyMultiplier = combat.isLiYuen ? 2.0 : 1.0
        let booty = Int(Double(Int(Double.random(in: 0...bootyBase)) + Int.random(in: 0...1000) + 250) * bootyMultiplier)

        cash += Double(booty)
        combat.booty = booty

        if combat.isLiYuen {
            combat.combatLog.append("💰 LEGENDARY VICTORY!")
            combat.combatLog.append("Defeated Li Yuen's fleet!")
            combat.combatLog.append("Earned ¥\(booty) in treasure (2x for Li Yuen!)")
            addLog("💰 Defeated Li Yuen! Legendary treasure: ¥\(booty)")
        } else {
            combat.combatLog.append("VICTORY! All pirates defeated!")
            combat.combatLog.append("Earned ¥\(booty) in booty")
            addLog("⚔️ Victory! Earned ¥\(booty) in booty")
        }
    }

    private func endCombat(combat: CombatState) {
        combat.isActive = false

        if combat.outcome == .defeat {
            // Lose half the cargo
            let lostCargo = currentCargo / 2
            for (key, _) in cargoHold {
                cargoHold[key] = cargoHold[key, default: 0] / 2
            }
            addLog("💀 Defeated! Lost \(lostCargo) cargo")
        }
    }

    private func calculateMonthsSince1860() -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: gameDate)
        let month = calendar.component(.month, from: gameDate)
        return (year - 1860) * 12 + (month - 1)
    }
    
    // MARK: - Time Management
    
    func advanceTime(days: Int) {
        gameDate = Calendar.current.date(byAdding: .day, value: days, to: gameDate) ?? gameDate

        // Apply debt interest monthly
        if debt > 0 {
            debt = debt * 1.10  // 10% monthly
        }

        // Apply bank interest monthly
        if bank > 0 {
            let monthlyRate = calculateInterestRate() / 12.0
            bank = bank * (1 + monthlyRate)
        }
    }
    
    func applyWarehouseSpoilage() {
        guard var warehouse = warehouses[currentPort] else { return }
        
        let daysSinceLastVisit = Calendar.current.dateComponents([.day], from: warehouse.lastVisit, to: gameDate).day ?? 0
        
        if daysSinceLastVisit > 60 {
            let portRisk = ports.first(where: { $0.name == currentPort })?.riskLevel ?? 0.1
            let spoilageRate = portRisk * Double(daysSinceLastVisit - 60) / 100.0
            
            let opiumLost = Int(Double(warehouse.opium) * spoilageRate)
            let armsLost = Int(Double(warehouse.arms) * spoilageRate)
            let silkLost = Int(Double(warehouse.silk) * spoilageRate)
            let generalLost = Int(Double(warehouse.general) * spoilageRate)
            
            warehouse.opium -= opiumLost
            warehouse.arms -= armsLost
            warehouse.silk -= silkLost
            warehouse.general -= generalLost
            
            warehouses[currentPort] = warehouse
            
            let totalLost = opiumLost + armsLost + silkLost + generalLost
            if totalLost > 0 {
                addLog("⚠️ Warehouse spoilage: Lost \(totalLost) goods in \(currentPort)")
            }
        }
    }
    
    func addLog(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let dateStr = dateFormatter.string(from: gameDate)
        gameLog.insert("[\(dateStr)] \(message)", at: 0)
        if gameLog.count > 50 {
            gameLog.removeLast()
        }
    }
    
    // MARK: - Retirement
    
    func retire() -> RetirementResult {
        let points = Int(netWorth / 100)
        
        let rank: String
        if points >= 50000 {
            rank = "Ma Tsu - Living legend of the high seas!"
        } else if points >= 8000 {
            rank = "Master Taipan - Your name echoes through trading houses"
        } else if points >= 1000 {
            rank = "Taipan - Respected merchant prince"
        } else if points >= 500 {
            rank = "Compradore - Successful trader"
        } else {
            rank = "Galley Hand - Perhaps find another career..."
        }
        
        let millionaire = netWorth >= 1_000_000
        
        return RetirementResult(rank: rank, points: points, netWorth: netWorth, millionaire: millionaire)
    }
    
    // MARK: - Save/Load

    // Get App Support directory for save slots
    private func getAppSupportDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let gameDir = appSupport.appendingPathComponent("TaipanSaves")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)

        return gameDir
    }

    // Save to specific slot (1-4)
    func saveToSlot(_ slot: Int) throws {
        guard slot >= 1 && slot <= 4 else {
            throw SaveError.invalidSlot
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let saveData = SaveData(
            firmName: firmName,
            currentPort: currentPort,
            cash: cash,
            bank: bank,
            debt: debt,
            portDebt: portDebt,
            ships: ships,
            guns: guns,
            shipDamage: shipDamage,
            cargoHold: cargoHold,
            warehouses: warehouses,
            ports: ports,
            commodities: commodities,
            gameDate: gameDate,
            gameLog: gameLog,
            liYuenProtection: liYuenProtection,
            liYuenTributesPaid: liYuenTributesPaid,
            liYuenRefusals: liYuenRefusals
        )

        let data = try encoder.encode(saveData)

        let saveDir = getAppSupportDirectory()
        let filename = "savegame\(slot).json"
        let fileURL = saveDir.appendingPathComponent(filename)

        try data.write(to: fileURL)
        addLog("Saved to Slot \(slot)")
    }

    // Load from specific slot (1-4)
    func loadFromSlot(_ slot: Int) throws {
        guard slot >= 1 && slot <= 4 else {
            throw SaveError.invalidSlot
        }

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

        self.firmName = saveData.firmName
        self.currentPort = saveData.currentPort
        self.cash = saveData.cash
        self.bank = saveData.bank
        self.debt = saveData.debt
        self.portDebt = saveData.portDebt ?? [:]
        self.ships = saveData.ships
        self.guns = saveData.guns
        self.shipDamage = saveData.shipDamage
        self.cargoHold = saveData.cargoHold
        self.warehouses = saveData.warehouses
        self.ports = saveData.ports
        self.commodities = saveData.commodities
        self.gameDate = saveData.gameDate
        self.gameLog = saveData.gameLog
        self.liYuenProtection = saveData.liYuenProtection ?? false
        self.liYuenTributesPaid = saveData.liYuenTributesPaid ?? 0
        self.liYuenRefusals = saveData.liYuenRefusals ?? 0

        addLog("Loaded from Slot \(slot)")
    }

    // Auto-save to slot 1 after every sail
    func autoSave() {
        do {
            try saveToSlot(1)
        } catch {
            addLog("⚠️ Auto-save failed: \(error.localizedDescription)")
        }
    }

    // Check if slot has save data
    func slotHasSave(_ slot: Int) -> Bool {
        let saveDir = getAppSupportDirectory()
        let filename = "savegame\(slot).json"
        let fileURL = saveDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // Get slot info (firm name and date)
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

    // Old save function - kept for backward compatibility
    func saveGame() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let saveData = SaveData(
            firmName: firmName,
            currentPort: currentPort,
            cash: cash,
            bank: bank,
            debt: debt,
            portDebt: portDebt,
            ships: ships,
            guns: guns,
            shipDamage: shipDamage,
            cargoHold: cargoHold,
            warehouses: warehouses,
            ports: ports,
            commodities: commodities,
            gameDate: gameDate,
            gameLog: gameLog,
            liYuenProtection: liYuenProtection,
            liYuenTributesPaid: liYuenTributesPaid,
            liYuenRefusals: liYuenRefusals
        )
        
        let data = try encoder.encode(saveData)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "\(firmName)_\(dateFormatter.string(from: Date())).json"
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        try data.write(to: fileURL)
        
        addLog("Game saved: \(filename)")
    }
    
    func loadGame(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let saveData = try decoder.decode(SaveData.self, from: data)
        
        self.firmName = saveData.firmName
        self.currentPort = saveData.currentPort
        self.cash = saveData.cash
        self.bank = saveData.bank
        self.debt = saveData.debt
        self.portDebt = saveData.portDebt ?? [:]  // Backward compatibility - defaults to empty
        self.ships = saveData.ships
        self.guns = saveData.guns
        self.shipDamage = saveData.shipDamage
        self.cargoHold = saveData.cargoHold
        self.warehouses = saveData.warehouses
        self.ports = saveData.ports
        self.commodities = saveData.commodities
        self.gameDate = saveData.gameDate
        self.gameLog = saveData.gameLog
        self.liYuenProtection = saveData.liYuenProtection ?? false  // Backward compatibility - defaults to no protection

        addLog("Game loaded")
    }
    
    func getHighestOpiumPrice() -> (port: String, price: Double)? {
        var highest: (String, Double)? = nil

        for port in Port.allPorts {
            if let opiumPrice = portPrices[port.name]?["opium"]?.price {
                if highest == nil || opiumPrice > highest!.1 {
                    highest = (port.name, opiumPrice)
                }
            }
        }

        return highest
    }

    func getLowestOpiumPrice() -> (port: String, price: Double)? {
        var lowest: (String, Double)? = nil

        for port in Port.allPorts {
            if let opiumPrice = portPrices[port.name]?["opium"]?.price {
                if lowest == nil || opiumPrice < lowest!.1 {
                    lowest = (port.name, opiumPrice)
                }
            }
        }

        return lowest
    }
}

// MARK: - Supporting Structures

// Combat state for multi-round combat
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

    // Escape progression variables (from original game)
    var ok: Int = 0
    var ik: Int = 0

    // Li Yuen flag (BASIC F1 = 2 for double damage)
    let isLiYuen: Bool

    init(pirateCount: Int, isLiYuen: Bool = false) {
        self.isLiYuen = isLiYuen
        self.pirateShips = (0..<pirateCount).map { _ in
            PirateShip(health: Int.random(in: 20...50))
        }
    }

    var piratesRemaining: Int {
        pirateShips.filter { !$0.sunk }.count
    }

    var allPiratesSunk: Bool {
        piratesRemaining == 0
    }
}

struct PirateShip: Identifiable {
    let id = UUID()
    var health: Int
    var sunk: Bool = false

    mutating func takeDamage(_ damage: Int) {
        health -= damage
        if health <= 0 {
            sunk = true
        }
    }
}

enum CombatOutcome: Equatable {
    case ongoing
    case victory
    case defeat
    case escaped
    case threwCargo
}

enum CombatAction {
    case fight
    case run
    case throwCargo
}

struct RetirementResult {
    let rank: String
    let points: Int
    let netWorth: Double
    let millionaire: Bool
}

struct LiYuenTributeOffer {
    let amount: Int
    let message: String
}

enum SaveError: Error {
    case invalidSlot
    case slotEmpty
    case encodingFailed
    case decodingFailed
}

struct SaveData: Codable {
    let firmName: String
    let currentPort: String
    let cash: Double
    let bank: Double
    let debt: Double
    let portDebt: [String: Double]?  // Optional for backward compatibility
    let ships: Int
    let guns: Int
    let shipDamage: Double
    let cargoHold: [String: Int]
    let warehouses: [String: Warehouse]
    let ports: [Port]
    let commodities: [String: Commodity]
    let gameDate: Date
    let gameLog: [String]
    let liYuenProtection: Bool?  // Optional for backward compatibility
    let liYuenTributesPaid: Int?  // Optional for backward compatibility
    let liYuenRefusals: Int?  // Optional for backward compatibility
}