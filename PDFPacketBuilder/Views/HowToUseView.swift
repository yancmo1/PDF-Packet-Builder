//
//  HowToUseView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct HowToUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Quick Start")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Build and send personalized, fillable PDFs from a CSV list. No backend.")
                        .foregroundColor(.secondary)
                }

                Group {
                    Text("1) Import a template")
                        .font(.headline)
                    Text("Go to Template and import a fillable PDF (AcroForm text fields).")
                        .foregroundColor(.secondary)
                }

                Group {
                    Text("2) Add recipients")
                        .font(.headline)
                    Text("Go to Recipients and import a CSV or add recipients manually.")
                        .foregroundColor(.secondary)
                }

                Group {
                    Text("3) Map fields")
                        .font(.headline)
                    Text("Go to Map and connect PDF fields to recipient data. Mapping is always manual.")
                        .foregroundColor(.secondary)
                }

                Group {
                    Text("4) Generate")
                        .font(.headline)
                    Text("Go to Generate, select recipients, then tap Generate PDFs.")
                        .foregroundColor(.secondary)

                    Text("Optional: Enable Message Template to create a per-recipient subject/body using tokens like {{recipient_name}} and CSV-header tokens.")
                        .foregroundColor(.secondary)
                }

                Group {
                    Text("5) Share or Mail")
                        .font(.headline)
                    Text("Use Share to hand off the generated PDF to another app, or Mail to open the Mail composer with the PDF attached.")
                        .foregroundColor(.secondary)

                    Text("Logs are recorded only after a confirmed delivery action:")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Share: logged only when the share completes")
                        Text("• Mail: logged only when Mail reports Sent")
                    }
                    .foregroundColor(.secondary)
                }

                Group {
                    Text("6) Logs and export")
                        .font(.headline)
                    Text("Go to Logs to view history and export as CSV.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("How to Use")
    }
}

struct HowToUseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HowToUseView()
        }
    }
}
