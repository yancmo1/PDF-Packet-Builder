//
//  ContactsPickerView.swift
//  PDFPacketSender
//
//  View for picking contacts
//

import SwiftUI
import Contacts

struct ContactsPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var contacts: [Recipient] = []
    @State private var selectedContacts = Set<UUID>()
    @State private var isLoading = false
    @State private var hasPermission = false
    @State private var showingPermissionDenied = false
    
    private let contactsService = ContactsService()
    
    var body: some View {
        NavigationView {
            Group {
                if !hasPermission {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Contacts Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This app needs access to your contacts to import recipients")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button(action: requestPermission) {
                            Text("Grant Access")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    .padding()
                } else if isLoading {
                    ProgressView("Loading Contacts...")
                } else if contacts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Contacts Found")
                            .font(.title2)
                        Text("No contacts with email addresses")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(contacts) { contact in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(contact.fullName)
                                        .fontWeight(.semibold)
                                    Text(contact.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedContacts.contains(contact.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(contact.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(selectedContacts.count))") {
                        addSelectedContacts()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
            .onAppear {
                checkPermissionAndLoad()
            }
        }
    }
    
    private func checkPermissionAndLoad() {
        let status = contactsService.authorizationStatus()
        hasPermission = (status == .authorized)
        
        if hasPermission {
            loadContacts()
        }
    }
    
    private func requestPermission() {
        Task {
            hasPermission = await contactsService.requestAccess()
            if hasPermission {
                loadContacts()
            }
        }
    }
    
    private func loadContacts() {
        isLoading = true
        Task {
            contacts = await contactsService.fetchContacts()
            isLoading = false
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedContacts.contains(id) {
            selectedContacts.remove(id)
        } else {
            selectedContacts.insert(id)
        }
    }
    
    private func addSelectedContacts() {
        let newContacts = contacts.filter { selectedContacts.contains($0.id) }
        var allRecipients = appState.recipients
        allRecipients.append(contentsOf: newContacts)
        appState.saveRecipients(allRecipients)
        dismiss()
    }
}
