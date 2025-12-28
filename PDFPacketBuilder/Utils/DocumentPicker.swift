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
    var onFailure: ((Error) -> Void)? = nil
    
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
            guard url.startAccessingSecurityScopedResource() else {
                parent.onFailure?(DocumentPickerError.securityScopeDenied)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let localURL = try makeLocalCopy(of: url)

                if let onPDFSelected = parent.onPDFSelected {
                    onPDFSelected(localURL)
                } else {
                    parent.onSelected(localURL)
                }
            } catch {
                parent.onFailure?(error)
            }
        }

        private func makeLocalCopy(of sourceURL: URL) throws -> URL {
            let fileManager = FileManager.default
            let destinationDir = fileManager.temporaryDirectory
                .appendingPathComponent("PickedDocuments", isDirectory: true)

            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }

            let destination = destinationDir.appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
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
                    throw error
                }
            }
        }
    }
}

enum DocumentPickerError: Error {
    case securityScopeDenied
}
