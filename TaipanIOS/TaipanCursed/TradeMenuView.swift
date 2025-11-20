import SwiftUI

struct TradeMenuView: View {
    @ObservedObject var game: GameModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current prices
                Section {
                    VStack(spacing: 12) {
                        ForEach(["opium", "arms", "silk", "general"], id: \.self) { commodity in
                            CommodityRow(game: game, commodity: commodity)
                        }
                    }
                } header: {
                    Text("Current Prices - \(game.currentPort)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Cargo hold
                Section {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Cargo Hold")
                                .font(.headline)
                            Spacer()
                            Text("\(game.currentCargo)/\(game.cargoCapacity)")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        ForEach(["opium", "arms", "silk", "general"], id: \.self) { commodity in
                            if let amount = game.cargoHold[commodity], amount > 0 {
                                HStack {
                                    Text(commodity.capitalized)
                                    Spacer()
                                    Text("\(amount) units")
                                        .font(.system(.body, design: .monospaced))
                                }
                                .padding(.leading)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                } header: {
                    Text("Your Cargo")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Warehouse
                if let warehouse = game.warehouses[game.currentPort] {
                    Section {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Warehouse - \(game.currentPort)")
                                    .font(.headline)
                                Spacer()
                                Text("\(warehouse.total)/10000")
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            if warehouse.total > 0 {
                                ForEach(["opium", "arms", "silk", "general"], id: \.self) { commodity in
                                    let amount = warehouse.get(commodity)
                                    if amount > 0 {
                                        HStack {
                                            Text(commodity.capitalized)
                                            Spacer()
                                            Text("\(amount) units")
                                                .font(.system(.body, design: .monospaced))
                                        }
                                        .padding(.leading)
                                    }
                                }
                            } else {
                                Text("Empty")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    } header: {
                        Text("Warehouse")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }
}

struct CommodityRow: View {
    @ObservedObject var game: GameModel
    let commodity: String
    @State private var showingBuyDialog = false
    @State private var showingSellDialog = false
    @State private var showingStoreDialog = false
    @State private var showingRetrieveDialog = false
    
    var commodityInfo: Commodity? {
        game.commodities[commodity]
    }

    var currentPrice: Int {
        Int(game.getCurrentPrice(commodity: commodity) ?? 0)
    }
    
    var inCargo: Int {
        game.cargoHold[commodity] ?? 0
    }
    
    var inWarehouse: Int {
        game.warehouses[game.currentPort]?.get(commodity) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Commodity header
            HStack {
                Text(commodity.capitalized)
                    .font(.headline)
                Spacer()
                Text("¥\(currentPrice)")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
            }
            .padding()
            .background(commodityColor.opacity(0.3))
            
            // Action buttons
            HStack(spacing: 8) {
                // Buy
                Button(action: { showingBuyDialog = true }) {
                    Label("Buy", systemImage: "cart.fill.badge.plus")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                
                // Sell
                Button(action: { showingSellDialog = true }) {
                    Label("Sell", systemImage: "cart.fill.badge.minus")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(inCargo == 0)
                
                // Store
                Button(action: { showingStoreDialog = true }) {
                    Label("Store", systemImage: "archivebox.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(inCargo == 0)
                
                // Retrieve
                Button(action: { showingRetrieveDialog = true }) {
                    Label("Get", systemImage: "shippingbox.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(inWarehouse == 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Status row
            HStack {
                Text("Cargo: \(inCargo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Warehouse: \(inWarehouse)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .sheet(isPresented: $showingBuyDialog) {
            TransactionView(
                game: game,
                commodity: commodity,
                transactionType: .buy,
                isPresented: $showingBuyDialog
            )
        }
        .sheet(isPresented: $showingSellDialog) {
            TransactionView(
                game: game,
                commodity: commodity,
                transactionType: .sell,
                isPresented: $showingSellDialog
            )
        }
        .sheet(isPresented: $showingStoreDialog) {
            TransactionView(
                game: game,
                commodity: commodity,
                transactionType: .store,
                isPresented: $showingStoreDialog
            )
        }
        .sheet(isPresented: $showingRetrieveDialog) {
            TransactionView(
                game: game,
                commodity: commodity,
                transactionType: .retrieve,
                isPresented: $showingRetrieveDialog
            )
        }
    }
    
    var commodityColor: Color {
        switch commodity {
        case "opium": return .red
        case "arms": return .orange
        case "silk": return .purple
        case "general": return .blue
        default: return .gray
        }
    }
}

// MARK: - Transaction View

enum TransactionType {
    case buy, sell, store, retrieve
    
    var title: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        case .store: return "Store"
        case .retrieve: return "Retrieve"
        }
    }
}

struct TransactionView: View {
    @ObservedObject var game: GameModel
    let commodity: String
    let transactionType: TransactionType
    @Binding var isPresented: Bool
    @State private var amount = 1
    
    var maxAmount: Int {
        switch transactionType {
        case .buy:
            let price = game.getCurrentPrice(commodity: commodity) ?? 1
            let affordableAmount = Int(game.cash / price)
            let spaceAvailable = game.cargoCapacity - game.currentCargo
            return min(affordableAmount, spaceAvailable)
        case .sell:
            return game.cargoHold[commodity] ?? 0
        case .store:
            let inCargo = game.cargoHold[commodity] ?? 0
            let warehouseSpace = 10000 - (game.warehouses[game.currentPort]?.total ?? 0)
            return min(inCargo, warehouseSpace)
        case .retrieve:
            let inWarehouse = game.warehouses[game.currentPort]?.get(commodity) ?? 0
            let cargoSpace = game.cargoCapacity - game.currentCargo
            return min(inWarehouse, cargoSpace)
        }
    }

    var totalCost: Int {
        if transactionType == .buy || transactionType == .sell {
            let price = game.getCurrentPrice(commodity: commodity) ?? 0
            return Int(price * Double(amount))
        }
        return 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("\(transactionType.title) \(commodity.capitalized)")
                    .font(.title)
                    .fontWeight(.bold)
                
                if transactionType == .buy || transactionType == .sell {
                    VStack(spacing: 8) {
                        Text("Price: ¥\(Int(game.getCurrentPrice(commodity: commodity) ?? 0))")
                            .font(.headline)
                        
                        if transactionType == .buy {
                            Text("Available Cash: ¥\(Int(game.cash))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Cargo Space: \(game.cargoCapacity - game.currentCargo)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if maxAmount > 0 {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Amount:")
                            Spacer()
                            Text("\(amount)")
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(amount) },
                            set: { amount = Int($0) }
                        ), in: 1...Double(maxAmount), step: 1)
                        
                        HStack {
                            Button("1") { amount = 1 }
                            Button("25%") { amount = max(1, maxAmount / 4) }
                            Button("50%") { amount = max(1, maxAmount / 2) }
                            Button("75%") { amount = max(1, maxAmount * 3 / 4) }
                            Button("Max") { amount = maxAmount }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    
                    if totalCost > 0 {
                        Text("Total: ¥\(totalCost)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    Button(action: performTransaction) {
                        Text("\(transactionType.title) \(amount) \(commodity.capitalized)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Spacer()
                    Text("Cannot perform this transaction")
                        .font(.headline)
                        .foregroundColor(.red)
                    Spacer()
                }
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
    
    func performTransaction() {
        var success = false
        
        switch transactionType {
        case .buy:
            success = game.buyGoods(commodity, amount: amount)
        case .sell:
            success = game.sellGoods(commodity, amount: amount)
        case .store:
            success = game.storeGoods(commodity, amount: amount)
        case .retrieve:
            success = game.retrieveGoods(commodity, amount: amount)
        }
        
        if success {
            isPresented = false
        }
    }
}
