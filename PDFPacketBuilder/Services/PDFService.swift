//
//  PDFService.swift
//  PDFPacketSender
//
//  Service for PDF generation and field filling
//

import Foundation
import PDFKit

class PDFService {
    
    // Extract form fields from PDF
    func extractFields(from pdfData: Data) -> [PDFField] {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return [] }
        var fields: [PDFField] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Extract annotations (form fields)
            let annotations = page.annotations
            for annotation in annotations {
                if let fieldName = annotation.fieldName, !fieldName.isEmpty {
                    let field = PDFField(
                        name: fieldName,
                        type: determineFieldType(annotation),
                        defaultValue: annotation.widgetStringValue
                    )
                    fields.append(field)
                }
            }
        }
        
        return fields
    }
    
    private func determineFieldType(_ annotation: PDFAnnotation) -> PDFField.FieldType {
        // Simple heuristic based on widget type
        if annotation.widgetFieldType == .button {
            return .checkbox
        } else if annotation.widgetFieldType == .text {
            return .text
        } else {
            return .text
        }
    }
    
    // Generate personalized PDF for a recipient
    func generatePersonalizedPDF(template: PDFTemplate, recipient: Recipient) -> Data? {
        guard let pdfDocument = PDFDocument(data: template.pdfData) else { return nil }
        
        // Create a copy of the document
        guard let documentCopy = pdfDocument.copy() as? PDFDocument else { return nil }
        
        // Fill in fields based on mappings
        for pageIndex in 0..<documentCopy.pageCount {
            guard let page = documentCopy.page(at: pageIndex) else { continue }
            
            let annotations = page.annotations
            for annotation in annotations {
                if let fieldName = annotation.fieldName,
                   let mapping = template.fieldMappings[fieldName],
                   let value = recipient.value(forKey: mapping) {
                    
                    // Set the field value
                    annotation.setValue(value, forAnnotationKey: .widgetValue)
                    annotation.widgetStringValue = value
                }
            }
        }
        
        // Return the modified PDF data
        return documentCopy.dataRepresentation()
    }
    
    // Flatten PDF (make fields non-editable)
    func flattenPDF(data: Data) -> Data? {
        guard let pdfDocument = PDFDocument(data: data) else { return nil }
        
        // Create flattened version by removing annotations
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Remove all annotations (this effectively flattens the form)
            let annotations = page.annotations
            for annotation in annotations {
                page.removeAnnotation(annotation)
            }
        }
        
        return pdfDocument.dataRepresentation()
    }
}

