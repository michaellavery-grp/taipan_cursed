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
        if amount <= cash {
            cash -= amount
            bank += amount
            addLog("Deposited ¥\(Int(amount))")
            return true
        }
        return false
    }
    
    func withdraw(_ amount: Double) -> Bool {
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
        
        // Random pirate encounter (1 in 9 chance)
        if Double.random(in: 0...1) < (1.0 / 9.0) {
            encounterPirates()
        }
        
        // Update current port
        currentPort = destination
        if let index = ports.firstIndex(where: { $0.name == destination }) {
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
        
        addLog("Arrived at \(destination) after \(travelDays) days")
    }
    
    // MARK: - Combat

    func encounterPirates() {
        let pirateFleet = Int.random(in: 5...20)  // More pirates for realism
        combatState = CombatState(pirateCount: pirateFleet)
        showingCombat = true
        addLog("⚠️ Pirates attacking! \(pirateFleet) ships approaching!")
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
            let baseDamage = Int.random(in: 0...Int(edScaled * Double(piratesLeft)))
            let additionalDamage = piratesLeft / 2
            let damageTaken = baseDamage + additionalDamage

            shipDamage = min(1.0, shipDamage + (Double(damageTaken) / 100.0))
            combat.totalDamageTaken += damageTaken

            let seaworthiness = Int((1.0 - shipDamage) * 100)
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
        } else {
            combat.combatLog.append("Couldn't lose them!")

            // Enemy attacks when run fails
            let piratesLeft = combat.piratesRemaining
            let edScaled = 0.5
            let baseDamage = Int.random(in: 0...Int(edScaled * Double(piratesLeft)))
            let additionalDamage = piratesLeft / 2
            let damageTaken = baseDamage + additionalDamage

            shipDamage = min(1.0, shipDamage + (Double(damageTaken) / 100.0))
            combat.totalDamageTaken += damageTaken

            let seaworthiness = Int((1.0 - shipDamage) * 100)
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
        let months = max(1, calculateMonthsSince1860())
        let bootyBase = Double(months) / 4.0 * 1000.0 * pow(Double(ships), 1.05)
        let booty = Int(Double.random(in: 0...bootyBase)) + Int.random(in: 0...1000) + 250

        cash += Double(booty)
        combat.booty = booty
        combat.combatLog.append("VICTORY! All pirates defeated!")
        combat.combatLog.append("Earned ¥\(booty) in booty")
        addLog("⚔️ Victory! Earned ¥\(booty) in booty")
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
            gameLog: gameLog
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

    init(pirateCount: Int) {
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
}