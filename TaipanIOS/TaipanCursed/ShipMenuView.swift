import SwiftUI

struct ShipMenuView: View {
    @ObservedObject var game: GameModel
    @State private var showingSailDialog = false
    @State private var showingBuyShipDialog = false
    @State private var showingBuyGunsDialog = false
    @State private var gunsToBuy = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Sail To section
                Section {
                    Button(action: { showingSailDialog = true }) {
                        HStack {
                            Image(systemName: "ferry.fill")
                                .font(.title2)
                            Text("Sail To...")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } header: {
                    Text("Navigation")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Current location map
                PortMapView(game: game)
                
                // Ship management
                Section {
                    VStack(spacing: 12) {
                        // Buy Ship
                        Button(action: { showingBuyShipDialog = true }) {
                            let cost = calculateShipCost()
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Buy Ship")
                                Spacer()
                                Text("¥\(cost)")
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(game.cash >= Double(cost) ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(game.cash < Double(calculateShipCost()))
                        
                        // Buy Guns
                        Button(action: { showingBuyGunsDialog = true }) {
                            HStack {
                                Image(systemName: "scope")
                                Text("Buy Guns")
                                Spacer()
                                Text("¥\(Int(500 * game.ships)) ea")
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Repair Ship
                        if game.shipDamage > 0 {
                            Button(action: {
                                _ = game.repairShip()
                            }) {
                                HStack {
                                    Image(systemName: "wrench.fill")
                                    Text("Repair Ship")
                                    Spacer()
                                    Text("¥\(calculateRepairCost())")
                                        .font(.system(.body, design: .monospaced))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(game.cash >= Double(calculateRepairCost()) ? Color.red : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(game.cash < Double(calculateRepairCost()))
                        }
                    }
                } header: {
                    Text("Ship Management")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Ship status
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fleet Size:")
                            Spacer()
                            Text("\(game.ships) ships")
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Armament:")
                            Spacer()
                            Text("\(game.guns) guns")
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Cargo Capacity:")
                            Spacer()
                            Text("\(game.cargoCapacity) units")
                                .fontWeight(.bold)
                        }
                        
                        if game.shipDamage > 0 {
                            HStack {
                                Text("Damage:")
                                Spacer()
                                Text("\(Int(game.shipDamage * 100))%")
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                } header: {
                    Text("Fleet Status")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingSailDialog) {
            SailToView(game: game, isPresented: $showingSailDialog)
        }
        .alert("Buy Ship", isPresented: $showingBuyShipDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Buy for ¥\(calculateShipCost())") {
                _ = game.buyShip()
            }
        } message: {
            Text("Purchase a new ship to increase your cargo capacity by 60 units?")
        }
        .sheet(isPresented: $showingBuyGunsDialog) {
            BuyGunsView(game: game, isPresented: $showingBuyGunsDialog)
        }
    }
    
    func calculateShipCost() -> Int {
        let baseCost = 5000
        let gunPenalty = game.guns > 20 ? ((game.guns - 20) / 2) * 1000 : 0
        return baseCost + gunPenalty
    }
    
    func calculateRepairCost() -> Int {
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: game.gameDate, to: Date()).year ?? 0
        let cost = game.shipDamage * 1000 * Double(game.ships) * (1 + Double(years) * 0.1)
        return Int(cost)
    }
}

// MARK: - Sail To View

struct SailToView: View {
    @ObservedObject var game: GameModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List(game.ports.filter { $0.name != game.currentPort }) { port in
                Button(action: {
                    game.sailTo(port.name)
                    isPresented = false
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(port.name)
                                .font(.headline)
                            Text("Risk: \(Int(port.riskLevel * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if port.visited {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        // Show if warehouse has goods
                        if let warehouse = game.warehouses[port.name], warehouse.total > 0 {
                            Text("📦 \(warehouse.total)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Sail To")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Buy Guns View

struct BuyGunsView: View {
    @ObservedObject var game: GameModel
    @Binding var isPresented: Bool
    @State private var gunsToBuy = 1
    
    var costPerGun: Int {
        500 * game.ships
    }
    
    var totalCost: Int {
        costPerGun * gunsToBuy
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Buy Guns")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    Text("Cost per gun: ¥\(costPerGun)")
                        .font(.headline)
                    
                    Text("(\(game.ships) ships × ¥500)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Stepper("Guns to buy: \(gunsToBuy)", value: $gunsToBuy, in: 1...100)
                    .padding()
                
                Text("Total Cost: ¥\(totalCost)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Available Cash: ¥\(Int(game.cash))")
                    .font(.headline)
                    .foregroundColor(game.cash >= Double(totalCost) ? .green : .red)
                
                Spacer()
                
                Button(action: {
                    if game.buyGuns(gunsToBuy) {
                        isPresented = false
                    }
                }) {
                    Text("Purchase Guns")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(game.cash >= Double(totalCost) ? Color.orange : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(game.cash < Double(totalCost))
                .padding()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Port Map View

struct PortMapView: View {
    @ObservedObject var game: GameModel
    @State private var showASCIIMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Known World")
                    .font(.headline)

                Spacer()

                Button(action: {
                    showASCIIMap.toggle()
                }) {
                    Image(systemName: showASCIIMap ? "map.fill" : "map")
                        .foregroundColor(.blue)
                }
            }

            if showASCIIMap {
                // ASCII Map Display
                ASCIIMapView(currentPort: game.currentPort)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            } else {
                // Port Markers (original view)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(game.ports) { port in
                            PortMarker(port: port, isCurrent: port.name == game.currentPort, hasGoods: hasGoodsInWarehouse(port.name))
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }

    func hasGoodsInWarehouse(_ portName: String) -> Bool {
        if let warehouse = game.warehouses[portName] {
            return warehouse.total > 0
        }
        return false
    }
}

// MARK: - ASCII Map View

struct ASCIIMapView: View {
    let currentPort: String
    @State private var mapContent: String = ""

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(mapContent)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.green)
                .padding()
        }
        .frame(height: 200)
        .onAppear {
            loadMap()
        }
    }

    func loadMap() {
        // Map the current port to the appropriate map file number
        let mapNumber: Int
        switch currentPort {
        case "Hong Kong":
            mapNumber = 1
        case "Shanghai":
            mapNumber = 2
        case "Nagasaki":
            mapNumber = 3
        case "Manila":
            mapNumber = 4
        case "Saigon":
            mapNumber = 5
        case "Singapore":
            mapNumber = 6
        case "Batavia":
            mapNumber = 7
        default:
            mapNumber = 1
        }

        // Try to load the map file from the bundle
        if let filepath = Bundle.main.path(forResource: "ascii_taipan_map\(mapNumber)", ofType: "txt") {
            do {
                mapContent = try String(contentsOfFile: filepath, encoding: .utf8)
            } catch {
                mapContent = "Map file not found. Please ensure ascii_taipan_map\(mapNumber).txt is added to the Xcode project."
            }
        } else {
            mapContent = "Map file not found in bundle.\n\nTo add maps:\n1. In Xcode, select TaipanCursed folder\n2. Right-click → Add Files\n3. Select all ascii_taipan_map*.txt files\n4. Check 'Copy items if needed'\n5. Select TaipanCursed target"
        }
    }
}

struct PortMarker: View {
    let port: Port
    let isCurrent: Bool
    let hasGoods: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.blue : (port.visited ? Color.green : Color.gray))
                    .frame(width: 50, height: 50)
                
                if isCurrent {
                    Text("@")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else if hasGoods {
                    Text("*")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("○")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            Text(port.name)
                .font(.caption)
                .fontWeight(isCurrent ? .bold : .regular)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}
