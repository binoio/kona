//
//  LibraryView.swift
//  Kona
//
//  Created by GitHub Copilot on 2025-12-26.
//

import SwiftUI

struct SidebarRow: View {
    @ObservedObject var state: WakeState
    @EnvironmentObject var manager: WakeStateManager
    let isSelected: Bool
    let isEditing: Bool
    let onStartEdit: () -> Void
    let onEndEdit: () -> Void
    
    @State private var editingName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                if state.isEnabled {
                    manager.disableWakeState(state)
                } else {
                    manager.enableWakeState(state)
                }
            }) {
                Image(systemName: state.isEnabled ? "power.circle.fill" : "power.circle")
                    .foregroundColor(state.isEnabled ? .accentColor : .primary)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("enableButton-\(state.id.uuidString)")

            if isEditing {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.squareBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        commitRename()
                    }
                    .onAppear {
                        editingName = state.name
                        isTextFieldFocused = true
                    }
            } else {
                Text(state.name)
                    .gesture(TapGesture(count: 2).onEnded {
                        if state.name != "Indefinite" && isSelected {
                            onStartEdit()
                        }
                    })
                Spacer()
                if state.name != "Indefinite" {
                    Button(action: {
                        manager.duplicateWakeState(state)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    Button(action: {
                        manager.deleteWakeState(state)
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .onChange(of: isTextFieldFocused) { focused in
            if !focused && isEditing {
                commitRename()
            }
        }
    }
    
    private func commitRename() {
        if !editingName.isEmpty && editingName != state.name {
            state.name = editingName
            manager.saveWakeStates()
        }
        onEndEdit()
    }
}

struct LibraryView: View {
    @EnvironmentObject var manager: WakeStateManager
    @State private var selectedState: WakeState? {
        didSet {
            manager.selectedWakeState = selectedState
        }
    }
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var editingStateId: UUID?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedState) {
                ForEach(manager.wakeStates) { s in
                    SidebarRow(
                        state: s,
                        isSelected: selectedState?.id == s.id,
                        isEditing: editingStateId == s.id,
                        onStartEdit: { editingStateId = s.id },
                        onEndEdit: { editingStateId = nil }
                    )
                    .tag(s)
                }
            }
            .frame(minWidth: 150)
            .navigationTitle("Kona Library")
            .toolbar {
                Button(action: {
                    let newState = WakeState(
                        name: "Untitled",
                        options: WakeState.StateOptions(allowScreenDim: true, allowSystemLock: true)
                    )
                    manager.addWakeState(newState)
                }) {
                    Image(systemName: "plus")
                }
            }
        } detail: {
            if let selectedState = selectedState {
                if selectedState.name == "Indefinite" {
                    IndefiniteEditView(state: selectedState)
                } else {
                    EditWakeStateView(state: selectedState)
                }
            } else {
                Text("Select a Wake State in the sidebar to edit or create a new one.")
            }
        }
        .onChange(of: manager.sidebarVisible) { newValue in
            columnVisibility = newValue ? .all : .detailOnly
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 450, idealWidth: 550, minHeight: 300, idealHeight: 400)
    }
}