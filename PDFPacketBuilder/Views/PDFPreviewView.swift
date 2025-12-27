//
//  PDFPreviewView.swift
//  PDFPacketBuilder
//

import SwiftUI
import PDFKit

struct PDFPreviewView: UIViewRepresentable {
    let pdfData: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        pdfView.document = PDFDocument(data: pdfData)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Reload only if the underlying data appears different (simple v1 check).
        if let currentDoc = pdfView.document,
           let currentCount = currentDoc.dataRepresentation()?.count,
           currentCount == pdfData.count {
            return
        }

        pdfView.document = PDFDocument(data: pdfData)
    }
}