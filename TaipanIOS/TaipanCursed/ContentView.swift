import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameModel()
    @State private var showingWelcome = true
    @State private var showingRetirement = false
    @State private var retirementResult: RetirementResult?
    
    var body: some View {
        if showingWelcome {
            WelcomeView(game: game, showingWelcome: $showingWelcome)
        } else {
            GameView(game: game, showingRetirement: $showingRetirement, retirementResult: $retirementResult)
                .sheet(isPresented: $showingRetirement) {
                    if let result = retirementResult {
                        RetirementView(result: result, onNewGame: {
                            showingRetirement = false
                            showingWelcome = true
                        })
                    }
                }
        }
    }
}

struct GameView: View {
    @ObservedObject var game: GameModel
    @Binding var showingRetirement: Bool
    @Binding var retirementResult: RetirementResult?
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    // Status Bar
                    StatusBarView(game: game)
                        .padding()
                        .background(Color(.systemBackground))
                
                Divider()
                
                // Main Content
                TabView(selection: $selectedTab) {
                    ShipMenuView(game: game)
                        .tabItem {
                            Label("Ship", systemImage: "ferry")
                        }
                        .tag(0)
                    
                    TradeMenuView(game: game)
                        .tabItem {
                            Label("Trade", systemImage: "cart")
                        }
                        .tag(1)
                    
                    MoneyMenuView(game: game)
                        .tabItem {
                            Label("Money", systemImage: "dollarsign.circle")
                        }
                        .tag(2)
                    
                    SystemMenuView(game: game, showingRetirement: $showingRetirement, retirementResult: $retirementResult)
                        .tabItem {
                            Label("System", systemImage: "gear")
                        }
                        .tag(3)
                }
            }
            .navigationTitle("Taipan - \(game.firmName)")
            .navigationBarTitleDisplayMode(.inline)
            }

            // Combat overlay (full screen, black background with ASCII art)
            if game.showingCombat, let combat = game.combatState {
                CombatView(game: game, combat: combat)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
    }
}

// MARK: - Status Bar

struct StatusBarView: View {
    @ObservedObject var game: GameModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Top row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Firm: \(game.firmName)")
                        .font(.headline)
                    Text("Port: \(game.currentPort)")
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDate(game.gameDate))
                        .font(.headline)
                    Text("Ships: \(game.ships) | Guns: \(game.guns)")
                        .font(.subheadline)
                }
            }
            
            // Financial info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cash: ¥\(Int(game.cash))")
                        .font(.system(.body, design: .monospaced))
                    Text("Bank: ¥\(Int(game.bank))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Debt: ¥\(Int(game.debt))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(game.debt > 0 ? .red : .secondary)
                    Text("Net: ¥\(Int(game.netWorth))")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }
            }
            
            // Cargo info
            HStack {
                Text("Cargo: \(game.currentCargo)/\(game.cargoCapacity)")
                    .font(.subheadline)
                
                Spacer()
                
                if game.shipDamage > 0 {
                    Text("⚠️ Damage: \(Int(game.shipDamage * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            // Opium prices tracker
            OpiumTrackerView(game: game)
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

struct OpiumTrackerView: View {
    @ObservedObject var game: GameModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OPIUM PRICES")
                .font(.caption)
                .fontWeight(.bold)
            
            if let highest = game.getHighestOpiumPrice() {
                Text("High: \(highest.port) ¥\(Int(highest.price))")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            
            if let lowest = game.getLowestOpiumPrice() {
                Text("Low: \(lowest.port) ¥\(Int(lowest.price))")
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @ObservedObject var game: GameModel
    @Binding var showingWelcome: Bool
    @State private var firmName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("🚢 TAIPAN 🚢")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                
                Text("Trading Game of 1860s East Asia")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Name your firm:")
                        .font(.headline)
                    
                    TextField("Enter firm name", text: $firmName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        if !firmName.isEmpty {
                            game.firmName = firmName
                            showingWelcome = false
                        }
                    }) {
                        Text("Start Trading")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(firmName.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(firmName.isEmpty)
                }
                
                Spacer()
                
                Text("Build your empire across seven ports from Hong Kong to Batavia.\nTrade opium, arms, silk, and general cargo.\nBattle pirates and become a millionaire!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("Welcome Taipan")
        }
    }
}

// MARK: - Retirement View

struct RetirementView: View {
    let result: RetirementResult
    let onNewGame: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Text("⚓️ Retirement ⚓️")
                    .font(.system(size: 36, weight: .bold))
                
                VStack(spacing: 16) {
                    Text("Final Score: \(result.points) points")
                        .font(.title2)
                    
                    Text("Net Worth: ¥\(Int(result.netWorth))")
                        .font(.title3)
                    
                    if result.millionaire {
                        Text("🎉 MILLIONAIRE STATUS 🎉")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .padding()
                        
                        Text("The Emperor recognizes your achievement!")
                            .font(.headline)
                    }
                    
                    Text(result.rank)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                
                Spacer()
                
                Button(action: onNewGame) {
                    Text("New Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("Game Over")
        }
    }
}

#Preview {
    ContentView()
}
