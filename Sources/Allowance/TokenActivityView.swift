import SwiftUI

// Resolve the property wrapper explicitly rather than the newer SDK's State macro.
private typealias TokenHoverState = State<Date?>

/// Only service-provided totals are shown. Missing dates remain unavailable, not zero.
struct TokenActivityView: View {
    @ObservedObject var model: Model
    var onHeightChange: ((CGFloat) -> Void)? = nil
    var horizontalInset: CGFloat = 0
    @AppStorage("showTokenActivity") private var expanded = false
    @TokenHoverState private var hoveredDay = nil
    @FocusState private var focusedDay: Date?
    private let tint = Color(red: 0.30, green: 0.88, blue: 0.73)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = model.tokenActivity?.weekOrderedDays(now: context.date) ?? []
            let todayDate = TokenActivity.displayCalendar().startOfDay(for: context.date)
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    expanded.toggle()
                    hoveredDay = nil
                    focusedDay = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                        Text("Token activity").fontWeight(.medium)
                        Spacer()
                        if let today = days.first(where: { $0.date == todayDate })?.tokens {
                            Text("\(TokenActivity.compact(today)) today").foregroundStyle(.secondary)
                        }
                    }.font(.system(size: 12)).contentShape(Rectangle()).padding(.vertical, 5)
                }.buttonStyle(.plain)
                    .accessibilityLabel("Token activity")
                    .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                if expanded {
                    if model.tokensError {
                        Text(model.tokenActivity == nil ? "Token activity unavailable" : "Showing last known activity")
                            .font(.system(size: 10)).foregroundStyle(.orange)
                    }
                    if model.tokenActivity?.dailyUsageBuckets != nil, !days.allSatisfy({ $0.tokens == nil }) {
                        let maximum = max(1, days.compactMap(\.tokens).max() ?? 1)
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(days) { day in
                                let today = day.date == todayDate
                                let inspecting = day.id == (hoveredDay ?? focusedDay)
                                VStack(spacing: 7) {
                                    ZStack(alignment: .bottom) {
                                        if let tokens = day.tokens {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(today ? tint : (inspecting ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.4)))
                                                .frame(width: 18, height: tokens == 0 ? 1 : max(2, 56 * CGFloat(Double(tokens) / Double(maximum))))
                                        } else {
                                            Text("—").font(.system(size: 10)).foregroundStyle(.secondary)
                                        }
                                    }.frame(height: 56, alignment: .bottom)
                                    Text(weekday(day.date)).font(.system(size: 10, weight: today ? .semibold : .regular))
                                        .foregroundStyle(today ? tint : (inspecting ? Color.primary : Color.secondary))
                                }.frame(maxWidth: .infinity).padding(.top, 10).contentShape(Rectangle())
                                    .focusable()
                                    .focused($focusedDay, equals: day.id)
                                    .onHover { inside in
                                        if inside { hoveredDay = day.id }
                                        else if hoveredDay == day.id { hoveredDay = nil }
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(today ? "Today" : dayLabel(day.date))
                                    .accessibilityValue(day.tokens.map { $0.formatted() + " tokens" } ?? "No total reported")
                            }
                        }
                        let inspected = days.first { $0.id == (hoveredDay ?? focusedDay) }
                        Text(inspected.map(detail) ?? "")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .frame(height: 12, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if model.tokensLoading && model.tokenActivity == nil {
                        Text("Reading token activity…").font(.system(size: 11)).foregroundStyle(.secondary)
                    } else if !model.tokensError {
                        Text("No daily history reported").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: focusedDay) { _ in hoveredDay = nil }
        .onDisappear {
            hoveredDay = nil
            focusedDay = nil
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, horizontalInset > 0 ? 8 : 0)
        .background {
            GeometryReader { proxy in
                Color.clear.onAppear { onHeightChange?(proxy.size.height) }
                    .onChange(of: proxy.size.height) { onHeightChange?($0) }
            }
        }
    }
    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
    private func detail(_ day: TokenActivity.Day) -> String {
        return "\(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(day.tokens.map { $0.formatted() + " tokens" } ?? "No total reported")"
    }
}
