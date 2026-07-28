import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 설정 › 알림 — a single daily review reminder the learner can turn on and time.
struct NotificationSettingsView: View {
    @Environment(\.colorScheme) private var scheme

    @AppStorage("reviewReminderOn") private var reminderOn = false
    @AppStorage("reviewReminderHour") private var hour = 20
    @AppStorage("reviewReminderMinute") private var minute = 0

    @State private var showingDeniedAlert = false

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()
            Form {
                Section {
                    Toggle("매일 복습 알림", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("시간", selection: timeBinding, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("정한 시간에 복습을 떠올리도록 매일 알려드려요.")
                }
                .listRowBackground(Theme.rowFill)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: reminderOn) { _, isOn in
            if isOn { enable() } else { ReviewReminder.cancel() }
        }
        .onChange(of: hour) { _, _ in reschedule() }
        .onChange(of: minute) { _, _ in reschedule() }
        .alert("알림이 꺼져 있어요", isPresented: $showingDeniedAlert) {
            Button("설정 열기") { openSystemSettings() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("기기 설정에서 Vocabie 알림을 켜야 리마인더를 받을 수 있어요.")
        }
    }

    /// Bridges the stored hour/minute to the DatePicker's Date.
    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date() },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour = c.hour ?? 20
                minute = c.minute ?? 0
            }
        )
    }

    private func enable() {
        Task {
            let granted = await ReviewReminder.requestAuthorization()
            if granted {
                ReviewReminder.schedule(hour: hour, minute: minute)
            } else {
                reminderOn = false
                showingDeniedAlert = true
            }
        }
    }

    private func reschedule() {
        guard reminderOn else { return }
        ReviewReminder.schedule(hour: hour, minute: minute)
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
