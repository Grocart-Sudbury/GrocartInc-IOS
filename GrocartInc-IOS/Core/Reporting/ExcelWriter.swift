//
//  ExcelWriter.swift
//  GrocartInc-IOS
//
//  Builds a real .xlsx workbook in pure Swift (Foundation only, no
//  packages). An .xlsx file is a ZIP archive of XML files, so this
//  writes a minimal ZIP (entries stored uncompressed, which is valid
//  and which Excel accepts) and the XML parts a workbook needs.
//  Strings use inline strings, so no sharedStrings.xml is required.
//  Dates are written as text ("yyyy-MM-dd"), not Excel serial dates.
//

import Foundation

/// One cell in a worksheet.
enum ExcelCell {
    /// Plain text.
    case text(String)
    /// A plain number (quantities, counts).
    case number(Double)
    /// A money amount, shown with the currency style ($#,##0.00).
    case currency(Double)
}

/// One worksheet in a workbook.
struct ExcelSheet {
    let name: String
    let rows: [[ExcelCell]]
}

/// Builds a complete .xlsx file as Data. Returns nil when there are no
/// sheets to write.
enum ExcelWriter {

    static func makeWorkbook(sheets: [ExcelSheet]) -> Data? {
        guard !sheets.isEmpty else { return nil }
        let names = uniqueSheetNames(sheets.map { $0.name })

        var files: [(name: String, data: Data)] = []
        files.append(("[Content_Types].xml", Data(contentTypesXML(sheetCount: sheets.count).utf8)))
        files.append(("_rels/.rels", Data(rootRelsXML.utf8)))
        files.append(("xl/workbook.xml", Data(workbookXML(names: names).utf8)))
        files.append(("xl/_rels/workbook.xml.rels", Data(workbookRelsXML(sheetCount: sheets.count).utf8)))
        files.append(("xl/styles.xml", Data(stylesXML.utf8)))
        for (index, sheet) in sheets.enumerated() {
            files.append(("xl/worksheets/sheet\(index + 1).xml", Data(worksheetXML(sheet).utf8)))
        }
        return zip(files: files)
    }

    // MARK: - Sheet names

    /// Excel sheet names may not contain \ / ? * [ ] : and are at most
    /// 31 characters; they must also be unique within a workbook.
    private static func uniqueSheetNames(_ names: [String]) -> [String] {
        var used = Set<String>()
        return names.map { raw in
            var name = raw.components(separatedBy: CharacterSet(charactersIn: "\\/?*[]:")).joined(separator: " ")
            if name.count > 31 { name = String(name.prefix(31)) }
            if name.isEmpty { name = "Sheet" }
            var candidate = name
            var suffix = 2
            while used.contains(candidate) {
                candidate = String(name.prefix(29)) + " \(suffix)"
                suffix += 1
            }
            used.insert(candidate)
            return candidate
        }
    }

    // MARK: - XML parts

    private static func contentTypesXML(sheetCount: Int) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        xml += "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        xml += "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
        xml += "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
        xml += "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
        for index in 1...sheetCount {
            xml += "<Override PartName=\"/xl/worksheets/sheet\(index).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        xml += "</Types>"
        return xml
    }

    private static let rootRelsXML =
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>"
        + "</Relationships>"

    private static func workbookXML(names: [String]) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
        for (index, name) in names.enumerated() {
            xml += "<sheet name=\"\(escapeXML(name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }
        xml += "</sheets></workbook>"
        return xml
    }

