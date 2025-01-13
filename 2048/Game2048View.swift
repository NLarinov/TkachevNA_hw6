import SwiftUI
import AVFoundation

struct Tile: Equatable {
    var value: Int
    var id = UUID() // Для уникальности плиток (нужно для анимации)
}

enum Direction {
    case up, down, left, right
}

class GameModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var score: Int = 0
    @Published var moves: Int = 0
    @Published var highScores: [Int] = []

    private let boardSize = 4
    private let userDefaultsKey = "HighScores"
    private var audioPlayer: AVAudioPlayer?

    init() {
        loadHighScores()
        resetGame()
    }

    func resetGame() {
        tiles = Array(repeating: Tile(value: 0), count: boardSize * boardSize)
        score = 0
        moves = 0
        spawnTile()
        spawnTile()
    }

    func spawnTile() {
        let emptyIndexes = tiles.enumerated().filter { $0.element.value == 0 }.map { $0.offset }
        guard let randomIndex = emptyIndexes.randomElement() else { return }
        tiles[randomIndex] = Tile(value: Bool.random() ? 2 : 4)
    }

    func move(_ direction: Direction) {
        let originalTiles = tiles
        let lines = getLines(for: direction)

        var newLines: [[Tile]] = []
        for line in lines {
            let filteredLine = line.filter { $0.value > 0 } // Убираем пустые клетки
            var mergedLine: [Tile] = []
            var skipNext = false

            for i in 0..<filteredLine.count {
                if skipNext {
                    skipNext = false
                    continue
                }

                if i < filteredLine.count - 1, filteredLine[i].value == filteredLine[i + 1].value {
                    // Слияние плиток
                    let mergedTile = Tile(value: filteredLine[i].value * 2)
                    mergedLine.append(mergedTile)
                    score += mergedTile.value
                    playMergeSound()
                    skipNext = true
                } else {
                    mergedLine.append(filteredLine[i])
                }
            }

            // Добавляем пустые плитки для завершения строки до 4 элементов
            while mergedLine.count < boardSize {
                mergedLine.append(Tile(value: 0))
            }

            newLines.append(mergedLine)
        }

        setLines(newLines, for: direction)

        // Если поле изменилось, добавляем новую плитку и увеличиваем счётчик ходов
        if tiles != originalTiles {
            spawnTile()
            moves += 1
        }

        checkGameOver()
    }

    private func getLines(for direction: Direction) -> [[Tile]] {
        var lines: [[Tile]] = []

        switch direction {
        case .left:
            for row in 0..<boardSize {
                lines.append(Array(tiles[row * boardSize..<(row * boardSize + boardSize)]))
            }
        case .right:
            for row in 0..<boardSize {
                lines.append(Array(tiles[row * boardSize..<(row * boardSize + boardSize)].reversed()))
            }
        case .up:
            for col in 0..<boardSize {
                lines.append((0..<boardSize).map { tiles[$0 * boardSize + col] })
            }
        case .down:
            for col in 0..<boardSize {
                lines.append((0..<boardSize).map { tiles[$0 * boardSize + col] }.reversed())
            }
        }

        return lines
    }

    private func setLines(_ lines: [[Tile]], for direction: Direction) {
        switch direction {
        case .left:
            for row in 0..<boardSize {
                for col in 0..<boardSize {
                    tiles[row * boardSize + col] = lines[row][col]
                }
            }
        case .right:
            for row in 0..<boardSize {
                for col in 0..<boardSize {
                    tiles[row * boardSize + (boardSize - 1 - col)] = lines[row][col]
                }
            }
        case .up:
            for col in 0..<boardSize {
                for row in 0..<boardSize {
                    tiles[row * boardSize + col] = lines[col][row]
                }
            }
        case .down:
            for col in 0..<boardSize {
                for row in 0..<boardSize {
                    tiles[(boardSize - 1 - row) * boardSize + col] = lines[col][row]
                }
            }
        }
    }

    func directionFromGesture(_ gesture: DragGesture.Value) -> Direction {
        let translation = gesture.translation
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }

    private func playMergeSound() {
        guard let soundURL = Bundle.main.url(forResource: "move", withExtension: "mp3") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)
        audioPlayer?.play()
    }

    private func checkGameOver() {
        if tiles.allSatisfy({ $0.value > 0 }) {
            saveHighScore()
        }
    }

    private func saveHighScore() {
        if highScores.contains(score) {return}
        highScores.append(score)
        highScores = Array(highScores.sorted(by: >).prefix(10)) // Храним топ-10
        UserDefaults.standard.set(highScores, forKey: userDefaultsKey)
    }

    private func loadHighScores() {
        highScores = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Int] ?? []
    }
}

struct GameBoardView: View {
    @ObservedObject var gameModel: GameModel
    @State private var popupScale: CGFloat = 1.0

    var body: some View {
        VStack {
            HStack {
                Text("Score: \(gameModel.score)")
                Spacer()
                Text("Moves: \(gameModel.moves)")
            }
            .padding()

            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { col in
                            let tile = gameModel.tiles[row * 4 + col]
                            TileView(tile: tile)
                                .scaleEffect(tile.value > 0 ? popupScale : 1.0)
                                .onAppear {
                                    if tile.value > 0 {
                                        withAnimation(.bouncy()) {
                                            popupScale = 1.1
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            withAnimation(.bouncy()) {
                                                popupScale = 1.0
                                            }
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)

            Button("Restart Game") {
                gameModel.resetGame()
            }
            .padding()

            List {
                Text("High Scores")
                    .font(.headline)
                ForEach(gameModel.highScores, id: \.self) { score in
                    Text("\(score)")
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    let direction = gameModel.directionFromGesture(gesture)
                    gameModel.move(direction)
                }
        )
        .padding()
    }
}

struct TileView: View {
    let tile: Tile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tileColor(for: tile.value))
                .frame(width: 60, height: 60)

            if tile.value > 0 {
                Text("\(tile.value)")
                    .font(.title)
                    .foregroundColor(tile.value <= 4 ? .black : .white)
            }
        }
        .animation(.easeInOut, value: tile.value)
    }

    private func tileColor(for value: Int) -> Color {
        switch value {
        case 2:
            return .yellow
        case 4:
            return .orange
        case 8:
            return .red
        case 16:
            return .purple
        case 32:
            return .blue
        case 64:
            return .green
        case 128:
            return .cyan
        case 256:
            return .pink
        case 512:
            return .brown
        case 1024:
            return .gray
        case 2048:
            return .black
        default:
            return .white
        }
    }
}

