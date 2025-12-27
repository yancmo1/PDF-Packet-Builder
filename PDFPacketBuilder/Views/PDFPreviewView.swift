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
        
        if let document = PDFDocument(data: pdfData) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
    // Reload document only if the data size has changed (simple and reliable for v1)
    if let currentDoc = pdfView.document, currentDoc.dataRepresentation()?.count == pdfData.count {
        return
    }

    pdfView.document = PDFDocument(data: pdfData)
}
    }
}
