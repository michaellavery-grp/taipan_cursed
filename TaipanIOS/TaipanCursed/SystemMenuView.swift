import SwiftUI
import UniformTypeIdentifiers

struct SystemMenuView: View {
    @ObservedObject var game: GameModel
    @Binding var showingRetirement: Bool
    @Binding var retirementResult: RetirementResult?
    @State private var showingSaveAlert = false
    @State private var showingLoadPicker = false
    @State private var showingRetireConfirm = false
    @State private var showingGameLog = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Game info
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Firm Name:")
                            Spacer()
                            Text(game.firmName)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Current Port:")
                            Spacer()
                            Text(game.currentPort)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Game Date:")
                            Spacer()
                            Text(formatDate(game.gameDate))
                                .fontWeight(.bold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Net Worth:")
                            Spacer()
                            Text("¥\(Int(game.netWorth))")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(game.netWorth >= 1_000_000 ? .yellow : .primary)
                        }
                        
                        if game.netWorth >= 1_000_000 {
                            Text("🎉 MILLIONAIRE STATUS 🎉")
                                .font(.headline)
                                .foregroundColor(.yellow)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                } header: {
                    Text("Game Information")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Actions
                Section {
                    VStack(spacing: 12) {
                        // Save Game
                        Button(action: {
                            do {
                                try game.saveGame()
                                showingSaveAlert = true
                            } catch {
                                print("Error saving: \(error)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.title2)
                                Text("Save Game")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Load Game
                        Button(action: { showingLoadPicker = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .font(.title2)
                                Text("Load Game")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Game Log
                        Button(action: { showingGameLog = true }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                Text("Game Log")
                                    .font(.headline)
                                Spacer()
                                Text("\(game.gameLog.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Retire
                        Button(action: { showingRetireConfirm = true }) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .font(.title2)
                                Text("Retire")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                } header: {
                    Text("System Actions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Statistics
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fleet Statistics")
                            .font(.headline)
                        
                        HStack {
                            Text("Total Ships:")
                            Spacer()
                            Text("\(game.ships)")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Total Guns:")
                            Spacer()
                            Text("\(game.guns)")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Cargo Capacity:")
                            Spacer()
                            Text("\(game.cargoCapacity) units")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Divider()
                        
                        Text("Trading Statistics")
                            .font(.headline)
                        
                        HStack {
                            Text("Ports Visited:")
                            Spacer()
                            Text("\(game.ports.filter { $0.visited }.count)/7")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Days Elapsed:")
                            Spacer()
                            let days = Calendar.current.dateComponents([.day], from: game.gameStartDate, to: game.gameDate).day ?? 0
                            Text("\(days)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                } header: {
                    Text("Statistics")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // About
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Taipan")
                            .font(.headline)
                        
                        Text("A trading game set in 1860s East Asia. Build your merchant empire by trading commodities, battling pirates, and managing your finances.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Text("Original game by Art Canfil (1982)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Perl Curses::UI version by Michael Lavery (2020-2025)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("iOS version 2025 by Claude Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .alert("Game Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your game has been saved successfully.")
        }
        .alert("Retire from Trading?", isPresented: $showingRetireConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Retire", role: .destructive) {
                retirementResult = game.retire()
                showingRetirement = true
            }
        } message: {
            Text("Are you ready to hang up your trading hat and see how you've fared?\n\nCurrent Net Worth: ¥\(Int(game.netWorth))")
        }
        .sheet(isPresented: $showingGameLog) {
            GameLogView(game: game)
        }
        .sheet(isPresented: $showingLoadPicker) {
            DocumentPicker(game: game, isPresented: $showingLoadPicker)
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Game Log View

struct GameLogView: View {
    @ObservedObject var game: GameModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(game.gameLog, id: \.self) { entry in
                Text(entry)
                    .font(.system(.caption, design: .monospaced))
            }
            .navigationTitle("Game Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var game: GameModel
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            do {
                try parent.game.loadGame(from: url)
                parent.isPresented = false
            } catch {
                print("Error loading game: \(error)")
            }
        }
    }
}
