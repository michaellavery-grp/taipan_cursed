import SwiftUI

struct CombatView: View {
    @ObservedObject var game: GameModel
    @ObservedObject var combat: CombatState
    @State private var animationState: AnimationState = .idle
    @State private var showingBlast: Bool = false
    @State private var blastPositions: [Int] = []
    @State private var sinkingShips: [Int] = []
    @State private var lorchaFlashColor: Color = .red
    @State private var isFlashing: Bool = false

    enum AnimationState {
        case idle
        case firing
        case sinking
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Combat arena - top 2/3 of screen
                ZStack {
                    Color.black

                    VStack(spacing: 20) {
                        // Top row of pirate ships (5 ships)
                        HStack(spacing: 15) {
                            ForEach(0..<5) { index in
                                lorchaView(at: index)
                            }
                        }
                        .padding(.top, 40)

                        // Bottom row of pirate ships (5 ships)
                        HStack(spacing: 15) {
                            ForEach(5..<10) { index in
                                lorchaView(at: index)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // Combat log and controls - bottom 1/3
                VStack(spacing: 12) {
                    // Status line
                    HStack {
                        Text("Round: \(combat.roundNumber)")
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("Pirates: \(combat.piratesRemaining)")
                            .foregroundColor(.red)
                        Spacer()
                        Text("Seaworthiness: \(Int((1.0 - game.shipDamage) * 100))%")
                            .foregroundColor(seaworthinessColor)
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal)

                    // Combat log (last 4 messages)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(combat.combatLog.suffix(4), id: \.self) { message in
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .frame(height: 80)

                    // Action buttons
                    if combat.isActive && combat.outcome == .ongoing {
                        HStack(spacing: 20) {
                            // Fight button
                            Button(action: {
                                withAnimation {
                                    animationState = .firing
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    game.processCombatAction(.fight)
                                    checkForSunkShips()
                                    animationState = .idle
                                }
                            }) {
                                VStack {
                                    Text("⚔️")
                                        .font(.title)
                                    Text("FIGHT")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.red.opacity(0.3))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            // Run button
                            Button(action: {
                                game.processCombatAction(.run)
                            }) {
                                VStack {
                                    Text("🏃")
                                        .font(.title)
                                    Text("RUN")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            // Throw cargo button
                            Button(action: {
                                game.processCombatAction(.throwCargo)
                            }) {
                                VStack {
                                    Text("📦")
                                        .font(.title)
                                    Text("THROW")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.orange.opacity(0.3))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(game.currentCargo == 0)
                        }
                    } else {
                        // Combat ended
                        Button("Continue") {
                            game.showingCombat = false
                            game.combatState = nil
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.9))
            }
        }
    }

    @ViewBuilder
    private func lorchaView(at index: Int) -> some View {
        if index < combat.pirateShips.count {
            let ship = combat.pirateShips[index]

            if ship.sunk {
                // Empty space or sinking animation
                if sinkingShips.contains(index) {
                    sinkingLorchaArt
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let idx = sinkingShips.firstIndex(of: index) {
                                    sinkingShips.remove(at: idx)
                                }
                            }
                        }
                } else {
                    Color.clear
                        .frame(width: 50, height: 60)
                }
            } else {
                ZStack {
                    // Lorcha ship ASCII art
                    lorchaArt

                    // Blast animation overlay
                    if showingBlast && blastPositions.contains(index) {
                        blastArt
                    }
                }
            }
        } else {
            // Empty slot (less than 10 pirates)
            Color.clear
                .frame(width: 50, height: 60)
        }
    }

    private var lorchaArt: some View {
        VStack(spacing: 0) {
            Text("-|-_|_")
                .font(.system(size: 10, design: .monospaced))
            Text("-|-_|_")
                .font(.system(size: 10, design: .monospaced))
            Text("_|__|__/")
                .font(.system(size: 10, design: .monospaced))
            Text("\\_____/")
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundColor(isFlashing ? lorchaFlashColor : .white)
        .onAppear {
            startFlashing()
        }
    }

    private var blastArt: some View {
        VStack(spacing: 0) {
            Text("  ***")
                .font(.system(size: 10, design: .monospaced))
            Text(" *****")
                .font(.system(size: 10, design: .monospaced))
            Text("*******")
                .font(.system(size: 10, design: .monospaced))
            Text(" *****")
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundColor(.orange)
    }

    private var sinkingLorchaArt: some View {
        VStack(spacing: 0) {
            Text("       ")
                .font(.system(size: 10, design: .monospaced))
            Text("-|-_|_")
                .font(.system(size: 10, design: .monospaced))
            Text("-|-_|_")
                .font(.system(size: 10, design: .monospaced))
            Text("_|__|__/")
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundColor(.gray)
        .opacity(0.5)
    }

    private var seaworthinessColor: Color {
        let seaworthiness = Int((1.0 - game.shipDamage) * 100)
        if seaworthiness < 30 {
            return .red
        } else if seaworthiness < 60 {
            return .orange
        } else {
            return .green
        }
    }

    private func checkForSunkShips() {
        for (index, ship) in combat.pirateShips.enumerated() {
            if ship.sunk && !sinkingShips.contains(index) {
                sinkingShips.append(index)
            }
        }
    }

    private func startFlashing() {
        // Cycle through colors: red -> yellow -> orange -> red
        let colors: [Color] = [.red, .yellow, .orange, Color(red: 1.0, green: 0.5, blue: 0.0)]
        var colorIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            if !combat.isActive {
                timer.invalidate()
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                isFlashing.toggle()
                if isFlashing {
                    lorchaFlashColor = colors[colorIndex]
                    colorIndex = (colorIndex + 1) % colors.count
                }
            }
        }
    }
}
