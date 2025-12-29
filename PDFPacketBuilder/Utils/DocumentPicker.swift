//
//  DocumentPicker.swift
//  PDFPacketSender
//
//  UIKit wrapper for document picker
//

import SwiftUI
import Foundation
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var contentTypes: [UTType] = [.pdf]
    var onSelected: (URL) -> Void = { _ in }
    var onPDFSelected: ((URL) -> Void)? = nil
    var onFailure: ((Error) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // `asCopy: true` is significantly more reliable for cloud providers (OneDrive/iCloud)
        // because the system hands the app a readable local copy.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
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

            // Cloud providers (OneDrive/iCloud) may require file coordination and can be slow.
            // Do the copy off the main thread, then call back on the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let didStartSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let localURL = try self.makeLocalCopy(of: url)
                    DispatchQueue.main.async {
                        if let onPDFSelected = self.parent.onPDFSelected {
                            onPDFSelected(localURL)
                        } else {
                            self.parent.onSelected(localURL)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.onFailure?(error)
                    }
                }
            }
        }

        private func makeLocalCopy(of sourceURL: URL) throws -> URL {
            let fileManager = FileManager.default
            let destinationDir = fileManager.temporaryDirectory
                .appendingPathComponent("PickedDocuments", isDirectory: true)

            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }

            // Keep the original filename so the UI shows the real PDF name.
            // Use a unique subfolder to avoid collisions.
            let uniqueDir = destinationDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
            if !fileManager.fileExists(atPath: uniqueDir.path) {
                try fileManager.createDirectory(at: uniqueDir, withIntermediateDirectories: true)
            }

            let destination = uniqueDir.appendingPathComponent(sourceURL.lastPathComponent)

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            // Coordinate reads for File Provider URLs.
            var coordinatedError: NSError?
            var resultURL: URL?
            var copyError: Error?

            NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinatedError) { coordinatedURL in
                do {
                    do {
                        try fileManager.copyItem(at: coordinatedURL, to: destination)
                        resultURL = destination
                    } catch {
                        // Fallback for providers that don't support copyItem well.
                        let data = try Data(contentsOf: coordinatedURL)
                        try data.write(to: destination, options: [.atomic])
                        resultURL = destination
                    }
                } catch {
                    copyError = error
                }
            }

            if let error = coordinatedError {
                throw error
            }
            if let error = copyError {
                throw error
            }
            if let resultURL = resultURL {
                return resultURL
            }

            throw DocumentPickerError.securityScopeDenied
        }
    }
}

enum DocumentPickerError: Error {
    case securityScopeDenied
}
