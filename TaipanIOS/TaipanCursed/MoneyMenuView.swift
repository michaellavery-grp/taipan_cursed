import SwiftUI

struct MoneyMenuView: View {
    @ObservedObject var game: GameModel
    @State private var showingDepositDialog = false
    @State private var showingWithdrawDialog = false
    @State private var showingBorrowDialog = false
    @State private var showingRepayDialog = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Bank header
                Section {
                    VStack(spacing: 12) {
                        Text("Hong Kong & Shanghai Banking Corporation")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cash:")
                                    .font(.subheadline)
                                Text("¥\(Int(game.cash))")
                                    .font(.system(.title2, design: .monospaced))
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("Bank Balance:")
                                    .font(.subheadline)
                                Text("¥\(Int(game.bank))")
                                    .font(.system(.title2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if game.debt > 0 {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Debt:")
                                        .font(.subheadline)
                                    Text("¥\(Int(game.debt))")
                                        .font(.system(.title2, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Interest Rate:")
                                        .font(.subheadline)
                                    Text("10% Monthly")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Net Worth:")
                                .font(.headline)
                            Spacer()
                            Text("¥\(Int(game.netWorth))")
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(game.netWorth >= 0 ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                // Banking operations
                Section {
                    VStack(spacing: 12) {
                        // Deposit
                        Button(action: { showingDepositDialog = true }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title2)
                                Text("Deposit")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(game.calculateInterestRate() * 100))% APR")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(game.cash <= 0)
                        
                        // Withdraw
                        Button(action: { showingWithdrawDialog = true }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                Text("Withdraw")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(game.bank <= 0)
                        
                        // Borrow
                        Button(action: { showingBorrowDialog = true }) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .font(.title2)
                                Text("Borrow Money")
                                    .font(.headline)
                                Spacer()
                                Text("10% Monthly")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Repay
                        if game.debt > 0 {
                            Button(action: { showingRepayDialog = true }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                    Text("Repay Debt")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(game.cash <= 0)
                        }
                    }
                } header: {
                    Text("Banking Operations")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Interest information
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interest Rates")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Savings (Annual):")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("• < ¥50,000: 3%")
                                .font(.caption)
                            Text("• ¥50,000 - ¥99,999: 4%")
                                .font(.caption)
                            Text("• ≥ ¥100,000: 5%")
                                .font(.caption)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debt (Monthly):")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("• All debt: 10% compounding monthly")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if game.debt > 0 {
                            Divider()
                            
                            Text("⚠️ Brother Wu warns: Your debt is growing at 10% per month! Pay it down quickly!")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingDepositDialog) {
            MoneyTransactionView(
                game: game,
                transactionType: .deposit,
                isPresented: $showingDepositDialog
            )
        }
        .sheet(isPresented: $showingWithdrawDialog) {
            MoneyTransactionView(
                game: game,
                transactionType: .withdraw,
                isPresented: $showingWithdrawDialog
            )
        }
        .sheet(isPresented: $showingBorrowDialog) {
            MoneyTransactionView(
                game: game,
                transactionType: .borrow,
                isPresented: $showingBorrowDialog
            )
        }
        .sheet(isPresented: $showingRepayDialog) {
            MoneyTransactionView(
                game: game,
                transactionType: .repay,
                isPresented: $showingRepayDialog
            )
        }
    }
}

// MARK: - Money Transaction View

enum MoneyTransactionType {
    case deposit, withdraw, borrow, repay
    
    var title: String {
        switch self {
        case .deposit: return "Deposit"
        case .withdraw: return "Withdraw"
        case .borrow: return "Borrow"
        case .repay: return "Repay Debt"
        }
    }
    
    var color: Color {
        switch self {
        case .deposit: return .green
        case .withdraw: return .blue
        case .borrow: return .orange
        case .repay: return .red
        }
    }
}

struct MoneyTransactionView: View {
    @ObservedObject var game: GameModel
    let transactionType: MoneyTransactionType
    @Binding var isPresented: Bool
    @State private var amount = 100.0
    
    var maxAmount: Double {
        switch transactionType {
        case .deposit:
            return game.cash
        case .withdraw:
            return game.bank
        case .borrow:
            return 50000.0 // Reasonable borrowing limit
        case .repay:
            return min(game.cash, game.debt)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(transactionType.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 8) {
                    switch transactionType {
                    case .deposit:
                        Text("Available Cash: ¥\(Int(game.cash))")
                            .font(.headline)
                        Text("Current Interest Rate: \(Int(game.calculateInterestRate() * 100))% APR")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    case .withdraw:
                        Text("Bank Balance: ¥\(Int(game.bank))")
                            .font(.headline)
                    case .borrow:
                        Text("Interest Rate: 10% Monthly (Compounding)")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("⚠️ Debt grows quickly!")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    case .repay:
                        Text("Current Debt: ¥\(Int(game.debt))")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("Available Cash: ¥\(Int(game.cash))")
                            .font(.subheadline)
                    }
                }
                
                if maxAmount > 0 {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Amount:")
                            Spacer()
                            Text("¥\(Int(amount))")
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                        }
                        
                        Slider(value: $amount, in: 100...maxAmount, step: 100)
                        
                        HStack {
                            Button("¥100") { amount = 100 }
                            Button("¥1K") { amount = min(1000, maxAmount) }
                            Button("¥5K") { amount = min(5000, maxAmount) }
                            Button("¥10K") { amount = min(10000, maxAmount) }
                            Button("Max") { amount = maxAmount }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button(action: performTransaction) {
                        Text("\(transactionType.title) ¥\(Int(amount))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(transactionType.color)
                            .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Spacer()
                    Text("No funds available")
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
        case .deposit:
            success = game.deposit(amount)
        case .withdraw:
            success = game.withdraw(amount)
        case .borrow:
            success = game.borrow(amount)
        case .repay:
            success = game.repayDebt(amount)
        }
        
        if success {
            isPresented = false
        }
    }
}