    private static func workbookRelsXML(sheetCount: Int) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        for index in 1...sheetCount {
            xml += "<Relationship Id=\"rId\(index)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(index).xml\"/>"
        }
        xml += "<Relationship Id=\"rId\(sheetCount + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        xml += "</Relationships>"
        return xml
    }

    /// Minimal styles: a default font, a bold font for the header row,
    /// a currency number format, and cell formats for default, bold
    /// header, currency, and bold currency.
    private static let stylesXML =
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        + "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
        + "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"&quot;$&quot;#,##0.00\"/></numFmts>"
        + "<fonts count=\"2\">"
        + "<font><sz val=\"11\"/><color theme=\"1\"/><name val=\"Calibri\"/><family val=\"2\"/></font>"
        + "<font><b/><sz val=\"11\"/><color theme=\"1\"/><name val=\"Calibri\"/><family val=\"2\"/></font>"
        + "</fonts>"
        + "<fills count=\"2\">"
        + "<fill><patternFill patternType=\"none\"/></fill>"
        + "<fill><patternFill patternType=\"gray125\"/></fill>"
        + "</fills>"
        + "<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"
        + "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"
        + "<cellXfs count=\"4\">"
        + "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>"
        + "<xf numFmtId=\"0\" fontId=\"1\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyFont=\"1\"/>"
        + "<xf numFmtId=\"164\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"
        + "<xf numFmtId=\"164\" fontId=\"1\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyFont=\"1\" applyNumberFormat=\"1\"/>"
        + "</cellXfs>"
        + "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>"
        + "</styleSheet>"

    // MARK: - Worksheets

    private static func worksheetXML(_ sheet: ExcelSheet) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
        let columnCount = sheet.rows.map { $0.count }.max() ?? 0
        if columnCount > 0 {
            xml += "<cols>"
            for col in 0..<columnCount {
                xml += "<col min=\"\(col + 1)\" max=\"\(col + 1)\" width=\"\(widthForColumn(sheet, col))\" customWidth=\"1\"/>"
            }
            xml += "</cols>"
        }
        xml += "<sheetData>"
        for (rowIndex, row) in sheet.rows.enumerated() {
            let rowNumber = rowIndex + 1
            xml += "<row r=\"\(rowNumber)\">"
            for (colIndex, cell) in row.enumerated() {
                let ref = columnLetter(colIndex) + "\(rowNumber)"
                // The first row is the bold header row.
                let isHeader = rowIndex == 0
                switch cell {
                case .text(let value):
                    let style = isHeader ? " s=\"1\"" : ""
                    xml += "<c r=\"\(ref)\"\(style) t=\"inlineStr\"><is><t>\(escapeXML(value))</t></is></c>"
                case .number(let value):
                    xml += "<c r=\"\(ref)\"><v>\(numberString(value))</v></c>"
                case .currency(let value):
                    xml += "<c r=\"\(ref)\" s=\"2\"><v>\(currencyString(value))</v></c>"
                }
            }
            xml += "</row>"
        }
        xml += "</sheetData></worksheet>"
        return xml
    }

    /// Text columns get 18, numbers and currency 14; the Product
    /// column gets 22 so product names have room.
    private static func widthForColumn(_ sheet: ExcelSheet, _ col: Int) -> Double {
        if let header = sheet.rows.first, col < header.count,
           case .text(let heading) = header[col], heading.lowercased() == "product" {
            return 22
        }
        if sheet.rows.count > 1, col < sheet.rows[1].count {
            switch sheet.rows[1][col] {
            case .number, .currency:
                return 14
            case .text:
                return 18
            }
        }
        return 18
    }

    /// 0 -> "A", 25 -> "Z", 26 -> "AA".
    private static func columnLetter(_ index: Int) -> String {
        var n = index
        var letters = ""
        repeat {
            let remainder = n % 26
            letters = String(UnicodeScalar(65 + remainder)!) + letters
            n = n / 26 - 1
        } while n >= 0
        return letters
    }

    /// Locale-independent number formatting (a comma decimal separator
    /// would make the XML value invalid for Excel).
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func numberString(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private static func currencyString(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private static func escapeXML(_ text: String) -> String {
        // Ampersand first, so the entities below are not double-escaped.
        var out = text
        out = out.replacingOccurrences(of: "&", with: "&amp;")
        out = out.replacingOccurrences(of: "<", with: "&lt;")
        out = out.replacingOccurrences(of: ">", with: "&gt;")
        out = out.replacingOccurrences(of: "\"", with: "&quot;")
        out = out.replacingOccurrences(of: "'", with: "&apos;")
        return out
    }

    // MARK: - ZIP (stored entries, method 0)

    private static let crcTable: [UInt32] = {
        (0..<256).map { i in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = crcTable[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    private static func dosDateTime(for date: Date) -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, components.year ?? 1980)
        let dosDate = UInt16(((year - 1980) << 9) | ((components.month ?? 1) << 5) | (components.day ?? 1))
        let dosTime = UInt16(((components.hour ?? 0) << 11) | ((components.minute ?? 0) << 5) | ((components.second ?? 0) / 2))
        return (dosTime, dosDate)
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 4))
    }

    /// Packs the files into a ZIP archive. Entries are stored
    /// uncompressed (method 0), which is valid in a ZIP and which
    /// Excel accepts.
    private static func zip(files: [(name: String, data: Data)]) -> Data {
        var out = Data()
        var central = Data()
        let (dosTime, dosDate) = dosDateTime(for: Date())

        for file in files {
            let nameData = Data(file.name.utf8)
            let crc = crc32(file.data)
            let offset = UInt32(out.count)

            // Local File Header
            appendUInt32(0x04034b50, to: &out)
            appendUInt16(20, to: &out) // version needed
            appendUInt16(0, to: &out) // flags
            appendUInt16(0, to: &out) // method 0 (stored)
            appendUInt16(dosTime, to: &out)
            appendUInt16(dosDate, to: &out)
            appendUInt32(crc, to: &out)
            appendUInt32(UInt32(file.data.count), to: &out) // compressed size
            appendUInt32(UInt32(file.data.count), to: &out) // uncompressed size
            appendUInt16(UInt16(nameData.count), to: &out)
            appendUInt16(0, to: &out) // extra length
            out.append(nameData)
            out.append(file.data)

            // Central Directory Header
            appendUInt32(0x02014b50, to: &central)
            appendUInt16(20, to: &central) // version made by
            appendUInt16(20, to: &central) // version needed
            appendUInt16(0, to: &central) // flags
            appendUInt16(0, to: &central) // method 0 (stored)
            appendUInt16(dosTime, to: &central)
            appendUInt16(dosDate, to: &central)
            appendUInt32(crc, to: &central)
            appendUInt32(UInt32(file.data.count), to: &central)
            appendUInt32(UInt32(file.data.count), to: &central)
            appendUInt16(UInt16(nameData.count), to: &central)
            appendUInt16(0, to: &central) // extra length
            appendUInt16(0, to: &central) // comment length
            appendUInt16(0, to: &central) // disk number
            appendUInt16(0, to: &central) // internal attributes
            appendUInt32(0, to: &central) // external attributes
            appendUInt32(offset, to: &central)
            central.append(nameData)
        }

        let centralOffset = UInt32(out.count)
        out.append(central)

        // End of Central Directory
        appendUInt32(0x06054b50, to: &out)
        appendUInt16(0, to: &out) // disk number
        appendUInt16(0, to: &out) // central directory disk
        appendUInt16(UInt16(files.count), to: &out) // entries on this disk
        appendUInt16(UInt16(files.count), to: &out) // total entries
        appendUInt32(UInt32(central.count), to: &out) // central directory size
        appendUInt32(centralOffset, to: &out) // central directory offset
        appendUInt16(0, to: &out) // comment length
        return out
    }
}
