//
//  ManualRecipientView.swift
//  PDFPacketSender
//
//  View for manually adding a recipient
//

import SwiftUI

struct ManualRecipientView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient Information")) {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone Number (Optional)", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add Recipient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addRecipient()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private func addRecipient() {
        let recipient = Recipient(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            source: .manual
        )
        
        var recipients = appState.recipients
        recipients.append(recipient)
        appState.saveRecipients(recipients)
        dismiss()
    }
}
