import UIKit

enum RideWeeklyReportPDF {
    static let pageSize = CGSize(width: 841.89, height: 595.28)

    @MainActor
    static func file(pages: [WeeklyReportPage], language: MovementLanguage) throws -> URL {
        guard !pages.isEmpty else { throw ReportExportError.empty }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MovementWeeklyReport.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { context in
            for page in pages {
                context.beginPage()
                draw(page, language: language, in: context.cgContext)
            }
        }
        return url
    }

    static func pages(from rides: [Ride], start: Date, end: Date, language: MovementLanguage) -> [WeeklyReportPage] {
        let calendar = ReportCalendar.calendar
        let dayNames = MovementText.dayNames(language)
        let kinds: [ActivityKind] = [.ride, .run, .walk]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.dateFormat = "d/MM/yy"

        let byDay = Dictionary(grouping: rides) { calendar.startOfDay(for: $0.date) }
        return ReportCalendar.weeks(from: start, to: end).map { days in
            WeeklyReportPage(
                dayNames: dayNames,
                dates: days.map { dateFormatter.string(from: $0) },
                rows: kinds.map { kind in
                    WeeklyReportPage.Row(
                        label: kind.label(language),
                        cells: days.map { day in
                            let matches = (byDay[calendar.startOfDay(for: day)] ?? [])
                                .filter { $0.kind == kind }
                                .sorted { $0.date < $1.date }
                            return matches.map { ride in
                                WeeklyReportPage.Item(
                                    title: RideSummary.clock(ride.movingSeconds),
                                    notes: RideSummary.notes(
                                        distanceMeters: ride.distanceMeters,
                                        movingSeconds: ride.movingSeconds,
                                        ascentMeters: ride.ascentMeters ?? 0,
                                        calories: ride.calories,
                                        language: language
                                    ),
                                    imageJPEG: nil
                                )
                            }
                        }
                    )
                }
            )
        }
    }

    private static func draw(_ page: WeeklyReportPage, language: MovementLanguage, in context: CGContext) {
        let margin: CGFloat = 10
        let bounds = CGRect(origin: .zero, size: pageSize).insetBy(dx: margin, dy: margin)
        let labelWidth: CGFloat = 88
        let dayCount = CGFloat(max(page.dayNames.count, 1))
        let dayWidth = (bounds.width - labelWidth) / dayCount
        let headerHeight: CGFloat = 20
        let dateHeight: CGFloat = 16
        let rowHeight = (bounds.height - headerHeight - dateHeight) / CGFloat(max(page.rows.count, 1))
        let rtl = language == .hebrew

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))

        func frame(column: Int, y: CGFloat, height: CGFloat) -> CGRect {
            let width = column == 0 ? labelWidth : dayWidth
            let x: CGFloat
            if rtl {
                x = column == 0
                    ? bounds.maxX - labelWidth
                    : bounds.maxX - labelWidth - CGFloat(column) * dayWidth
            } else {
                x = column == 0
                    ? bounds.minX
                    : bounds.minX + labelWidth + CGFloat(column - 1) * dayWidth
            }
            return CGRect(x: x, y: y, width: width, height: height)
        }

        var y = bounds.minY
        let headerColumns = [""] + page.dayNames
        for column in headerColumns.indices {
            let rect = frame(column: column, y: y, height: headerHeight)
            fill(rect, color: UIColor(white: 0.95, alpha: 1), in: context)
            drawCentered(headerColumns[column], in: rect, font: .systemFont(ofSize: 10, weight: .semibold), rtl: rtl)
            stroke(rect, in: context)
        }
        y += headerHeight

        let dateLabel = MovementText.t("תאריך", "Date", language)
        let dateColumns = [dateLabel] + page.dayNames.indices.map { index in
            index < page.dates.count ? page.dates[index] : ""
        }
        for column in dateColumns.indices {
            let rect = frame(column: column, y: y, height: dateHeight)
            if column == 0 {
                fill(rect, color: UIColor(white: 0.97, alpha: 1), in: context)
            }
            drawCentered(dateColumns[column], in: rect, font: .systemFont(ofSize: 8, weight: column == 0 ? .bold : .regular), rtl: rtl)
            stroke(rect, in: context)
        }
        y += dateHeight

        let bodyFont = UIFont.systemFont(ofSize: 8)
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        for row in page.rows {
            let labelRect = frame(column: 0, y: y, height: rowHeight)
            fill(labelRect, color: UIColor(white: 0.97, alpha: 1), in: context)
            drawCentered(row.label, in: labelRect, font: labelFont, rtl: rtl)
            stroke(labelRect, in: context)

            for index in page.dayNames.indices {
                let items = index < row.cells.count ? row.cells[index] : []
                let rect = frame(column: index + 1, y: y, height: rowHeight)
                drawItems(items, in: rect, font: bodyFont, language: language, context: context)
                stroke(rect, in: context)
            }
            y += rowHeight
        }
    }

    private static func drawItems(
        _ items: [WeeklyReportPage.Item],
        in rect: CGRect,
        font: UIFont,
        language: MovementLanguage,
        context: CGContext
    ) {
        let inset = rect.insetBy(dx: 3, dy: 3)
        guard inset.width > 1, inset.height > 1 else { return }
        let rtl = language == .hebrew
        context.saveGState()
        context.clip(to: inset)
        var cursor = inset.minY
        for item in items {
            if cursor >= inset.maxY { break }
            let titlePrefix = MovementText.t("זמן : ", "Time: ", language)
            cursor = drawText(
                titlePrefix + item.title,
                x: inset.minX,
                y: cursor,
                width: inset.width,
                maxY: inset.maxY,
                font: font,
                rtl: rtl
            )
            let notes = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                cursor = drawText(notes, x: inset.minX, y: cursor, width: inset.width, maxY: inset.maxY, font: font, rtl: rtl)
            }
            cursor += 4
        }
        context.restoreGState()
    }

    private static func drawText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        maxY: CGFloat,
        font: UIFont,
        rtl: Bool
    ) -> CGFloat {
        let remaining = maxY - y
        guard remaining >= font.lineHeight * 0.8 else { return y }
        let attrs = textAttributes(font: font, alignment: rtl ? .right : .left, rtl: rtl)
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

    private static func drawCentered(_ text: String, in rect: CGRect, font: UIFont, rtl: Bool) {
        let inset = rect.insetBy(dx: 2, dy: 1)
        guard inset.width > 1, inset.height > 1, !text.isEmpty else { return }
        let attrs = textAttributes(font: font, alignment: .center, rtl: rtl)
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

    private static func textAttributes(
        font: UIFont,
        alignment: NSTextAlignment,
        rtl: Bool
    ) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
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
