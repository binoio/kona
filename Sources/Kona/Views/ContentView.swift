//
//  ContentView.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: WakeStateManager
    
    var body: some View {
        LibraryView()
    }
}