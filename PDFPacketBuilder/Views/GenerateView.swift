//
//  GenerateView.swift
//  PDFPacketBuilder
//

import SwiftUI
import MessageUI

struct GenerateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var isGenerating = false
    @State private var generatedPDFs: [(recipient: Recipient, pdfData: Data)] = []
    @State private var showingShareSheet = false
    @State private var currentShareItem: ShareItem?
    @State private var currentMailItem: MailItem?
    @State private var currentPreviewItem: PreviewItem?
    @State private var showingPaywall = false
    @State private var showingMailUnavailableAlert = false
    @State private var showingMailFailedAlert = false
    @State private var mailFailedMessage: String = ""
    @State private var showingNoRecipientsSelectedAlert = false
    @State private var showingShareErrorAlert = false
    @State private var showingNoEmailForRowAlert = false

    // Pro: message templates
    @State private var isMessageTemplateEnabled = false
    @State private var subjectTemplateText = MessageTemplate.default.subjectTemplate
    @State private var bodyTemplateText = MessageTemplate.default.bodyTemplate

    // Pro: batch export folder
    @State private var showingFolderPicker = false
    @State private var isExporting = false
    @State private var exportedBundleURL: URL?
    @State private var showingExportShareSheet = false
    @State private var exportErrorMessage: String?
    @State private var showingExportErrorAlert = false

    @State private var statusFilter: StatusFilter = .all

    @State private var selectedRecipientIDs: Set<UUID> = []
    @State private var isRecipientListExpanded = true
    
    private let pdfService = PDFService()
    private let exportService = ExportService()

    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case unsent = "Unsent"
        case sent = "Sent"

        var id: String { rawValue }
    }

    private var selectedRecipients: [Recipient] {
        appState.recipients.filter { selectedRecipientIDs.contains($0.id) }
    }

    private var needsEmailColumnSelectionToSend: Bool {
        guard appState.csvImport != nil else { return false }
        let selected = appState.csvEmailColumn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !selected.isEmpty { return false }

        return appState.recipients.contains { recipient in
            recipient.source == .csv && recipient.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if appState.pdfTemplate == nil {
                    EmptyStateView(
                        icon: "doc.badge.plus",
                        title: "No Template",
                        message: "Import a PDF template first"
                    )
                } else if appState.recipients.isEmpty {
                    EmptyStateView(
                        icon: "person.2.badge.plus",
                        title: "No Recipients",
                        message: "Add recipients to send PDFs"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Template")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(appState.pdfTemplate?.name ?? "")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Recipients")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(selectedRecipientIDs.count) selected of \(appState.recipients.count)")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)

                            // Recipient selection
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Choose Recipients")
                                        .font(.headline)
                                    Spacer()

                                    Button {
                                        isRecipientListExpanded.toggle()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(isRecipientListExpanded ? "Hide" : "Show")
                                            Image(systemName: isRecipientListExpanded ? "chevron.up" : "chevron.down")
                                                .font(.caption)
                                        }
                                    }
                                    .font(.subheadline)

                                    Button("All") {
                                        selectedRecipientIDs = Set(appState.recipients.map { $0.id })
                                    }
                                    .font(.subheadline)
                                    Button("None") {
                                        selectedRecipientIDs.removeAll()
                                    }
                                    .font(.subheadline)
                                }

                                if isRecipientListExpanded {
                                    ForEach(appState.recipients) { recipient in
                                        Button {
                                            if selectedRecipientIDs.contains(recipient.id) {
                                                selectedRecipientIDs.remove(recipient.id)
                                            } else {
                                                selectedRecipientIDs.insert(recipient.id)
                                            }
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    let primary = displayName(for: recipient)
                                                    let secondary = resolvedEmail(for: recipient)

                                                    Text(primary)
                                                        .foregroundColor(.primary)

                                                    if !secondary.isEmpty && secondary != primary {
                                                        Text(secondary)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: selectedRecipientIDs.contains(recipient.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedRecipientIDs.contains(recipient.id) ? .blue : .secondary)
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)

                                        Divider()
                                    }
                                } else {
                                    Text("Recipient list hidden")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)

                            messageTemplateSection
                            
                            Button(action: attemptGenerate) {
                                Label("Generate PDFs", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(isGenerating)

                            if needsEmailColumnSelectionToSend {
                                Text("Select an Email column to send.")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Generated PDFs list
                            if !generatedPDFs.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Generated PDFs")
                                            .font(.headline)
                                        Spacer()
                                        let sentCount = generatedPDFs.filter { isSentStatus(for: $0) }.count
                                        Text("Sent \(sentCount) / \(generatedPDFs.count)")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Button {
                                            attemptExportFolder()
                                        } label: {
                                            Label("Export Folder", systemImage: "folder")
                                                .font(.subheadline)
                                        }
                                        Spacer()
                                    }

                                    Picker("Filter", selection: $statusFilter) {
                                        ForEach(StatusFilter.allCases) { filter in
                                            Text(filter.rawValue).tag(filter)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    
                                    ForEach(filteredGeneratedPDFs(), id: \.recipient.id) { item in
                                        let displayEmail = resolvedEmail(for: item.recipient)
                                        let canMail = !displayEmail.isEmpty
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(displayName(for: item.recipient))
                                                    .fontWeight(.semibold)

                                                HStack(spacing: 8) {
                                                    Text(displayEmail.isEmpty ? "(no email)" : displayEmail)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)

                                                    statusChip(for: item)
                                                }
                                            }
                                            Spacer()

                                            // Preview button (Free)
                                            Button {
                                                currentPreviewItem = PreviewItem(
                                                    recipientName: displayName(for: item.recipient),
                                                    templateName: appState.pdfTemplate?.name ?? "document",
                                                    pdfData: item.pdfData
                                                )
                                            } label: {
                                                Label("Preview", systemImage: "eye")
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color(.systemGray4))
                                                    .foregroundColor(.primary)
                                                    .cornerRadius(6)
                                            }
                                            
                                            // Mail button
                                            Button(action: {
                                                sendMail(item)
                                            }) {
                                                Label("Mail", systemImage: "envelope")
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(canMail ? Color.green : Color.gray)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(6)
                                            }
                                            .disabled(!canMail)
                                            
                                            // Share button
                                            Button(action: {
                                                sharePDF(item)
                                            }) {
                                                Label("Share", systemImage: "square.and.arrow.up")
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.blue)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Generate PDFs")
            .onAppear {
                // Default to all recipients selected.
                if selectedRecipientIDs.isEmpty {
                    selectedRecipientIDs = Set(appState.recipients.map { $0.id })
                }

                syncMessageTemplateFromAppState()
            }
            .onChange(of: appState.pdfTemplate?.id) { _ in
                syncMessageTemplateFromAppState()
            }
            .onChange(of: appState.recipients) { newRecipients in
                // Remove IDs that no longer exist, and auto-select new recipients.
                let newIDs = Set(newRecipients.map { $0.id })
                selectedRecipientIDs = selectedRecipientIDs.intersection(newIDs)
                selectedRecipientIDs.formUnion(newIDs)
            }
            .overlay {
                if isGenerating {
                    ProgressView("Generating PDFs...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                } else if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .sheet(item: $currentShareItem) { item in
                ShareSheet(
                    items: [item.url],
                    excludedActivityTypes: [
                        .assignToContact,
                        .saveToCameraRoll,
                        .markupAsPDF,
                        .openInIBooks,
                        .addToReadingList,
                        .postToFacebook,
                        .postToTwitter,
                        .postToWeibo,
                        .postToTencentWeibo
                    ]
                ) { completed in
                    if completed {
                        // Log the send only after successful share
                        logSend(recipientName: item.recipientName, templateName: item.templateName, fileName: item.fileName, method: .share)
                    }
                }
            }
            .sheet(item: $currentPreviewItem) { item in
                NavigationView {
                    PDFPreviewView(pdfData: item.pdfData)
                        .navigationTitle(item.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(item: $currentMailItem) { mailItem in
                MailComposer(
                    subject: mailItem.subject,
                    body: mailItem.body,
                    recipient: mailItem.recipientEmail,
                    pdfData: mailItem.pdfData,
                    fileName: mailItem.fileName
                ) { result, error in
                    if result == .sent {
                        // Log the send only after mail was sent
                        logSend(recipientName: mailItem.recipientName, templateName: mailItem.templateName, fileName: mailItem.fileName, method: .mail)
                    } else if result == .failed || error != nil {
                        mailFailedMessage = error?.localizedDescription ?? "Mail could not be sent. Please try again."
                        showingMailFailedAlert = true
                    }

                    // Dismiss sheet and clear state
                    currentMailItem = nil
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PurchaseView()
            }
            .sheet(isPresented: $showingFolderPicker) {
                FolderPicker(onSelected: { folderURL in
                    exportToFolder(folderURL)
                }, onFailure: { error in
                    exportErrorMessage = error.localizedDescription
                    showingExportErrorAlert = true
                })
            }
            .sheet(isPresented: $showingExportShareSheet) {
                if let url = exportedBundleURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("No recipients selected", isPresented: $showingNoRecipientsSelectedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Select at least one recipient to generate PDFs.")
            }
            .alert("Mail Not Available", isPresented: $showingMailUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Mail is not configured on this device. Please set up Mail in Settings.")
            }
            .alert("Mail Failed", isPresented: $showingMailFailedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(mailFailedMessage)
            }
            .alert("No email found for this row", isPresented: $showingNoEmailForRowAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Select an Email column to send.")
            }
            .alert("Unable to share", isPresented: $showingShareErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We could not prepare the PDF for sharing. Please try again.")
            }
            .alert("Export failed", isPresented: $showingExportErrorAlert) {
                Button("OK", role: .cancel) {
                    exportErrorMessage = nil
                }
            } message: {
                Text(exportErrorMessage ?? "We could not export the folder bundle. Please try again.")
            }
        }
    }

    private var messageTemplateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Message Template")
                    .font(.headline)
                Spacer()
                Text("Pro")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }

            if !iapManager.isProUnlocked {
                Text("Customize subject/body with tokens and preview before sending.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    showingPaywall = true
                } label: {
                    Label("Unlock Pro to edit messages", systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            } else {
                Toggle("Enable message template", isOn: $isMessageTemplateEnabled)
                    .onChange(of: isMessageTemplateEnabled) { _ in
                        persistMessageTemplateToAppState()
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Subject", text: $subjectTemplateText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isMessageTemplateEnabled)
                        .onChange(of: subjectTemplateText) { _ in
                            persistMessageTemplateToAppState()
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $bodyTemplateText)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .disabled(!isMessageTemplateEnabled)
                        .onChange(of: bodyTemplateText) { _ in
                            persistMessageTemplateToAppState()
                        }
                }

                if isMessageTemplateEnabled, let recipient = selectedRecipients.first {
                    let templateName = appState.pdfTemplate?.name ?? "document"
                    let fileName = outputFileName(for: recipient)
                    let ctx = MessageTemplateService.RenderContext(
                        recipient: recipient,
                        templateName: templateName,
                        outputFileName: fileName
                    )
                    let mt = MessageTemplate(isEnabled: true, subjectTemplate: subjectTemplateText, bodyTemplate: bodyTemplateText)
                    let previewSubject = MessageTemplateService.renderSubject(mt, context: ctx)
                    let previewBody = MessageTemplateService.renderBody(mt, context: ctx)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview (first selected recipient)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(previewSubject)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        Text(previewBody)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                    .padding(10)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }

                Text("Tokens: {{FirstName}}, {{LastName}}, {{FullName}}, {{Email}}, {{TemplateName}}, {{FileName}}")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func syncMessageTemplateFromAppState() {
        guard let template = appState.pdfTemplate else { return }
        let mt = template.messageTemplate ?? MessageTemplate.default

        // Do not force-disable stored templates for Free users; just reflect persisted state.
        isMessageTemplateEnabled = mt.isEnabled
        subjectTemplateText = mt.subjectTemplate
        bodyTemplateText = mt.bodyTemplate
    }

    private func persistMessageTemplateToAppState() {
        guard iapManager.isProUnlocked else { return }
        guard var template = appState.pdfTemplate else { return }

        template.messageTemplate = MessageTemplate(
            isEnabled: isMessageTemplateEnabled,
            subjectTemplate: subjectTemplateText,
            bodyTemplate: bodyTemplateText
        )
        appState.saveTemplate(template)
    }

    private func attemptExportFolder() {
        guard !generatedPDFs.isEmpty else { return }

        if !iapManager.isProUnlocked {
            showingPaywall = true
            return
        }

        showingFolderPicker = true
    }

    private func exportToFolder(_ folderURL: URL) {
        guard let templateName = appState.pdfTemplate?.name else { return }
        let items = generatedPDFs.map { ExportService.GeneratedItem(recipient: $0.recipient, pdfData: $0.pdfData) }

        isExporting = true
        exportErrorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let messageProvider: ((Recipient, String) -> String?)? = {
                    recipient, outputFileName in
                    guard self.iapManager.isProUnlocked, self.isMessageTemplateEnabled else { return nil }
                    let ctx = MessageTemplateService.RenderContext(
                        recipient: recipient,
                        templateName: templateName,
                        outputFileName: outputFileName
                    )
                    let mt = MessageTemplate(isEnabled: true, subjectTemplate: self.subjectTemplateText, bodyTemplate: self.bodyTemplateText)
                    let subject = MessageTemplateService.renderSubject(mt, context: ctx)
                    let body = MessageTemplateService.renderBody(mt, context: ctx)
                    return "Subject: \(subject)\n\n\(body)"
                }

                let url = try self.exportService.exportBundle(
                    items: items,
                    templateName: templateName,
                    parentFolderURL: folderURL,
                    messageProvider: messageProvider
                )

                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportedBundleURL = url
                    self.showingExportShareSheet = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportErrorMessage = error.localizedDescription
                    self.showingExportErrorAlert = true
                }
            }
        }
    }

    private func attemptGenerate() {
        if selectedRecipientIDs.isEmpty {
            showingNoRecipientsSelectedAlert = true
            return
        }

        // Hide the recipient list after starting generation to reduce screen clutter.
        isRecipientListExpanded = false
        generatePDFs()
    }
    
    private func generatePDFs() {
        guard let template = appState.pdfTemplate else { return }
        guard let templatePDFData = appState.resolvedTemplatePDFData() else {
            // Template metadata exists, but the PDF bytes could not be loaded.
            DispatchQueue.main.async {
                self.showingShareErrorAlert = true
            }
            return
        }

        // Snapshot inputs on the main thread to avoid races while generating.
        let recipientsToGenerate = selectedRecipients
        
        isGenerating = true
        generatedPDFs.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var pdfs: [(Recipient, Data)] = []
            
            for recipient in recipientsToGenerate {
                if let pdfData = pdfService.generatePersonalizedPDF(templatePDFData: templatePDFData, template: template, recipient: recipient) {
                    pdfs.append((recipient, pdfData))
                }
            }
            
            DispatchQueue.main.async {
                self.generatedPDFs = pdfs
                self.isGenerating = false
            }
        }
    }
    
    private func sharePDF(_ item: (recipient: Recipient, pdfData: Data)) {
        let fileName = outputFileName(for: item.recipient)
        
        guard let url = StorageService().savePDFToDocuments(data: item.pdfData, filename: fileName) else {
            showingShareErrorAlert = true
            return
        }

        currentShareItem = ShareItem(
            url: url,
            recipientName: displayName(for: item.recipient),
            templateName: appState.pdfTemplate?.name ?? "document",
            fileName: fileName
        )
    }
    
    private func sendMail(_ item: (recipient: Recipient, pdfData: Data)) {
        guard MFMailComposeViewController.isAvailable else {
            showingMailUnavailableAlert = true
            return
        }

        let fileName = outputFileName(for: item.recipient)
        let templateName = appState.pdfTemplate?.name ?? "document"

        let subject: String
        let body: String?
        if iapManager.isProUnlocked && isMessageTemplateEnabled {
            let mt = MessageTemplate(
                isEnabled: true,
                subjectTemplate: subjectTemplateText,
                bodyTemplate: bodyTemplateText
            )
            let ctx = MessageTemplateService.RenderContext(
                recipient: item.recipient,
                templateName: templateName,
                outputFileName: fileName
            )
            subject = MessageTemplateService.renderSubject(mt, context: ctx)
            body = MessageTemplateService.renderBody(mt, context: ctx)
        } else {
            subject = "\(templateName) PDF"
            body = nil
        }

        let email = resolvedEmail(for: item.recipient)
        if email.isEmpty {
            showingNoEmailForRowAlert = true
            return
        }
        let mailItem = MailItem(
            recipientName: displayName(for: item.recipient),
            recipientEmail: email,
            templateName: templateName,
            fileName: fileName,
            pdfData: item.pdfData,
            subject: subject,
            body: body
        )

        currentMailItem = mailItem
    }
    
    private func logSend(recipientName: String, templateName: String, fileName: String, method: SendLog.SendMethod) {
        let log = SendLog(
            recipientName: recipientName,
            templateName: templateName,
            outputFileName: fileName,
            sentDate: Date(),
            method: method
        )
        appState.addSendLog(log)
    }

    private func outputFileName(for recipient: Recipient) -> String {
        let templateComponent = safeFileComponent(appState.pdfTemplate?.name ?? "document")
        let nameComponent = safeFileComponent(displayName(for: recipient))
        let shortID = recipient.id.uuidString.prefix(8)
        return "\(templateComponent)_\(nameComponent)_\(shortID).pdf"
    }

    private func legacyOutputFileName(for recipient: Recipient) -> String {
        let templateComponent = safeFileComponent(appState.pdfTemplate?.name ?? "document")
        let nameComponent = safeFileComponent(displayName(for: recipient))
        return "\(templateComponent)_\(nameComponent).pdf"
    }

    private func originalLegacyOutputFileName(for recipient: Recipient) -> String {
        "\(appState.pdfTemplate?.name ?? "document")_\(recipient.fullName).pdf"
    }

    private func safeFileComponent(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "item" }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let mapped = String(trimmed.unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }
            return "_"
        })

        // Avoid creating paths with leading/trailing spaces/underscores.
        let collapsed = mapped
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " _"))

        // Keep names reasonably short.
        if collapsed.count > 60 {
            return String(collapsed.prefix(60))
        }
        return collapsed.isEmpty ? "item" : collapsed
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
        // If we have a chosen/detected display-name column, try it first.
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

        // CSV recipients often store a single full-name column in customFields.
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

            // Value-shape bonus.
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

    private func sendLogForGenerated(_ item: (recipient: Recipient, pdfData: Data)) -> SendLog? {
        let templateName = appState.pdfTemplate?.name ?? "document"

        let currentFileName = outputFileName(for: item.recipient)
        let legacyFileName = legacyOutputFileName(for: item.recipient)
        let originalLegacyFileName = originalLegacyOutputFileName(for: item.recipient)

        let matching = appState.sendLogs.filter {
            $0.templateName == templateName && (
                $0.outputFileName == currentFileName ||
                $0.outputFileName == legacyFileName ||
                $0.outputFileName == originalLegacyFileName
            )
        }

        return matching.max(by: { $0.sentDate < $1.sentDate })
    }

    private func isSentStatus(for item: (recipient: Recipient, pdfData: Data)) -> Bool {
        sendLogForGenerated(item) != nil
    }

    @ViewBuilder
    private func statusChip(for item: (recipient: Recipient, pdfData: Data)) -> some View {
        if let log = sendLogForGenerated(item) {
            Text("Sent \(log.formattedSentDate)")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .clipShape(Capsule())
        } else {
            Text("Unsent")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.secondary)
                .clipShape(Capsule())
        }
    }

    private func filteredGeneratedPDFs() -> [(recipient: Recipient, pdfData: Data)] {
        switch statusFilter {
        case .all:
            return generatedPDFs
        case .unsent:
            return generatedPDFs.filter { !isSentStatus(for: $0) }
        case .sent:
            return generatedPDFs.filter { isSentStatus(for: $0) }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let recipientName: String
    let templateName: String
    let fileName: String
}

struct PreviewItem: Identifiable {
    let id = UUID()
    let recipientName: String
    let templateName: String
    let pdfData: Data

    var title: String {
        "\(templateName) • \(recipientName)"
    }
}

struct MailItem: Identifiable {
    let id = UUID()
    let recipientName: String
    let recipientEmail: String
    let templateName: String
    let fileName: String
    let pdfData: Data
    let subject: String
    let body: String?
}

struct GenerateView_Previews: PreviewProvider {
    static var previews: some View {
        GenerateView()
            .environmentObject(AppState())
    }
}
