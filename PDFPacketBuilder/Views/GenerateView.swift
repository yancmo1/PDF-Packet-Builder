//
//  GenerateView.swift
//  PDFPacketBuilder
//

import SwiftUI
import MessageUI

private func clampNSRange(_ range: NSRange, in text: String) -> NSRange {
    let length = (text as NSString).length
    let loc = min(max(0, range.location), length)
    let maxLen = max(0, length - loc)
    let len = min(max(0, range.length), maxLen)
    return NSRange(location: loc, length: len)
}

struct GenerateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var isGenerating = false
    @State private var generatedPDFs: [(recipient: Recipient, pdfData: Data)] = []
    @State private var showingShareSheet = false
    @State private var currentShareItem: ShareItem?
    @State private var currentMailItem: MailItem?
    @State private var currentExportBundle: ExportBundle?
    @State private var showingPaywall = false
    @State private var showingMailUnavailableAlert = false
    @State private var showingMailFailedAlert = false
    @State private var mailFailedMessage: String = ""
    @State private var showingRecipientLimitAlert = false
    @State private var showingNoRecipientsSelectedAlert = false
    @State private var showingShareErrorAlert = false
    @State private var showingNoEmailForRowAlert = false
    @State private var showingExportErrorAlert = false
    @State private var exportErrorMessage: String = ""
    @State private var previewPDFData: Data? = nil
    @State private var showingPDFPreview = false

    @State private var statusFilter: StatusFilter = .all

    @State private var selectedRecipientIDs: Set<UUID> = []
    @State private var isRecipientListExpanded = true

    @State private var isMessageTemplateExpanded = false
    @State private var previewRecipientID: UUID? = nil

    @State private var messageTemplateFocus: MessageTemplateFocus? = nil
    @State private var messageSubjectSelection: NSRange = NSRange(location: 0, length: 0)
    @State private var messageBodySelection: NSRange = NSRange(location: 0, length: 0)

    @State private var messageBodyEditorHeight: CGFloat = 220
    
    private let pdfService = PDFService()

    private struct CSVTokenDescriptor: Hashable {
        var token: String
        var header: String
    }

    private enum MessageTemplateFocus: Hashable {
        case subject
        case body
    }

    private struct CursorAwareTextField: UIViewRepresentable {
        @Binding var text: String
        @Binding var selection: NSRange
        var placeholder: String
        var onBeginEditing: (() -> Void)?

        func makeUIView(context: Context) -> UITextField {
            let field = UITextField(frame: .zero)
            field.borderStyle = .roundedRect
            field.placeholder = placeholder
            field.autocapitalizationType = .sentences
            field.autocorrectionType = .default
            field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
            field.delegate = context.coordinator
            return field
        }

        func updateUIView(_ uiView: UITextField, context: Context) {
            if uiView.text != text {
                uiView.text = text
            }

            // Apply selection when this field is currently focused.
            guard uiView.isFirstResponder else { return }
            let clamped = clampNSRange(selection, in: text)
            if let start = uiView.position(from: uiView.beginningOfDocument, offset: clamped.location),
               let end = uiView.position(from: start, offset: clamped.length),
               let range = uiView.textRange(from: start, to: end) {
                uiView.selectedTextRange = range
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        final class Coordinator: NSObject, UITextFieldDelegate {
            private let parent: CursorAwareTextField

            init(_ parent: CursorAwareTextField) {
                self.parent = parent
            }

            func textFieldDidBeginEditing(_ textField: UITextField) {
                parent.onBeginEditing?()
                updateSelection(from: textField)
            }

            func textFieldDidChangeSelection(_ textField: UITextField) {
                updateSelection(from: textField)
            }

            @objc func textDidChange(_ textField: UITextField) {
                parent.text = textField.text ?? ""
                updateSelection(from: textField)
            }

            private func updateSelection(from textField: UITextField) {
                guard let range = textField.selectedTextRange else { return }
                let start = textField.offset(from: textField.beginningOfDocument, to: range.start)
                let end = textField.offset(from: textField.beginningOfDocument, to: range.end)
                parent.selection = NSRange(location: max(0, start), length: max(0, end - start))
            }
        }
    }

    private struct CursorAwareTextView: UIViewRepresentable {
        @Binding var text: String
        @Binding var selection: NSRange
        var onBeginEditing: (() -> Void)?

        func makeUIView(context: Context) -> UITextView {
            let view = UITextView(frame: .zero)
            view.isScrollEnabled = true
            view.backgroundColor = .systemBackground
            view.font = UIFont.preferredFont(forTextStyle: .body)
            view.delegate = context.coordinator
            view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
            return view
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            if uiView.text != text {
                uiView.text = text
            }

            // Apply selection when this view is currently focused.
            guard uiView.isFirstResponder else { return }
            let clamped = clampNSRange(selection, in: text)
            if uiView.selectedRange != clamped {
                uiView.selectedRange = clamped
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            private let parent: CursorAwareTextView

            init(_ parent: CursorAwareTextView) {
                self.parent = parent
            }

            func textViewDidBeginEditing(_ textView: UITextView) {
                parent.onBeginEditing?()
                parent.selection = textView.selectedRange
            }

            func textViewDidChange(_ textView: UITextView) {
                parent.text = textView.text
            }

            func textViewDidChangeSelection(_ textView: UITextView) {
                parent.selection = textView.selectedRange
            }
        }
    }

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
        let selected = appState.selectedEmailColumn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

                            messageTemplateSection()
                            
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
                                            
                                            // Preview button
                                            Button(action: {
                                                previewPDFData = item.pdfData
                                                showingPDFPreview = true
                                            }) {
                                                Image(systemName: "eye")
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                    .background(Color.purple)
                                                    .foregroundColor(.white)
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

                                    Button(action: exportGeneratedBundle) {
                                        Label("Export Folder", systemImage: "folder")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(10)
                                    }
                                    .disabled(isGenerating || generatedPDFs.isEmpty)

                                    if currentMessageTemplate().isEnabled && currentMessageTemplate().hasAnyContent {
                                        Text("Export includes one Message.txt per recipient.")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
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
            .sheet(item: $currentExportBundle) { bundle in
                ShareSheet(items: [bundle.shareURL]) { completed in
                    if completed {
                        cleanupExportArtifacts(bundle)
                    }
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
            .sheet(isPresented: $showingPDFPreview) {
                if let pdfData = previewPDFData {
                    NavigationView {
                        PDFPreviewView(pdfData: pdfData)
                            .navigationTitle("Preview")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        showingPDFPreview = false
                                        previewPDFData = nil
                                    }
                                }
                            }
                    }
                }
            }
            .alert("Limit reached", isPresented: $showingRecipientLimitAlert) {
                Button("OK", role: .cancel) { }
                Button("Unlock Pro") {
                    showingPaywall = true
                }
            } message: {
                Text("Free version supports 10 recipients per batch. Unlock Pro to remove limits.")
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
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
            }
        }
    }

    private func messageTemplateSection() -> some View {
        let template = currentMessageTemplate()
        let hasCSV = appState.csvImport != nil
        let headers = appState.csvImport?.headers ?? []

        let csvTokens = csvTokenCatalog(headers: headers)
        let csvTokenSet = Set(csvTokens.map { $0.token })
        let allowedTokens = MessageTemplateRenderer.systemTokens.union(csvTokenSet)

        let previewRecipient = previewRecipientForTemplate()
        let previewRecipientEmail = previewRecipient.map { resolvedEmail(for: $0) } ?? ""
        let resolvedValues = previewRecipient.map { resolvedMessageTokenValues(for: $0, messageTemplate: template, csvTokens: csvTokens) } ?? [:]
        let referencedTokens = MessageTemplateRenderer.extractTokens(from: template.subject)
            .union(MessageTemplateRenderer.extractTokens(from: template.body))
        let requiredIssues = requiredMessageTemplateIssues(
            referencedTokens: referencedTokens,
            hasCSV: hasCSV,
            headers: headers,
            csvTokenSet: csvTokenSet,
            messageTemplate: template,
            previewRecipientEmail: previewRecipientEmail
        )
        let renderResult = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues,
            requiredFieldIssues: requiredIssues
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Message Template")
                    .font(.headline)
                Spacer()
                Button {
                    isMessageTemplateExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(isMessageTemplateExpanded ? "Hide" : "Show")
                        Image(systemName: isMessageTemplateExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .font(.subheadline)
            }

            if isMessageTemplateExpanded {
                Toggle(
                    "Enable message template",
                    isOn: Binding(
                        get: { currentMessageTemplate().isEnabled },
                        set: { newValue in
                            updateMessageTemplate { mt in
                                mt.isEnabled = newValue
                                mt.lastEdited = Date()
                            }
                        }
                    )
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Subject")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    CursorAwareTextField(
                        text: Binding(
                            get: { currentMessageTemplate().subject },
                            set: { newValue in
                                updateMessageTemplate { mt in
                                    mt.subject = newValue
                                    mt.lastEdited = Date()
                                    syncTemplateEnabledState(&mt)
                                }
                            }
                        ),
                        selection: $messageSubjectSelection,
                        placeholder: "Subject",
                        onBeginEditing: {
                            messageTemplateFocus = .subject
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Body")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .bottomTrailing) {
                        CursorAwareTextView(
                            text: Binding(
                                get: { currentMessageTemplate().body },
                                set: { newValue in
                                    updateMessageTemplate { mt in
                                        mt.body = newValue
                                        mt.lastEdited = Date()
                                        syncTemplateEnabledState(&mt)
                                    }
                                }
                            ),
                            selection: $messageBodySelection,
                            onBeginEditing: {
                                messageTemplateFocus = .body
                            }
                        )
                        .frame(height: max(120, messageBodyEditorHeight))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(Color(.systemGray6).opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Resize message body")
                            .gesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { value in
                                        let proposed = messageBodyEditorHeight + value.translation.height
                                        messageBodyEditorHeight = min(max(120, proposed), 600)
                                    }
                            )
                    }
                }

                HStack {
                    Menu {
                        if hasCSV {
                            let sortedCSV = csvTokens.sorted { lhs, rhs in
                                if lhs.token == rhs.token { return lhs.header < rhs.header }
                                return lhs.token < rhs.token
                            }
                            ForEach(sortedCSV, id: \.self) { item in
                                Button("{{\(item.token)}} (\(item.header))") {
                                    insertToken(item.token)
                                }
                            }

                            if !sortedCSV.isEmpty {
                                Divider()
                            }
                        }

                        ForEach(Array(MessageTemplateRenderer.systemTokens).sorted(), id: \.self) { token in
                            Button("{{\(token)}}") {
                                insertToken(token)
                            }
                        }
                    } label: {
                        Label("Insert Token", systemImage: "curlybraces")
                    }

                    Spacer()

                    Button("Use Starter") {
                        updateMessageTemplate { mt in
                            mt = .starterEnabled
                        }
                    }

                    Button("Clear") {
                        updateMessageTemplate { mt in
                            mt = .emptyDisabled
                        }
                    }
                }
                .font(.subheadline)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Preview")
                            .font(.subheadline)
                        Spacer()

                        Menu {
                            Button("Use first selected") { previewRecipientID = nil }
                            Divider()

                            ForEach(selectedRecipients, id: \.id) { recipient in
                                Button(displayName(for: recipient)) {
                                    previewRecipientID = recipient.id
                                }
                            }
                        } label: {
                            let label = previewRecipient.map { displayName(for: $0) } ?? "(none)"
                            Label(label, systemImage: "eye")
                                .lineLimit(1)
                        }
                        .disabled(selectedRecipients.isEmpty)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Subject: \(renderResult.subject)")
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(renderResult.body)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)

                    if !renderResult.validation.requiredFieldIssues.isEmpty {
                        warningBlock(title: "Missing mappings", lines: renderResult.validation.requiredFieldIssues)
                    }

                    if !renderResult.validation.unknownTokens.isEmpty {
                        warningBlock(
                            title: "Unknown tokens",
                            lines: [renderResult.validation.unknownTokens.sorted().joined(separator: ", ")]
                        )
                    }

                    if !renderResult.validation.unresolvedTokens.isEmpty {
                        warningBlock(
                            title: "Blank for preview recipient",
                            lines: [renderResult.validation.unresolvedTokens.sorted().joined(separator: ", ")]
                        )
                    }
                }
            } else if template.hasAnyContent {
                let status = template.isEnabled ? "Enabled" : "Disabled"
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Optional. Add a Subject and Body with tokens like {{recipient_name}} or tokens derived from your CSV headers.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func warningBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
    }

    private func currentMessageTemplate() -> MessageTemplate {
        appState.pdfTemplate?.messageTemplate ?? .emptyDisabled
    }

    private func updateMessageTemplate(_ update: (inout MessageTemplate) -> Void) {
        guard var template = appState.pdfTemplate else { return }
        var mt = template.messageTemplate
        update(&mt)
        template.messageTemplate = mt
        appState.saveTemplate(template)
    }

    private func syncTemplateEnabledState(_ template: inout MessageTemplate) {
        if template.hasAnyContent {
            if !template.isEnabled {
                template.isEnabled = true
            }
        } else {
            template.isEnabled = false
        }
    }

    private func insertToken(_ token: String) {
        let snippet = "{{\(token)}}"

        switch messageTemplateFocus {
        case .subject:
            updateMessageTemplate { mt in
                let clamped = clampNSRange(messageSubjectSelection, in: mt.subject)
                let ns = mt.subject as NSString
                mt.subject = ns.replacingCharacters(in: clamped, with: snippet)
                messageSubjectSelection = NSRange(location: clamped.location + (snippet as NSString).length, length: 0)
                mt.lastEdited = Date()
                syncTemplateEnabledState(&mt)
            }
        case .body:
            updateMessageTemplate { mt in
                let clamped = clampNSRange(messageBodySelection, in: mt.body)
                let ns = mt.body as NSString
                mt.body = ns.replacingCharacters(in: clamped, with: snippet)
                messageBodySelection = NSRange(location: clamped.location + (snippet as NSString).length, length: 0)
                mt.lastEdited = Date()
                syncTemplateEnabledState(&mt)
            }
        default:
            updateMessageTemplate { mt in
                let clamped = clampNSRange(messageBodySelection, in: mt.body)
                let ns = mt.body as NSString
                mt.body = ns.replacingCharacters(in: clamped, with: snippet)
                messageBodySelection = NSRange(location: clamped.location + (snippet as NSString).length, length: 0)
                mt.lastEdited = Date()
                syncTemplateEnabledState(&mt)
            }
        }
    }

    private func appendToken(_ token: String, to text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return token
        }

        if text.hasSuffix("\n") {
            return text + token
        }

        return text + " " + token
    }

    private func previewRecipientForTemplate() -> Recipient? {
        if let id = previewRecipientID, let found = selectedRecipients.first(where: { $0.id == id }) {
            return found
        }
        return selectedRecipients.first ?? appState.recipients.first
    }

    private func resolvedMessageTokenValues(for recipient: Recipient, messageTemplate: MessageTemplate, csvTokens: [CSVTokenDescriptor]) -> [String: String] {
        var values: [String: String] = [:]

        values["recipient_name"] = displayName(for: recipient)
        values["recipient_email"] = resolvedEmail(for: recipient)

        for item in csvTokens {
            let boundHeader = messageTemplate.tokenBindings[item.token]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let headerToUse = boundHeader.isEmpty ? item.header : boundHeader
            values[item.token] = recipient.value(forKey: headerToUse)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        values["packet_title"] = (appState.pdfTemplate?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        values["date"] = formatter.string(from: Date())

        values["sender_name"] = appState.senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        values["sender_email"] = appState.senderEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        return values
    }

    private func requiredMessageTemplateIssues(
        referencedTokens: Set<String>,
        hasCSV: Bool,
        headers: [String],
        csvTokenSet: Set<String>,
        messageTemplate: MessageTemplate,
        previewRecipientEmail: String
    ) -> [String] {
        var issues: [String] = []

        let referencedCSV = referencedTokens.intersection(csvTokenSet)
        if !referencedCSV.isEmpty, !hasCSV {
            issues.append("Import a CSV to resolve tokens derived from CSV headers.")
        }

        if referencedTokens.contains("sender_name") {
            let name = appState.senderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                issues.append("Enter a Sender name in Settings to resolve {{sender_name}}.")
            }
        }

        if referencedTokens.contains("sender_email") {
            let email = appState.senderEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if email.isEmpty {
                issues.append("Enter a Sender email in Settings to resolve {{sender_email}}.")
            }
        }

        if referencedTokens.contains("recipient_email") {
            let email = previewRecipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if email.isEmpty {
                issues.append("Preview recipient has no email value for {{recipient_email}}.")
            }
        }

        return issues
    }

    private func exportGeneratedBundle() {
        guard let template = appState.pdfTemplate else { return }
        guard !generatedPDFs.isEmpty else { return }

        let messageTemplate = template.messageTemplate
        let shouldWriteMessages = messageTemplate.isEnabled && messageTemplate.hasAnyContent

        let headers = appState.csvImport?.headers ?? []
        let csvTokens = csvTokenCatalog(headers: headers)
        let csvTokenSet = Set(csvTokens.map { $0.token })
        let allowedTokens = MessageTemplateRenderer.systemTokens.union(csvTokenSet)

        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"

        let rootName = "Export_\(safeFileComponent(template.name))_\(dateFormatter.string(from: Date()))"
        let rootURL = tempRoot.appendingPathComponent(rootName, isDirectory: true)

        do {
            if fm.fileExists(atPath: rootURL.path) {
                try fm.removeItem(at: rootURL)
            }
            try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            exportErrorMessage = "Could not create export folder."
            showingExportErrorAlert = true
            return
        }

        var summaryLines: [String] = []
        summaryLines.append("recipient_name,recipient_email,pdf_path,message_path")

        for item in generatedPDFs {
            let recipient = item.recipient
            let folderComponent = safeFileComponent(displayName(for: recipient))
            let shortID = String(recipient.id.uuidString.prefix(8))
            let recipientFolderName = "\(folderComponent.isEmpty ? "Recipient" : folderComponent)_\(shortID)"
            let recipientFolderURL = rootURL.appendingPathComponent(recipientFolderName, isDirectory: true)

            do {
                try fm.createDirectory(at: recipientFolderURL, withIntermediateDirectories: true)
            } catch {
                exportErrorMessage = "Could not create a recipient folder."
                showingExportErrorAlert = true
                return
            }

            let pdfURL = recipientFolderURL.appendingPathComponent("Packet.pdf")
            do {
                try item.pdfData.write(to: pdfURL, options: [.atomic])
            } catch {
                exportErrorMessage = "Could not write Packet.pdf."
                showingExportErrorAlert = true
                return
            }

            var messageRelativePath = ""
            if shouldWriteMessages {
                let values = resolvedMessageTokenValues(for: recipient, messageTemplate: messageTemplate, csvTokens: csvTokens)
                let result = MessageTemplateRenderer.render(template: messageTemplate, allowedTokens: allowedTokens, resolvedValues: values)
                let messageText = "Subject: \(result.subject)\n\n\(result.body)"

                let messageURL = recipientFolderURL.appendingPathComponent("Message.txt")
                do {
                    try messageText.write(to: messageURL, atomically: true, encoding: .utf8)
                    messageRelativePath = "\(recipientFolderName)/Message.txt"
                } catch {
                    exportErrorMessage = "Could not write Message.txt."
                    showingExportErrorAlert = true
                    return
                }
            }

            let recipientNameCSV = escapeCSVField(displayName(for: recipient))
            let recipientEmailCSV = escapeCSVField(resolvedEmail(for: recipient))
            let pdfRelativePath = "\(recipientFolderName)/Packet.pdf"
            let pdfPathCSV = escapeCSVField(pdfRelativePath)
            let messagePathCSV = escapeCSVField(messageRelativePath)
            summaryLines.append("\(recipientNameCSV),\(recipientEmailCSV),\(pdfPathCSV),\(messagePathCSV)")
        }

        let summaryCSV = summaryLines.joined(separator: "\n") + "\n"
        let summaryURL = rootURL.appendingPathComponent("Summary.csv")
        do {
            try summaryCSV.write(to: summaryURL, atomically: true, encoding: .utf8)
        } catch {
            // Summary is optional; ignore failures.
        }

        // Prefer sharing a ZIP for better compatibility across share targets.
        // If zipping fails, fall back to sharing the folder.
        let zipURL = tempRoot.appendingPathComponent(rootName).appendingPathExtension("zip")
        do {
            try ZipWriter.zipFolder(at: rootURL, to: zipURL)
            currentExportBundle = ExportBundle(shareURL: zipURL, cleanupURLs: [zipURL, rootURL])
        } catch {
            currentExportBundle = ExportBundle(shareURL: rootURL, cleanupURLs: [rootURL])
        }
    }

    private func cleanupExportArtifacts(_ bundle: ExportBundle) {
        let fm = FileManager.default
        for url in bundle.cleanupURLs {
            do {
                if fm.fileExists(atPath: url.path) {
                    try fm.removeItem(at: url)
                }
            } catch {
                // Best-effort cleanup only.
            }
        }
    }

    private func csvTokenCatalog(headers: [String]) -> [CSVTokenDescriptor] {
        var used: [String: Int] = [:]
        var out: [CSVTokenDescriptor] = []
        out.reserveCapacity(headers.count)

        for header in headers {
            let base = normalizeHeaderToToken(header)
            let count = (used[base] ?? 0) + 1
            used[base] = count
            let token = count == 1 ? base : "\(base)_\(count)"
            out.append(CSVTokenDescriptor(token: token, header: header))
        }
        return out
    }

    private func normalizeHeaderToToken(_ header: String) -> String {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = NormalizedName.from(trimmed).tokens
        if !tokens.isEmpty {
            return tokens.joined(separator: "_")
        }

        // Fallback: keep only lowercase alphanumerics, join chunks with underscores.
        let lower = trimmed.lowercased()
        let parts = lower
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let joined = parts.joined(separator: "_")
        return joined.isEmpty ? "column" : joined
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field
    }

    private func attemptGenerate() {
        if selectedRecipientIDs.isEmpty {
            showingNoRecipientsSelectedAlert = true
            return
        }

        if !iapManager.isProUnlocked && selectedRecipientIDs.count > AppState.freeMaxRecipients {
            showingRecipientLimitAlert = true
            return
        }

        // Hide the recipient list + Message Template panel after starting generation to reduce screen clutter.
        isRecipientListExpanded = false
        isMessageTemplateExpanded = false
        messageTemplateFocus = nil
        generatePDFs()
    }
    
    private func generatePDFs() {
        guard let template = appState.pdfTemplate else { return }

        // Snapshot inputs on the main thread to avoid races while generating.
        let recipientsToGenerate = selectedRecipients
        
        isGenerating = true
        generatedPDFs.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var pdfs: [(Recipient, Data)] = []
            
            for recipient in recipientsToGenerate {
                if let pdfData = pdfService.generatePersonalizedPDF(template: template, recipient: recipient) {
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

        let email = resolvedEmail(for: item.recipient)
        if email.isEmpty {
            showingNoEmailForRowAlert = true
            return
        }

        let fallbackSubject = "\(templateName) PDF"
        let subjectAndBody = resolvedMailSubjectAndBody(for: item.recipient, fallbackSubject: fallbackSubject)

        let mailItem = MailItem(
            recipientName: displayName(for: item.recipient),
            recipientEmail: email,
            templateName: templateName,
            subject: subjectAndBody.subject,
            body: subjectAndBody.body,
            fileName: fileName,
            pdfData: item.pdfData
        )

        currentMailItem = mailItem
    }

    private func resolvedMailSubjectAndBody(for recipient: Recipient, fallbackSubject: String) -> (subject: String, body: String) {
        guard let template = appState.pdfTemplate else {
            return (fallbackSubject, "")
        }

        let mt = template.messageTemplate
        guard mt.isEnabled, mt.hasAnyContent else {
            return (fallbackSubject, "")
        }

        let headers = appState.csvImport?.headers ?? []
        let csvTokens = csvTokenCatalog(headers: headers)
        let csvTokenSet = Set(csvTokens.map { $0.token })
        let allowedTokens = MessageTemplateRenderer.systemTokens.union(csvTokenSet)

        let values = resolvedMessageTokenValues(for: recipient, messageTemplate: mt, csvTokens: csvTokens)
        let result = MessageTemplateRenderer.render(template: mt, allowedTokens: allowedTokens, resolvedValues: values)

        let subject = result.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackSubject : result.subject
        return (subject, result.body)
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
        if let column = appState.selectedEmailColumn?.trimmingCharacters(in: .whitespacesAndNewlines), !column.isEmpty {
            let fromColumn = recipient.value(forKey: column)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fromColumn.isEmpty {
                return fromColumn
            }
        }

        return recipient.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayName(for recipient: Recipient) -> String {
        // If we have a chosen/detected display-name column, try it first.
        if let column = appState.selectedDisplayNameColumn?.trimmingCharacters(in: .whitespacesAndNewlines), !column.isEmpty {
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

struct ExportBundle: Identifiable {
    let id = UUID()
    let shareURL: URL
    let cleanupURLs: [URL]
}

struct MailItem: Identifiable {
    let id = UUID()
    let recipientName: String
    let recipientEmail: String
    let templateName: String
    let subject: String
    let body: String
    let fileName: String
    let pdfData: Data
}

struct GenerateView_Previews: PreviewProvider {
    static var previews: some View {
        GenerateView()
            .environmentObject(AppState())
    }
}
