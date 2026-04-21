//
//  MonthReportData.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// Services/ReportGenerator.swift
import Foundation
import UIKit
internal import CoreData

// MARK: - Report Data Models

struct MonthReportData {
    var monthLabel:    String   // "March 2026"
    var monthKey:      String   // "2026-03"
    var totalIncome:   Double
    var totalExpense:  Double
    var netBalance:    Double
    var transactions:  [TransactionEntity]

    var expenseByCategory: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: transactions.filter { $0.type == "expense" }) {
            $0.category ?? "Other"
        }.mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.sorted { $0.value > $1.value } as! [(category: String, amount: Double)]
    }

    var incomeByCategory: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: transactions.filter { $0.type == "income" }) {
            $0.category ?? "Other"
        }.mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.sorted { $0.value > $1.value } as! [(category: String, amount: Double)]
    }
}

struct FullReport {
    var months:        [MonthReportData]
    var generatedAt:   Date
    var currency:      String

    var grandIncome:   Double { months.reduce(0) { $0 + $1.totalIncome } }
    var grandExpense:  Double { months.reduce(0) { $0 + $1.totalExpense } }
    var grandBalance:  Double { grandIncome - grandExpense }

    var savingsRate: Double {
        guard grandIncome > 0 else { return 0 }
        return (grandBalance / grandIncome) * 100
    }

    var dateRangeLabel: String {
        guard let first = months.first, let last = months.last else { return "" }
        if months.count == 1 { return first.monthLabel }
        return "\(first.monthLabel) – \(last.monthLabel)"
    }
}

// MARK: - Report Generator

class ReportGenerator {

    static let shared = ReportGenerator()
    private init() {}

    private let coreData = CoreDataManager.shared

    // MARK: - Build Report Data
    func buildReport(monthCount: Int) -> FullReport {
        let calendar  = Calendar.current
        let now       = Date()
        var months:   [MonthReportData] = []

        let monthFmt        = DateFormatter()
        monthFmt.dateFormat = "yyyy-MM"
        let labelFmt        = DateFormatter()
        labelFmt.dateFormat = "MMMM yyyy"

        for i in stride(from: monthCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now)
            else { continue }

            let month = calendar.component(.month, from: date)
            let year  = calendar.component(.year,  from: date)

            var comps   = DateComponents()
            comps.year  = year
            comps.month = month
            comps.day   = 1
            let monthDate = calendar.date(from: comps) ?? date
            let monthKey  = monthFmt.string(from: monthDate)

            let summaries = coreData.fetchAllSummaries()
                .filter { $0.date?.hasPrefix(monthKey) == true }

            let income  = summaries.reduce(0) { $0 + $1.totalIncome }
            let expense = summaries.reduce(0) { $0 + $1.totalExpense }

            let txs = coreData.fetchTransactions(month: month, year: year)

            months.append(MonthReportData(
                monthLabel:   labelFmt.string(from: monthDate),
                monthKey:     monthKey,
                totalIncome:  income,
                totalExpense: expense,
                netBalance:   income - expense,
                transactions: txs
            ))
        }

