//
//  SalesReport.swift
//  GrocartInc-IOS
//
//  Builds the monthly sales workbook from the on-device sales log.
//  Three sheets:
//   - "Monthly Summary": one row per store that had sales that month
//     (orders, items sold, subtotal, tax, tip, delivery charge,
//     discount, total amount), plus an "All Stores" total row. This is
//     the sheet that answers how much money each store generated,
//     broken down by total amount, tax, tip, and delivery charge.
//   - "Items Sold": one row per item sold that month (date, order,
//     store, category, product, quantity, unit price, line total).
//   - "By Category": one row per (category, store) pair that month
//     (items sold and total amount).
//  A month with no sales still produces a workbook with the three
//  sheets and only their header rows.
//

import Foundation

enum SalesReport {

    /// Builds the .xlsx workbook for the calendar month containing
    /// `date`, from the given log entries (which are filtered to that
    /// month inside). Returns nil only if the workbook cannot be built.
    static func workbook(forMonthContaining date: Date, entries: [SalesLogEntry]) -> Data? {
        let calendar = Calendar.current
        let target = calendar.dateComponents([.year, .month], from: date)
        let monthKey = String(format: "%04d-%02d", target.year ?? 0, target.month ?? 0)
        let monthEntries = entries.filter {
            let components = calendar.dateComponents([.year, .month], from: $0.date)
            return components.year == target.year && components.month == target.month
        }

        let summary = summarySheet(monthKey: monthKey, entries: monthEntries)
        let items = itemsSheet(entries: monthEntries)
        let byCategory = byCategorySheet(monthKey: monthKey, entries: monthEntries)
        return ExcelWriter.makeWorkbook(sheets: [summary, items, byCategory])
    }

    // MARK: - Monthly Summary

    private static func summarySheet(monthKey: String, entries: [SalesLogEntry]) -> ExcelSheet {
        let header: [ExcelCell] = [
            .text("Store"), .text("Month"), .text("Orders"), .text("Items Sold"),
            .text("Subtotal"), .text("Tax"), .text("Tip"), .text("Delivery Charge"),
            .text("Discount"), .text("Total Amount")
        ]

        // Group the month's entries by store.
        var byStore: [Int: (name: String, entries: [SalesLogEntry])] = [:]
        for entry in entries {
            if byStore[entry.storeId] == nil {
                byStore[entry.storeId] = (entry.storeName, [])
            }
            byStore[entry.storeId]?.entries.append(entry)
        }

        var rows: [[ExcelCell]] = [header]
        var totals = (orders: 0, items: 0, subtotal: 0.0, tax: 0.0, tip: 0.0, delivery: 0.0, discount: 0.0, total: 0.0)

        // One row per store, alphabetically by store name.
        for (_, group) in byStore.sorted(by: { $0.value.name < $1.value.name }) {
            let orders = group.entries.count
            let items = group.entries.reduce(0) { $0 + $1.itemCount }
            let subtotal = group.entries.reduce(0.0) { $0 + $1.subtotal }
            let tax = group.entries.reduce(0.0) { $0 + $1.tax }
            let tip = group.entries.reduce(0.0) { $0 + $1.tip }
            let delivery = group.entries.reduce(0.0) { $0 + $1.deliveryCharge }
            let discount = group.entries.reduce(0.0) { $0 + $1.discount }
            let total = group.entries.reduce(0.0) { $0 + $1.total }
            totals.orders += orders
            totals.items += items
            totals.subtotal += subtotal
            totals.tax += tax
            totals.tip += tip
            totals.delivery += delivery
            totals.discount += discount
            totals.total += total
            rows.append([
                .text(group.name), .text(monthKey),
                .number(Double(orders)), .number(Double(items)),
                .currency(subtotal), .currency(tax), .currency(tip),
                .currency(delivery), .currency(discount), .currency(total)
            ])
        }

        // "All Stores" total row.
        rows.append([
            .text("All Stores"), .text(monthKey),
            .number(Double(totals.orders)), .number(Double(totals.items)),
            .currency(totals.subtotal), .currency(totals.tax), .currency(totals.tip),
            .currency(totals.delivery), .currency(totals.discount), .currency(totals.total)
        ])

        return ExcelSheet(name: "Monthly Summary", rows: rows)
    }

    // MARK: - Items Sold

    private static func itemsSheet(entries: [SalesLogEntry]) -> ExcelSheet {
        let header: [ExcelCell] = [
            .text("Date"), .text("Order"), .text("Store"), .text("Category"),
            .text("Product"), .text("Quantity"), .text("Unit Price"), .text("Line Total")
        ]

        // A fresh formatter per export: this runs off the main thread, and
        // DateFormatter is not thread-safe to share.
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        // One row per item sold, sorted by date, then store, then
        // category, then product.
        var flat: [(date: Date, store: String, category: String, product: String, row: [ExcelCell])] = []
        for entry in entries {
            let dateText = dayFormatter.string(from: entry.date)
            for item in entry.items {
                flat.append((
                    date: entry.date,
                    store: entry.storeName,
                    category: item.categoryName,
                    product: item.productName,
                    row: [
                        .text(dateText), .text(entry.trackingId), .text(entry.storeName),
                        .text(item.categoryName), .text(item.productName),
                        .number(Double(item.quantity)),
                        .currency(item.unitPrice), .currency(item.lineTotal)
                    ]
                ))
            }
        }
        flat.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.store != $1.store { return $0.store < $1.store }
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.product < $1.product
        }

        return ExcelSheet(name: "Items Sold", rows: [header] + flat.map { $0.row })
    }

    // MARK: - By Category

    private static func byCategorySheet(monthKey: String, entries: [SalesLogEntry]) -> ExcelSheet {
        let header: [ExcelCell] = [
            .text("Category"), .text("Store"), .text("Month"),
            .text("Items Sold"), .text("Amount")
        ]

        // Group all items by (category, store).
        var grouped: [String: (category: String, store: String, quantity: Int, amount: Double)] = [:]
        for entry in entries {
            for item in entry.items {
                let key = "\(item.categoryName)\u{0}\(entry.storeName)"
                if grouped[key] == nil {
                    grouped[key] = (item.categoryName, entry.storeName, 0, 0)
                }
                grouped[key]?.quantity += item.quantity
                grouped[key]?.amount += item.lineTotal
            }
        }

        var rows: [[ExcelCell]] = [header]
        for (_, group) in grouped.sorted(by: {
            if $0.value.category != $1.value.category { return $0.value.category < $1.value.category }
            return $0.value.store < $1.value.store
        }) {
            rows.append([
                .text(group.category), .text(group.store), .text(monthKey),
                .number(Double(group.quantity)), .currency(group.amount)
            ])
        }

        return ExcelSheet(name: "By Category", rows: rows)
    }
}
