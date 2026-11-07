//
//  BridgeExportView.swift
//  Anchor
//
//  Local-first, fully exportable: this renders the draft to a PDF on-device
//  and hands it to the system share sheet (which includes "Mail" alongside
//  everything else) — no custom backend, no upload anywhere.
//

import SwiftUI
import SwiftData
import UIKit

struct BridgeExportView: View {
    let items: [BridgeDraftItem]
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]
    @State private var forProviderID: UUID?
    @State private var pdfURL: URL?

    /// The export label of the provider chosen, if any. Never the name as
    /// shown in the app unless no label was written.
    private var chosenName: String? {
        providers.first { $0.id == forProviderID }?.exportName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if !providers.isEmpty {
                    Picker("Notes for", selection: $forProviderID) {
                        Text("No one in particular").tag(UUID?.none)
                        ForEach(providers) { provider in
                            Text(provider.exportName).tag(UUID?.some(provider.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Share / email PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ProgressView("Preparing PDF…")
                }
            }
            .padding()
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: forProviderID) {
                pdfURL = nil
                pdfURL = BridgeExporter.makePDF(items: items, forName: chosenName)
            }
        }
    }
}

enum BridgeExporter {
    static func makePDF(items: [BridgeDraftItem], forName: String? = nil) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bridge-\(Date().timeIntervalSince1970).pdf")

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = margin

                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20)
                ]
                let title = forName.map { "Bridge: notes for \($0)" } ?? "Bridge: notes for my session"
                title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
                y += 36

                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray
                ]
                Date().formatted(date: .abbreviated, time: .shortened).draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttributes)
                y += 28

                let bodyAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13)]
                let subAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray
                ]

                for item in items {
                    if y > pageHeight - margin - 60 {
                        context.beginPage()
                        y = margin
                    }
                    let prefix: String
                    if item.isQuestion {
                        prefix = item.isResolved ? "[asked] Question: " : "Question: "
                    } else {
                        prefix = item.isResolved ? "[already discussed] " : "• "
                    }
                    var paragraphs = [prefix + item.text]
                    let answer = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if item.isQuestion, !answer.isEmpty { paragraphs.append("Answer: " + answer) }
                    for text in paragraphs {
                        let rect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 200)
                        let boundingRect = (text as NSString).boundingRect(
                            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                            options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil
                        )
                        text.draw(in: rect, withAttributes: bodyAttributes)
                        y += boundingRect.height + 4
                    }
                    item.createdAt.formatted(date: .abbreviated, time: .omitted)
                        .draw(at: CGPoint(x: margin, y: y), withAttributes: subAttributes)
                    y += 20
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
