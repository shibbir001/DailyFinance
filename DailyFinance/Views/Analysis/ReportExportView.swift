//
//  ReportExportView.swift
//  DailyFinance
//
//  Created by Shibbir on 21/3/26.
//


// Views/Analysis/ReportExportView.swift
import SwiftUI

struct ReportExportView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var theme:       ThemeManager

    // MARK: - State
    @State private var selectedMonths: Int     = 1
    @State private var isGenerating:   Bool    = false
    @State private var showShareSheet: Bool    = false
    @State private var shareItems:     [Any]   = []
    @State private var exportFormat:   ExportFormat = .pdf
    @State private var report:         FullReport?  = nil
    @State private var errorMessage:   String  = ""
    @State private var showError:      Bool    = false

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        case both = "Both"

        var icon: String {
            switch self {
            case .pdf:  return "doc.richtext.fill"
            case .csv:  return "tablecells.fill"
            case .both: return "doc.on.doc.fill"
            }
        }
    }

    let monthOptions = [1, 2, 3, 6, 12]

    var monthLabel: String {
        selectedMonths == 1 ? "1 Month" : "\(selectedMonths) Months"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Preview card
                    previewCard

                    // Month range selector
                    monthRangeSelector

                    // Format selector
                    formatSelector

                    // What's included
                    includedSection

                    // Export button
                    exportButton

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .alert("Export Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Preview Card
    var previewCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 44))
                .foregroundColor(.white)

            Text("Balance Sheet Report")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(previewDateRange)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            if let report = report {
                Divider().background(.white.opacity(0.3))
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("Income")
                            .font(.caption2).foregroundColor(.white.opacity(0.7))
                        Text(preferences.format(report.grandIncome))
                            .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    }.frame(maxWidth: .infinity)

                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 30)

                    VStack(spacing: 2) {
                        Text("Expense")
                            .font(.caption2).foregroundColor(.white.opacity(0.7))
                        Text(preferences.format(report.grandExpense))
                            .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    }.frame(maxWidth: .infinity)

                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 30)

                    VStack(spacing: 2) {
                        Text("Balance")
                            .font(.caption2).foregroundColor(.white.opacity(0.7))
                        Text(preferences.format(report.grandBalance))
                            .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    }.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [theme.accent, theme.accent.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: theme.accent.opacity(0.3), radius: 12)
        .onAppear { buildPreview() }
        .onChange(of: selectedMonths) { _ in buildPreview() }
    }

    // MARK: - Month Range Selector
    var monthRangeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Period")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 10) {
                ForEach(monthOptions, id: \.self) { months in
                    Button {
                        withAnimation(.spring()) {
                            selectedMonths = months
                        }
                    } label: {
                        Text(months == 1 ? "1M" : "\(months)M")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedMonths == months
                                ? theme.accent
                                : Color(.systemBackground)
                            )
                            .foregroundColor(
                                selectedMonths == months ? .white : .primary
                            )
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.05), radius: 4)
                    }
                }
            }

            Text(previewDateRange)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Format Selector
    var formatSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button {
                        withAnimation(.spring()) {
                            exportFormat = format
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: format.icon)
                                .font(.title2)
                            Text(format.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            exportFormat == format
                            ? theme.accent.opacity(0.15)
                            : Color(.systemBackground)
                        )
                        .foregroundColor(
                            exportFormat == format ? theme.accent : .primary
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    exportFormat == format
                                    ? theme.accent : Color.secondary.opacity(0.2),
                                    lineWidth: 1.5
                                )
                        )
                    }
                }
            }

            // Format description
            Group {
                switch exportFormat {
                case .pdf:
                    Text("📄 Formatted balance sheet with charts — great for printing or sharing")
                case .csv:
                    Text("📊 Spreadsheet-compatible — open in Excel, Google Sheets, or Numbers")
                case .both:
                    Text("📦 Exports both PDF and CSV — share or save as needed")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Included Section
    var includedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report Includes")
                .font(.headline)
                .fontWeight(.bold)

            let items = [
                ("chart.bar.fill",      "Monthly income & expense summary",  theme.accent),
                ("list.bullet.rectangle","All transactions with details",     theme.accent),
                ("chart.pie.fill",       "Spending by category breakdown",    theme.accent),
                ("percent",              "Savings rate & net balance",        theme.accent),
            ]

            ForEach(items, id: \.0) { icon, label, color in
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .frame(width: 20)
                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Export Button
    var exportButton: some View {
        Button {
            generateAndExport()
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Generating…")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export \(exportFormat.rawValue)")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.accent)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: theme.accent.opacity(0.3), radius: 8)
        }
        .disabled(isGenerating)
    }

    // MARK: - Actions
    func buildPreview() {
        Task.detached(priority: .userInitiated) {
            let r = ReportGenerator.shared.buildReport(monthCount: selectedMonths)
            await MainActor.run { self.report = r }
        }
    }

    func generateAndExport() {
        guard !isGenerating else { return }
        isGenerating = true

        Task.detached(priority: .userInitiated) {
            let r     = ReportGenerator.shared.buildReport(monthCount: selectedMonths)
            var items: [Any] = []

            let dateTag: String = {
                let f        = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: Date())
            }()

            do {
                switch await self.exportFormat {
                case .pdf, .both:
                    let pdfData = ReportGenerator.shared.generatePDF(report: r)
                    let url     = FileManager.default.temporaryDirectory
                        .appendingPathComponent("DailyFinance_Report_\(dateTag).pdf")
                    try pdfData.write(to: url)
                    items.append(url)
                    if case .pdf = await self.exportFormat { break }
                    fallthrough

                case .csv:
                    let csv    = ReportGenerator.shared.generateCSV(report: r)
                    let url    = FileManager.default.temporaryDirectory
                        .appendingPathComponent("DailyFinance_Report_\(dateTag).csv")
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    items.append(url)
                }

                await MainActor.run {
                    self.shareItems  = items
                    self.isGenerating = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage  = error.localizedDescription
                    self.isGenerating  = false
                    self.showError     = true
                }
            }
        }
    }

    // MARK: - Helpers
    var previewDateRange: String {
        let calendar = Calendar.current
        let now      = Date()
        let fmt      = DateFormatter()
        fmt.dateFormat = "MMM yyyy"

        guard let start = calendar.date(
            byAdding: .month, value: -(selectedMonths - 1), to: now
        ) else { return "" }

        if selectedMonths == 1 {
            return fmt.string(from: now)
        }
        return "\(fmt.string(from: start)) – \(fmt.string(from: now))"
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems:        items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}