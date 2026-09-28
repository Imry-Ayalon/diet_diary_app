import SwiftUI
import WebKit
import PDFKit

enum ReportCalendar {
    static let pageLimit = 12
    
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "he_IL")
        calendar.firstWeekday = 1
        return calendar
    }
    
    static func weeks(from start: Date, to end: Date) -> [[Date]] {
        let calendar = calendar
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        let startWeekday = calendar.component(.weekday, from: first)
        let sunday = calendar.date(byAdding: .day, value: 1 - startWeekday, to: first) ?? first
        
        var weeks: [[Date]] = []
        var cursor = sunday
        while cursor <= last {
            let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: cursor) }
            weeks.append(days)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return weeks
    }
    
    static func thisWeek() -> (start: Date, end: Date) {
        week(containing: Date())
    }
    
    static func previousWeek() -> (start: Date, end: Date) {
        let calendar = calendar
        let current = thisWeek().start
        let previous = calendar.date(byAdding: .day, value: -7, to: current) ?? current
        return week(containing: previous)
    }
    
    static func thisMonth() -> (start: Date, end: Date) {
        month(containing: Date())
    }
    
    static func previousMonth() -> (start: Date, end: Date) {
        let calendar = calendar
        let thisStart = thisMonth().start
        let previous = calendar.date(byAdding: .month, value: -1, to: thisStart) ?? thisStart
        return month(containing: previous)
    }
    
    private static func week(containing date: Date) -> (start: Date, end: Date) {
        let days = weeks(from: date, to: date).first ?? [date]
        return (days.first ?? date, days.last ?? date)
    }
    
    private static func month(containing date: Date) -> (start: Date, end: Date) {
        let calendar = calendar
        let parts = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: parts) ?? date
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let end = calendar.date(byAdding: .day, value: dayCount - 1, to: start) ?? start
        return (start, end)
    }
}

enum WeeklyReportPDF {
    static let pageSize = CGSize(width: 841.89, height: 595.28)
    
    @MainActor
    static func file(pages htmlPages: [String]) async throws -> URL {
        guard !htmlPages.isEmpty else { throw ReportExportError.empty }
        
        let webView = WKWebView(frame: CGRect(origin: CGPoint(x: 0, y: -4000), size: pageSize))
        webView.isOpaque = false
        webView.backgroundColor = .white
        
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        window?.addSubview(webView)
        defer { webView.removeFromSuperview() }
        
        let document = PDFDocument()
        for html in htmlPages {
            try await load(html, in: webView)
            try await Task.sleep(for: .milliseconds(80))
            
            let configuration = WKPDFConfiguration()
            configuration.rect = CGRect(origin: .zero, size: pageSize)
            let data = try await webView.pdf(configuration: configuration)
            guard let pageDocument = PDFDocument(data: data), let page = pageDocument.page(at: 0) else {
                continue
            }
            page.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
            document.insert(page, at: document.pageCount)
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WeeklyReport.pdf")
        guard document.pageCount > 0, document.write(to: url) else {
            throw ReportExportError.writeFailed
        }
        return url
    }
    
    @MainActor
    private static func load(_ html: String, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let waiter = NavigationWaiter(continuation: continuation)
            objc_setAssociatedObject(webView, &navigationWaiterKey, waiter, .OBJC_ASSOCIATION_RETAIN)
            webView.navigationDelegate = waiter
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

enum ReportExportError: Error {
    case empty
    case writeFailed
}

private var navigationWaiterKey: UInt8 = 0

private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private let continuation: CheckedContinuation<Void, Error>
    private var resumed = false
    
    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }
    
    private func finish(_ error: Error?) {
        guard !resumed else { return }
        resumed = true
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

func presentShareSheet(url: URL) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
        return
    }
    var presenter = root
    while let presented = presenter.presentedViewController {
        presenter = presented
    }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    presenter.present(controller, animated: true)
}
