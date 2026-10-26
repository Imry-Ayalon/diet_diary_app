import UIKit

enum WeeklyReportPDF {
    static let pageSize = CGSize(width: 841.89, height: 595.28)

    @MainActor
    static func file(pages: [WeeklyReportPage]) throws -> URL {
        guard !pages.isEmpty else { throw ReportExportError.empty }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WeeklyReport.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { context in
            for page in pages {
                context.beginPage()
                draw(page, in: context.cgContext)
            }
        }
        return url
    }

    private static func draw(_ page: WeeklyReportPage, in context: CGContext) {
        let margin: CGFloat = 10
        let bounds = CGRect(origin: .zero, size: pageSize).insetBy(dx: margin, dy: margin)
        let labelWidth: CGFloat = 88
        let dayCount = CGFloat(max(page.dayNames.count, 1))
        let dayWidth = (bounds.width - labelWidth) / dayCount
        let headerHeight: CGFloat = 20
        let dateHeight: CGFloat = 16
        let rowHeight = (bounds.height - headerHeight - dateHeight) / CGFloat(max(page.rows.count, 1))

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))

        func frame(column: Int, y: CGFloat, height: CGFloat) -> CGRect {
            let width = column == 0 ? labelWidth : dayWidth
            let x = column == 0
                ? bounds.maxX - labelWidth
                : bounds.maxX - labelWidth - CGFloat(column) * dayWidth
            return CGRect(x: x, y: y, width: width, height: height)
        }

        var y = bounds.minY
        let headerColumns = [""] + page.dayNames
        for column in headerColumns.indices {
            let rect = frame(column: column, y: y, height: headerHeight)
            fill(rect, color: UIColor(white: 0.95, alpha: 1), in: context)
            drawCentered(headerColumns[column], in: rect, font: .systemFont(ofSize: 10, weight: .semibold))
            stroke(rect, in: context)
        }
        y += headerHeight

        let dateColumns = ["תאריך"] + page.dayNames.indices.map { index in
            index < page.dates.count ? page.dates[index] : ""
        }
        for column in dateColumns.indices {
            let rect = frame(column: column, y: y, height: dateHeight)
            if column == 0 {
                fill(rect, color: UIColor(white: 0.97, alpha: 1), in: context)
            }
            drawCentered(dateColumns[column], in: rect, font: .systemFont(ofSize: 8, weight: column == 0 ? .bold : .regular))
            stroke(rect, in: context)
        }
        y += dateHeight

        let bodyFont = UIFont.systemFont(ofSize: 8)
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        for row in page.rows {
            let labelRect = frame(column: 0, y: y, height: rowHeight)
            fill(labelRect, color: UIColor(white: 0.97, alpha: 1), in: context)
            drawCentered(row.label, in: labelRect, font: labelFont)
            stroke(labelRect, in: context)

            for index in page.dayNames.indices {
                let items = index < row.cells.count ? row.cells[index] : []
                let rect = frame(column: index + 1, y: y, height: rowHeight)
                drawItems(items, in: rect, font: bodyFont, context: context)
                stroke(rect, in: context)
            }
            y += rowHeight
        }
    }

    private static func drawItems(_ items: [WeeklyReportPage.Item], in rect: CGRect, font: UIFont, context: CGContext) {
        let inset = rect.insetBy(dx: 3, dy: 3)
        guard inset.width > 1, inset.height > 1 else { return }

        context.saveGState()
        context.clip(to: inset)
        var cursor = inset.minY
        for item in items {
            if cursor >= inset.maxY { break }
            if let data = item.imageJPEG, let image = UIImage(data: data) {
                let imageHeight: CGFloat = 22
                let imageWidth = min(56, inset.width)
                if cursor + imageHeight <= inset.maxY {
                    let imageRect = CGRect(
                        x: inset.maxX - imageWidth,
                        y: cursor,
                        width: imageWidth,
                        height: imageHeight
                    )
                    image.draw(in: imageRect)
                    cursor += imageHeight + 2
                }
            }
            cursor = drawText("תוכן : \(item.title)", x: inset.minX, y: cursor, width: inset.width, maxY: inset.maxY, font: font)
            let notes = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                cursor = drawText("הערות : \(notes)", x: inset.minX, y: cursor, width: inset.width, maxY: inset.maxY, font: font)
            }
            cursor += 4
        }
        context.restoreGState()
    }

    private static func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, maxY: CGFloat, font: UIFont) -> CGFloat {
        let remaining = maxY - y
        guard remaining >= font.lineHeight * 0.8 else { return y }
        let attrs = textAttributes(font: font, alignment: .right)
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        )
        let height = min(ceil(measured.height), remaining)
        let rect = CGRect(x: x, y: y, width: width, height: height)
        NSAttributedString(string: text, attributes: attrs).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            context: nil
        )
        return y + height
    }

    private static func drawCentered(_ text: String, in rect: CGRect, font: UIFont) {
        let inset = rect.insetBy(dx: 2, dy: 1)
        guard inset.width > 1, inset.height > 1, !text.isEmpty else { return }
        let attrs = textAttributes(font: font, alignment: .center)
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: inset.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        )
        let height = min(ceil(measured.height), inset.height)
        let textRect = CGRect(
            x: inset.minX,
            y: inset.minY + max(0, (inset.height - height) / 2),
            width: inset.width,
            height: height
        )
        NSAttributedString(string: text, attributes: attrs).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            context: nil
        )
    }

    private static func textAttributes(font: UIFont, alignment: NSTextAlignment) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = .rightToLeft
        style.lineBreakMode = .byWordWrapping
        return [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ]
    }

    private static func fill(_ rect: CGRect, color: UIColor, in context: CGContext) {
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    private static func stroke(_ rect: CGRect, in context: CGContext) {
        context.setStrokeColor(UIColor(white: 0.8, alpha: 1).cgColor)
        context.setLineWidth(0.6)
        context.stroke(rect)
    }
}
