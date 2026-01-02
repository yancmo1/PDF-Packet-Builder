//
//  PDFPreviewView.swift
//  PDFPacketBuilder
//

import SwiftUI
import PDFKit
import CryptoKit

struct PDFPreviewView: UIViewControllerRepresentable {
    let pdfData: Data

    func makeUIViewController(context: Context) -> PDFPreviewViewController {
        let vc = PDFPreviewViewController()
        vc.setPDFData(pdfData)
        return vc
    }

    func updateUIViewController(_ uiViewController: PDFPreviewViewController, context: Context) {
        uiViewController.setPDFData(pdfData)
    }
}

final class PDFPreviewViewController: UIViewController {
    private let pdfView = PDFView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var lastSignature: String?
    private var hasAppliedInitialScale = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.backgroundColor = .systemBackground
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.startAnimating()

        view.addSubview(pdfView)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyScaleIfReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // PDFKit is sometimes blank on the first frame inside a SwiftUI sheet.
        // Re-apply scaling once the view is on-screen.
        DispatchQueue.main.async { [weak self] in
            self?.applyScaleIfReady(forceGoToFirstPage: true)
        }
    }

    func setPDFData(_ data: Data) {
        let signature = dataSignature(data)
        if signature == lastSignature, pdfView.document != nil {
            DispatchQueue.main.async { [weak self] in
                self?.applyScaleIfReady()
            }
            return
        }

        lastSignature = signature
        hasAppliedInitialScale = false
        spinner.startAnimating()

        let dataCopy = data
        DispatchQueue.global(qos: .userInitiated).async {
            let doc = PDFDocument(data: dataCopy)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.lastSignature == signature else { return }
                self.pdfView.document = nil
                self.pdfView.document = doc
                if (doc?.pageCount ?? 0) > 0 {
                    self.spinner.stopAnimating()
                }
                self.applyScaleIfReady(forceGoToFirstPage: true)
            }
        }
    }

    private func applyScaleIfReady(forceGoToFirstPage: Bool = false) {
        guard view.bounds.width > 2, view.bounds.height > 2 else { return }
        guard let doc = pdfView.document, doc.pageCount > 0 else { return }

        pdfView.autoScales = true
        if forceGoToFirstPage || !hasAppliedInitialScale {
            pdfView.goToFirstPage(nil)
        }
        hasAppliedInitialScale = true
    }

    private func dataSignature(_ data: Data) -> String {
        // PDF previews must reliably refresh when switching between generated PDFs.
        // A sampled signature can collide for similar PDFs; use a full hash instead.
        let digest = SHA256.hash(data: data)
        return "\(data.count)-\(Data(digest).base64EncodedString())"
    }
}