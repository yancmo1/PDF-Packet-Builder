//
//  QuickStartView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct QuickStartView: View {
    @AppStorage("showQuickStartOnLaunch") private var showQuickStartOnLaunch = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Welcome")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This app builds personalized PDFs from a fillable template and a recipient list.")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What to do")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Import a fillable PDF template")
                            Text("2. Import a CSV or add recipients")
                            Text("3. Map PDF fields")
                            Text("4. Generate PDFs")
                            Text("5. Share or Mail")
                        }
                        .foregroundColor(.secondary)
                    }

                    Toggle("Show on startup", isOn: $showQuickStartOnLaunch)

                    NavigationLink("How to Use", destination: HowToUseView())
                }
                .padding()
            }
            .navigationTitle("Quick Start")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuickStartView_Previews: PreviewProvider {
    static var previews: some View {
        QuickStartView()
    }
}
