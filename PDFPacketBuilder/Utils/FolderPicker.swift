//
//  FolderPicker.swift
//  PDFPacketBuilder
//
//  UIKit wrapper to pick a destination folder (for batch export).
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FolderPicker: UIViewControllerRepresentable {
    var onSelected: (URL) -> Void
    var onFailure: ((Error) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPicker

        init(_ parent: FolderPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onSelected(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // No-op.
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            parent.onSelected(url)
        }
    }
}
