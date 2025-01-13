import SwiftUI

@main
struct _048App: App {
    var body: some Scene {
        WindowGroup {
            GameBoardView(gameModel: GameModel())
        }
    }
}
