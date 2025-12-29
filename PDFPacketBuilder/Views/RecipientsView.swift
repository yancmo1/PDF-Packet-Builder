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
                                .environmentObject(appState)
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
    @EnvironmentObject var appState: AppState
    let recipient: Recipient
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(displayName(for: recipient))
                    .fontWeight(.semibold)
                let secondary = resolvedEmail(for: recipient)
                if !secondary.isEmpty {
                    Text(secondary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }

    private func resolvedEmail(for recipient: Recipient) -> String {
        if let column = appState.csvEmailColumn?.trimmingCharacters(in: .whitespacesAndNewlines), !column.isEmpty {
            let fromColumn = recipient.value(forKey: column)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fromColumn.isEmpty {
                return fromColumn
            }
        }

        return recipient.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayName(for recipient: Recipient) -> String {
        if let column = appState.csvDisplayNameColumn?.trimmingCharacters(in: .whitespacesAndNewlines), !column.isEmpty {
            let fromColumn = recipient.value(forKey: column)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fromColumn.isEmpty {
                return fromColumn
            }
        }

        let fullName = recipient.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            return fullName
        }

        if recipient.source == .csv, let fallback = bestNameFromCustomFields(recipient) {
            return fallback
        }

        let email = resolvedEmail(for: recipient)
        if !email.isEmpty {
            return email
        }

        return "Recipient"
    }

    private func bestNameFromCustomFields(_ recipient: Recipient) -> String? {
        let candidates: [(value: String, score: Double)] = recipient.customFields.compactMap { key, value in
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return nil }
            guard !v.contains("@") else { return nil }

            let tokens = Set(NormalizedName.from(key).tokens)
            if tokens.contains("email") || tokens.contains("phone") || tokens.contains("date") {
                return nil
            }

            var s: Double = 0.0
            if tokens.contains("name") { s += 0.6 }
            if tokens.contains("student") || tokens.contains("parent") || tokens.contains("guardian") { s += 0.2 }
            if tokens.contains("team") || tokens.contains("club") || tokens.contains("org") || tokens.contains("organization") { s -= 0.4 }

            s += personNameScore(v) * 0.6
            return (v, s)
        }

        guard let best = candidates.max(by: { $0.score < $1.score }), best.score >= 0.75 else {
            return nil
        }
        return best.value
    }

    private func personNameScore(_ raw: String) -> Double {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0.0 }
        if value.contains("@") { return 0.0 }

        let digitCount = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        if digitCount > 0 { return 0.0 }

        let words = value
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace })

        if words.isEmpty { return 0.0 }
        if words.count > 5 { return 0.20 }

        let letterCount = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let scalarCount = max(1, value.unicodeScalars.count)
        let letterRatio = Double(letterCount) / Double(scalarCount)
        if letterRatio < 0.55 { return 0.0 }

        if words.count == 2 || words.count == 3 { return 1.0 }
        if words.count == 1 { return 0.45 }
        if words.count == 4 { return 0.65 }
        return 0.50
    }
}

struct RecipientsView_Previews: PreviewProvider {
    static var previews: some View {
        RecipientsView()
            .environmentObject(AppState())
    }
}
