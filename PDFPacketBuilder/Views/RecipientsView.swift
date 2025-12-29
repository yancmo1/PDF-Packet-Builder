//
//  RecipientsView.swift
//  PDFPacketSender
//
//  View for selecting and managing recipients
//

import SwiftUI

struct RecipientsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.editMode) private var editMode
    @State private var showingContactsPicker = false
    @State private var showingCSVImporter = false
    @State private var showingAddManual = false
    @State private var selectedRecipients = Set<UUID>()

    private var isEditing: Bool {
        editMode?.wrappedValue == .active
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if appState.recipients.isEmpty {
                    // No recipients
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No Recipients")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add recipients from Contacts or CSV")
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 15) {
                            Button(action: {
                                showingContactsPicker = true
                            }) {
                                Label("Import from Contacts", systemImage: "person.crop.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showingCSVImporter = true
                            }) {
                                Label("Import from CSV", systemImage: "doc.text")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showingAddManual = true
                            }) {
                                Label("Add Manually", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                } else {
                    // Recipients list
                    List {
                        ForEach(appState.recipients) { recipient in
                            RecipientRow(recipient: recipient, isSelected: isEditing && selectedRecipients.contains(recipient.id))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard isEditing else { return }
                                    toggleSelection(recipient.id)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Avoid "swipe and gone". Require tapping Delete.
                                    Button(role: .destructive) {
                                        deleteRecipient(recipient.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Recipients (\(appState.recipients.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingContactsPicker = true }) {
                            Label("Import from Contacts", systemImage: "person.crop.circle")
                        }
                        Button(action: { showingCSVImporter = true }) {
                            Label("Import from CSV", systemImage: "doc.text")
                        }
                        Button(action: { showingAddManual = true }) {
                            Label("Add Manually", systemImage: "plus.circle")
                        }
                        if !appState.recipients.isEmpty {
                            Divider()
                            Button(role: .destructive, action: clearAll) {
                                Label("Clear All", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    if isEditing {
                        Button(role: .destructive) {
                            deleteSelectedRecipients()
                        } label: {
                            Label("Delete (\(selectedRecipients.count))", systemImage: "trash")
                        }
                        .disabled(selectedRecipients.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingContactsPicker) {
                ContactsPickerView()
            }
            .sheet(isPresented: $showingCSVImporter) {
                CSVImporterView()
            }
            .sheet(isPresented: $showingAddManual) {
                ManualRecipientView()
            }
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedRecipients.contains(id) {
            selectedRecipients.remove(id)
        } else {
            selectedRecipients.insert(id)
        }
    }
    
    private func deleteRecipient(_ id: UUID) {
        let recipients = appState.recipients.filter { $0.id != id }
        appState.saveRecipients(recipients)
        selectedRecipients.remove(id)
    }
    
    private func clearAll() {
        appState.saveRecipients([])
        selectedRecipients.removeAll()
    }

    private func deleteSelectedRecipients() {
        guard !selectedRecipients.isEmpty else { return }
        let remaining = appState.recipients.filter { !selectedRecipients.contains($0.id) }
        appState.saveRecipients(remaining)
        selectedRecipients.removeAll()
    }
}

struct RecipientRow: View {
    let recipient: Recipient
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recipient.fullName)
                    .fontWeight(.semibold)
                Text(recipient.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct RecipientsView_Previews: PreviewProvider {
    static var previews: some View {
        RecipientsView()
            .environmentObject(AppState())
    }
}
