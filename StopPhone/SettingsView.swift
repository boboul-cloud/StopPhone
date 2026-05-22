import FamilyControls
import SwiftUI

/// Lets the user pick which apps and categories to block when driving.
/// Uses Apple's native FamilyActivityPicker (requires FamilyControls auth).
struct SettingsView: View {

    @EnvironmentObject private var blockingManager: BlockingManager
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Label(String(localized: "settings.choose.apps"),
                                  systemImage: "apps.iphone")
                            Spacer()
                            Text(selectionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .disabled(!blockingManager.isAuthorized)
                } header: {
                    Text(String(localized: "settings.section.blocking"))
                } footer: {
                    Text(String(localized: "settings.section.footer"))
                }

                Section {
                    Button(role: .destructive) {
                        blockingManager.activitySelection = FamilyActivitySelection()
                    } label: {
                        Label(String(localized: "settings.reset"),
                              systemImage: "arrow.counterclockwise")
                    }
                    .disabled(blockingManager.activitySelection.categoryTokens.isEmpty
                              && blockingManager.activitySelection.applicationTokens.isEmpty)
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: $blockingManager.activitySelection
            )
        }
    }

    private var selectionSummary: String {
        let cats = blockingManager.activitySelection.categoryTokens.count
        let apps = blockingManager.activitySelection.applicationTokens.count
        if cats == 0 && apps == 0 {
            return String(localized: "settings.default")
        }
        var parts: [String] = []
        if cats > 0 { parts.append("\(cats) catégorie\(cats > 1 ? "s" : "")") }
        if apps > 0 { parts.append("\(apps) app\(apps > 1 ? "s" : "")") }
        return parts.joined(separator: ", ")
    }
}
