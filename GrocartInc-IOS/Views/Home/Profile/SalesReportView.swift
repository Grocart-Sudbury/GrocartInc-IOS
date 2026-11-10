//
//  SalesReportView.swift
//  GrocartInc-IOS
//
//  Monthly sales report: pick a month, see that month's totals, and
//  export a real .xlsx workbook (Monthly Summary, Items Sold, By
//  Category) through the iOS share sheet, so it can be saved to Files,
//  emailed, or sent anywhere else.
//
//  The report covers orders placed through the app on this device,
//  from when the sales log was added. Past orders cannot be backfilled:
//  the backend's order endpoints do not return tip, delivery charge,
//  or category.
//

import SwiftUI
import UIKit

struct SalesReportView: View {
    @ObservedObject private var salesLog = SalesLogManager.shared
    @State private var selectedMonth: Date?
    @State private var shareItem: ShareItem?
    @State private var isExporting = false
    @State private var exportError: String?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var months: [Date] { salesLog.availableMonths() }

    private var selectedEntries: [SalesLogEntry] {
        guard let month = selectedMonth else { return [] }
        return salesLog.entries(forMonthContaining: month)
    }

    private var totalSales: Double { selectedEntries.reduce(0) { $0 + $1.total } }
    private var orderCount: Int { selectedEntries.count }
    private var storeCount: Int { Set(selectedEntries.map(\.storeId)).count }
    private var itemsSold: Int { selectedEntries.reduce(0) { $0 + $1.itemCount } }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let fileMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private var selectedMonthLabel: String {
        guard let month = selectedMonth else { return "Select a month" }
        return Self.monthFormatter.string(from: month)
    }

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if months.isEmpty {
                        emptyState
                    } else {
                        monthPicker
                        summaryCard
                        exportButton
                        if let error = exportError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        noteCard
                    }
                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Sales Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedMonth == nil {
                selectedMonth = months.first
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(.grocartSecondary.opacity(0.5))
            Text("No sales logged yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.grocartPrimary)
            Text("Orders you place will appear here, and you can export them as an Excel file by month.")
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Month Picker

    private var monthPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Month")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.grocartSecondary)
            Picker("Month", selection: Binding(
                get: { selectedMonth ?? months.first ?? Date() },
                set: { selectedMonth = $0 }
            )) {
                ForEach(months, id: \.self) { month in
                    Text(Self.monthFormatter.string(from: month)).tag(month)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 16, tint: .clear)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            summaryRow(label: "Total sales", value: String(format: "$%.2f", totalSales), bold: true)
            Divider()
            summaryRow(label: "Orders", value: "\(orderCount)")
            summaryRow(label: "Stores", value: "\(storeCount)")
            summaryRow(label: "Items sold", value: "\(itemsSold)")
        }
        .padding(16)
        .glassCard(cornerRadius: 16, tint: .clear)
        .padding(.horizontal, 20)
    }

    private func summaryRow(label: String, value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: bold ? .semibold : .regular))
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: bold ? .bold : .semibold))
                .foregroundColor(.black)
        }
    }

    // MARK: - Export

    private var exportButton: some View {
        Button(action: exportExcel) {
            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Export Excel")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.blackPrimary)
        .disabled(isExporting || selectedEntries.isEmpty)
        .padding(.horizontal, 20)
    }

    private var noteCard: some View {
        Text("The file has three sheets: Monthly Summary (money per store, by total, tax, tip and delivery charge), Items Sold, and By Category. It covers orders placed through this app on this device.")
            .font(.system(size: 12))
            .foregroundColor(.grocartSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
    }

    // MARK: - Export

    private func exportExcel() {
        guard let month = selectedMonth else { return }
        exportError = nil
        isExporting = true
        // Capture the entries on the main actor, then build the workbook
        // off the main thread so a large log never blocks the UI.
        let allEntries = salesLog.entries
        let monthKey = Self.fileMonthFormatter.string(from: month)
        Task.detached {
            let data = SalesReport.workbook(forMonthContaining: month, entries: allEntries)
            let filename = "Grocart-Sales-\(monthKey).xlsx"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                guard let data else { throw NSError(domain: "SalesReport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not build the report."]) }
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    isExporting = false
                    shareItem = ShareItem(url: url)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = "Could not export the report. Please try again."
                }
            }
        }
    }
}

// MARK: - Share Sheet

/// Presents the iOS share sheet (save to Files, email, and so on).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
