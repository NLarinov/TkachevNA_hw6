//
//  _048App.swift
//  2048
//
//  Created by Николай Ткачев on 13/01/2025.
//

import SwiftUI

@main
struct _048App: App {
    var body: some Scene {
        WindowGroup {
            GameBoardView(gameModel: GameModel())
        }
    }
}
