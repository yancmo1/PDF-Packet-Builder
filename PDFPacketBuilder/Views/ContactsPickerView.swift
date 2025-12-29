//
//  ContactsPickerView.swift
//  PDFPacketSender
//
//  View for picking contacts
//

import SwiftUI
import Contacts
import UIKit

struct ContactsPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var contacts: [Recipient] = []
    @State private var selectedContacts = Set<UUID>()
    @State private var isLoading = false
    @State private var hasPermission = false
    @State private var showingPermissionDenied = false
    @State private var permissionStatus: CNAuthorizationStatus = .notDetermined
    @State private var searchText: String = ""
    
    private let contactsService = ContactsService()

    private var filteredContacts: [Recipient] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        let q = query.lowercased()

        return contacts.filter { contact in
            let name = contact.fullName.lowercased()
            let email = contact.email.lowercased()
            let phone = (contact.phoneNumber ?? "").lowercased()
            return name.contains(q) || email.contains(q) || phone.contains(q)
        }
    }
    
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

                        if permissionStatus == .denied || permissionStatus == .restricted {
                            Button(action: openAppSettings) {
                                Text("Open Settings")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding()

                            Text("Contacts access is currently disabled. Enable it in Settings to import recipients from Contacts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
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
                        ForEach(filteredContacts) { contact in
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
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
                    // When searching, the navigation bar buttons can be harder to reach.
                    // Keep a persistent Add button available at the bottom.
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            Spacer()
                            Button("Add (\(selectedContacts.count))") {
                                addSelectedContacts()
                            }
                            .disabled(selectedContacts.isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
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
            .alert("Contacts Access Denied", isPresented: $showingPermissionDenied) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    openAppSettings()
                }
            } message: {
                Text("Enable Contacts access in Settings to import recipients.")
            }
        }
    }
    
    private func checkPermissionAndLoad() {
        permissionStatus = contactsService.authorizationStatus()
        hasPermission = (permissionStatus == .authorized)
        
        if hasPermission {
            loadContacts()
        }
    }
    
    private func requestPermission() {
        Task {
            permissionStatus = contactsService.authorizationStatus()
            if permissionStatus == .denied || permissionStatus == .restricted {
                showingPermissionDenied = true
                return
            }

            hasPermission = await contactsService.requestAccessIfNeeded()
            permissionStatus = contactsService.authorizationStatus()
            if hasPermission {
                loadContacts()
            } else if permissionStatus == .denied || permissionStatus == .restricted {
                showingPermissionDenied = true
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
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