        return FullReport(
            months:      months,
            generatedAt: now,
            currency:    UserPreferences.shared.currency
        )
    }

    // MARK: - Generate CSV
    func generateCSV(report: FullReport) -> String {
        let prefs = UserPreferences.shared
        var lines: [String] = []

        // Header
        lines.append("DailyFinance Report")
        lines.append("Period,\(report.dateRangeLabel)")
        lines.append("Generated,\(formatDate(report.generatedAt))")
        lines.append("Currency,\(report.currency)")
        lines.append("")

        // Summary
        lines.append("SUMMARY")
        lines.append("Total Income,\(prefs.format(report.grandIncome))")
        lines.append("Total Expense,\(prefs.format(report.grandExpense))")
        lines.append("Net Balance,\(prefs.format(report.grandBalance))")
        lines.append("Savings Rate,\(String(format: "%.1f%%", report.savingsRate))")
        lines.append("")

        // Monthly breakdown
        lines.append("MONTHLY BREAKDOWN")
        lines.append("Month,Income,Expense,Net Balance")
        for month in report.months {
            lines.append("\(month.monthLabel),\(prefs.format(month.totalIncome)),\(prefs.format(month.totalExpense)),\(prefs.format(month.netBalance))")
        }
        lines.append("")

        // Transactions
        lines.append("TRANSACTIONS")
        lines.append("Date,Type,Category,Note,Amount")

        let dateFmt        = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        for month in report.months {
            let sorted = month.transactions.sorted {
                ($0.date ?? Date()) < ($1.date ?? Date())
            }
            for tx in sorted {
                let date     = dateFmt.string(from: tx.date ?? Date())
                let type_    = tx.type     ?? ""
                let category = tx.category ?? ""
                let note     = (tx.note    ?? "").replacingOccurrences(of: ",", with: ";")
                let amount   = prefs.format(tx.amount)
                lines.append("\(date),\(type_),\(category),\(note),\(amount)")
            }
        }

        // Category breakdown
        lines.append("")
        lines.append("EXPENSE BY CATEGORY")
        lines.append("Category,Amount")

        let allExpenses = report.months.flatMap { $0.transactions }.filter { $0.type == "expense" }
        let byCat = Dictionary(grouping: allExpenses) { $0.category ?? "Other" }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }

        for (cat, amount) in byCat {
            lines.append("\(cat),\(prefs.format(amount))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Generate PDF
    // Uses UIGraphicsPDFRenderer — no external dependencies
    func generatePDF(report: FullReport) -> Data {
        let pageWidth:  CGFloat = 595   // A4
        let pageHeight: CGFloat = 842
        let margin:     CGFloat = 40
        let contentW:   CGFloat = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let prefs = UserPreferences.shared

        return renderer.pdfData { ctx in
            var y: CGFloat = 0

            // Helper to start a new page
            func newPage() {
                ctx.beginPage()
                y = margin
            }

            // Helper to check if we need a new page
            func checkPageBreak(needing height: CGFloat) {
                if y + height > pageHeight - margin {
                    newPage()
                }
            }

            // ── Fonts & Colors ────────────────────────────────
            let titleFont    = UIFont.systemFont(ofSize: 22, weight: .bold)
            let heading1Font = UIFont.systemFont(ofSize: 14, weight: .bold)
            let heading2Font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let bodyFont     = UIFont.systemFont(ofSize: 10, weight: .regular)
            let captionFont  = UIFont.systemFont(ofSize: 8,  weight: .regular)

            let primaryColor   = UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
            let secondaryColor = UIColor.secondaryLabel
            let redColor       = UIColor.systemRed
            let bgColor        = UIColor(red: 0.95, green: 0.98, blue: 0.95, alpha: 1)

            func attrs(_ font: UIFont, _ color: UIColor = .label,
                       alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
                let para = NSMutableParagraphStyle()
                para.alignment = alignment
                return [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: para
                ]
            }

            func drawText(_ text: String, at point: CGPoint,
                          font: UIFont, color: UIColor = .label,
                          alignment: NSTextAlignment = .left,
                          maxWidth: CGFloat? = nil) -> CGFloat {
                let w = maxWidth ?? contentW
                let a = attrs(font, color, alignment: alignment)
                let rect = CGRect(x: point.x, y: point.y, width: w, height: 500)
                let bRect = text.boundingRect(with: CGSize(width: w, height: 500),
                                              options: .usesLineFragmentOrigin,
                                              attributes: a, context: nil)
                text.draw(in: CGRect(x: point.x, y: point.y,
                                     width: w, height: bRect.height),
                          withAttributes: a)
                return bRect.height
            }

            func drawLine(y: CGFloat, color: UIColor = .separator) {
                color.setStroke()
                let path = UIBezierPath()
                path.move(to:    CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                path.lineWidth = 0.5
                path.stroke()
            }

            func drawRect(_ rect: CGRect, color: UIColor, cornerRadius: CGFloat = 6) {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                color.setFill()
                path.fill()
            }

            // ── PAGE 1: Cover + Summary ───────────────────────
            newPage()

            // Header banner
            drawRect(CGRect(x: 0, y: 0, width: pageWidth, height: 100),
                     color: primaryColor, cornerRadius: 0)

            _ = drawText("DailyFinance",
                         at: CGPoint(x: margin, y: 24),
                         font: titleFont, color: .white)
            _ = drawText("Financial Report",
                         at: CGPoint(x: margin, y: 52),
                         font: heading2Font, color: UIColor.white.withAlphaComponent(0.85))
            _ = drawText(report.dateRangeLabel,
                         at: CGPoint(x: margin, y: 70),
                         font: captionFont, color: UIColor.white.withAlphaComponent(0.7))

            // Generated date (right side)
            _ = drawText("Generated: \(formatDate(report.generatedAt))",
                         at: CGPoint(x: margin, y: 80),
                         font: captionFont, color: UIColor.white.withAlphaComponent(0.6),
                         alignment: .right, maxWidth: contentW)

            y = 120

            // Summary box
            let summaryH: CGFloat = 100
            drawRect(CGRect(x: margin, y: y, width: contentW, height: summaryH),
                     color: bgColor)

            let colW = contentW / 3
            let summaryItems: [(String, String, UIColor)] = [
                ("Total Income",  prefs.format(report.grandIncome),   primaryColor),
                ("Total Expense", prefs.format(report.grandExpense),  redColor),
                ("Net Balance",   prefs.format(report.grandBalance),
                 report.grandBalance >= 0 ? primaryColor : redColor),
            ]
            for (i, item) in summaryItems.enumerated() {
                let x = margin + CGFloat(i) * colW
                _ = drawText(item.0,
                             at: CGPoint(x: x + 8, y: y + 12),
                             font: captionFont, color: secondaryColor,
                             maxWidth: colW - 16)
                _ = drawText(item.1,
                             at: CGPoint(x: x + 8, y: y + 28),
                             font: heading1Font, color: item.2,
                             maxWidth: colW - 16)
            }

            // Savings rate
            _ = drawText(
                "Savings Rate: \(String(format: "%.1f%%", report.savingsRate))   |   Period: \(report.dateRangeLabel)   |   Currency: \(report.currency)",
                at: CGPoint(x: margin + 8, y: y + 70),
                font: captionFont, color: secondaryColor
            )

            y += summaryH + 20

            // ── Monthly Breakdown Table ───────────────────────
            checkPageBreak(needing: 30)
            _ = drawText("Monthly Breakdown",
                         at: CGPoint(x: margin, y: y),
                         font: heading1Font)
            y += 22

            // Table header
            drawRect(CGRect(x: margin, y: y, width: contentW, height: 20),
                     color: UIColor.systemGray5)
            let cols: [(String, CGFloat)] = [
                ("Month", 0.35), ("Income", 0.22),
                ("Expense", 0.22), ("Net Balance", 0.21)
            ]
            var xOff: CGFloat = margin + 6
            for (label, frac) in cols {
                let w = contentW * frac
                _ = drawText(label, at: CGPoint(x: xOff, y: y + 4),
                             font: heading2Font, maxWidth: w - 6)
                xOff += w
            }
            y += 20

            for (idx, month) in report.months.enumerated() {
                checkPageBreak(needing: 22)
                if idx % 2 == 1 {
                    drawRect(CGRect(x: margin, y: y, width: contentW, height: 20),
                             color: UIColor.systemGray6)
                }
                xOff = margin + 6
                let rowData: [(String, UIColor)] = [
                    (month.monthLabel,               .label),
                    (prefs.format(month.totalIncome),  primaryColor),
                    (prefs.format(month.totalExpense), redColor),
                    (prefs.format(month.netBalance),
                     month.netBalance >= 0 ? primaryColor : redColor),
                ]
                for ((_, frac), (text, color)) in zip(cols, rowData) {
                    let w = contentW * frac
                    _ = drawText(text, at: CGPoint(x: xOff, y: y + 4),
                                 font: bodyFont, color: color, maxWidth: w - 6)
                    xOff += w
                }
                y += 20
            }

            // Totals row
            checkPageBreak(needing: 22)
            drawRect(CGRect(x: margin, y: y, width: contentW, height: 22),
                     color: primaryColor.withAlphaComponent(0.15))
            xOff = margin + 6
            let totalData: [(String, UIColor)] = [
                ("TOTAL",                          .label),
                (prefs.format(report.grandIncome),   primaryColor),
                (prefs.format(report.grandExpense),  redColor),
                (prefs.format(report.grandBalance),
                 report.grandBalance >= 0 ? primaryColor : redColor),
            ]
            for ((_, frac), (text, color)) in zip(cols, totalData) {
                let w = contentW * frac
                _ = drawText(text, at: CGPoint(x: xOff, y: y + 5),
                             font: heading2Font, color: color, maxWidth: w - 6)
                xOff += w
            }
            y += 30

            // ── Category Breakdown ────────────────────────────
            checkPageBreak(needing: 30)
            _ = drawText("Expense by Category",
                         at: CGPoint(x: margin, y: y), font: heading1Font)
            y += 22

            let allExpenses = report.months.flatMap { $0.transactions }
                .filter { $0.type == "expense" }
            let byCat = Dictionary(grouping: allExpenses) { $0.category ?? "Other" }
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
                .sorted { $0.value > $1.value }
            let totalExp = byCat.reduce(0) { $0 + $1.value }

            for (i, (cat, amount)) in byCat.prefix(10).enumerated() {
                checkPageBreak(needing: 24)
                let pct    = totalExp > 0 ? amount / totalExp : 0
                let barW   = contentW * 0.45
                let barH:  CGFloat = 8

                if i % 2 == 1 {
                    drawRect(CGRect(x: margin, y: y - 2, width: contentW, height: 22),
                             color: UIColor.systemGray6)
                }

                // Category name
                _ = drawText(cat, at: CGPoint(x: margin + 4, y: y + 2),
                             font: bodyFont, maxWidth: 100)

                // Bar background
                drawRect(CGRect(x: margin + 110, y: y + 5, width: barW, height: barH),
                         color: UIColor.systemGray5, cornerRadius: 3)
                // Bar fill
                drawRect(CGRect(x: margin + 110, y: y + 5,
                                width: barW * CGFloat(pct), height: barH),
                         color: redColor.withAlphaComponent(0.7), cornerRadius: 3)

                // Percentage
                _ = drawText(String(format: "%.1f%%", pct * 100),
                             at: CGPoint(x: margin + 110 + barW + 6, y: y + 2),
                             font: captionFont, color: secondaryColor, maxWidth: 40)

                // Amount
                _ = drawText(prefs.format(amount),
                             at: CGPoint(x: pageWidth - margin - 70, y: y + 2),
                             font: bodyFont, color: redColor,
                             alignment: .right, maxWidth: 70)
                y += 22
            }

            // ── Per-Month Transaction Pages ───────────────────
            for month in report.months {
                newPage()

                // Month header
                drawRect(CGRect(x: 0, y: 0, width: pageWidth, height: 50),
                         color: primaryColor.withAlphaComponent(0.85), cornerRadius: 0)
                _ = drawText(month.monthLabel,
                             at: CGPoint(x: margin, y: 14),
                             font: heading1Font, color: .white)

                let summLine = "Income: \(prefs.format(month.totalIncome))   Expense: \(prefs.format(month.totalExpense))   Net: \(prefs.format(month.netBalance))"
                _ = drawText(summLine, at: CGPoint(x: margin, y: 32),
                             font: captionFont,
                             color: UIColor.white.withAlphaComponent(0.85))
                y = 66

                // Transaction table header
                drawRect(CGRect(x: margin, y: y, width: contentW, height: 18),
                         color: UIColor.systemGray5)
                let txCols: [(String, CGFloat)] = [
                    ("Date", 0.16), ("Category", 0.22),
                    ("Note", 0.36), ("Type", 0.12), ("Amount", 0.14)
                ]
                xOff = margin + 4
                for (label, frac) in txCols {
                    _ = drawText(label, at: CGPoint(x: xOff, y: y + 3),
                                 font: captionFont, color: secondaryColor,
                                 maxWidth: contentW * frac - 4)
                    xOff += contentW * frac
                }
                y += 18

                let dateFmt        = DateFormatter()
                dateFmt.dateFormat = "MM/dd"
                let sorted = month.transactions.sorted {
                    ($0.date ?? Date()) < ($1.date ?? Date())
                }

                for (idx, tx) in sorted.enumerated() {
                    checkPageBreak(needing: 18)
                    if idx % 2 == 0 {
                        drawRect(CGRect(x: margin, y: y, width: contentW, height: 16),
                                 color: UIColor.systemGray6)
                    }
                    let isIncome = tx.type == "income"
                    let amtColor = isIncome ? primaryColor : redColor
                    let txData: [(String, UIColor)] = [
                        (dateFmt.string(from: tx.date ?? Date()), .label),
                        (tx.category ?? "",                        .label),
                        (tx.note     ?? "",                        secondaryColor),
                        (isIncome ? "In" : "Out",                  amtColor),
                        (prefs.format(tx.amount),                  amtColor),
                    ]
                    xOff = margin + 4
                    for ((_, frac), (text, color)) in zip(txCols, txData) {
                        let w = contentW * frac
                        _ = drawText(text, at: CGPoint(x: xOff, y: y + 2),
                                     font: captionFont, color: color, maxWidth: w - 4)
                        xOff += w
                    }
                    y += 16
                }

                // Month subtotals
                y += 8
                drawLine(y: y)
                y += 6
                let subLine = "Month Total — Income: \(prefs.format(month.totalIncome))   Expense: \(prefs.format(month.totalExpense))   Balance: \(prefs.format(month.netBalance))"
                _ = drawText(subLine, at: CGPoint(x: margin, y: y),
                             font: heading2Font,
                             color: month.netBalance >= 0 ? primaryColor : redColor)
            }

            // ── Footer on last page ───────────────────────────
            y += 30
            drawLine(y: y)
            y += 8
            _ = drawText(
                "Generated by DailyFinance  •  \(formatDate(report.generatedAt))  •  \(report.currency)",
                at: CGPoint(x: margin, y: y),
                font: captionFont, color: secondaryColor,
                alignment: .center, maxWidth: contentW
            )
        }
    }

    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
