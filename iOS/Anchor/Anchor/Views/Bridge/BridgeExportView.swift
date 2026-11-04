//
//  BridgeExportView.swift
//  Anchor
//
//  Local-first, fully exportable: this renders the draft to a PDF on-device
//  and hands it to the system share sheet (which includes "Mail" alongside
//  everything else) — no custom backend, no upload anywhere.
//

import SwiftUI
import UIKit

struct BridgeExportView: View {
    let items: [BridgeDraftItem]
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
            .task {
                pdfURL = BridgeExporter.makePDF(items: items)
            }
        }
    }
}

enum BridgeExporter {
    static func makePDF(items: [BridgeDraftItem]) -> URL? {
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
                let title = "Bridge: notes for my session"
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
                    let prefix = item.isResolved ? "[already discussed] " : "• "
                    let text = prefix + item.text
                    let rect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 200)
                    let boundingRect = (text as NSString).boundingRect(
                        with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin, attributes: bodyAttributes, context: nil
                    )
                    text.draw(in: rect, withAttributes: bodyAttributes)
                    y += boundingRect.height + 4
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
