//
//  DocumentPicker.swift
//  PDFPacketSender
//
//  UIKit wrapper for document picker
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var contentTypes: [UTType] = [.pdf]
    var onSelected: (URL) -> Void = { _ in }
    var onPDFSelected: ((URL) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource and copy locally so async reads work reliably.
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let localURL = makeLocalCopy(of: url) ?? url

            if let onPDFSelected = parent.onPDFSelected {
                onPDFSelected(localURL)
            } else {
                parent.onSelected(localURL)
            }
        }

        private func makeLocalCopy(of sourceURL: URL) -> URL? {
            let fileManager = FileManager.default
            let destination = fileManager.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")

            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }

            do {
                try fileManager.copyItem(at: sourceURL, to: destination)
                return destination
            } catch {
                // Fallback for providers that don't support copyItem well.
                do {
                    let data = try Data(contentsOf: sourceURL)
                    try data.write(to: destination, options: [.atomic])
                    return destination
                } catch {
                    return nil
                }
            }
        }
    }
}
