import SwiftUI

/// Modal that asks for the parental PIN before performing a destructive action
/// (disabling protection, dismissing the driving overlay, etc.).
struct PINPromptView: View {

    let onSuccess: () -> Void
    let onCancel: () -> Void

    @AppStorage(UDKey.parentPIN) private var savedPIN: String = ""
    @State private var entered: String = ""
    @State private var shake: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Text("🔒").font(.system(size: 56))
            Text(String(localized: "pin.prompt.title"))
                .font(.title3.weight(.semibold))
            Text(String(localized: "pin.prompt.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < entered.count ? Color.primary : Color.secondary.opacity(0.25))
                        .frame(width: 18, height: 18)
                }
            }
            .offset(x: shake ? -8 : 0)
            .animation(.default.repeatCount(3, autoreverses: true).speed(6), value: shake)

            PINKeypad { digit in
                guard entered.count < 4 else { return }
                entered.append(String(digit))
                if entered.count == 4 { validate() }
            } onDelete: {
                if !entered.isEmpty { entered.removeLast() }
            }

            Button(String(localized: "overlay.disable.confirm.no"), role: .cancel) {
                onCancel()
            }
            .padding(.top, 4)
        }
        .padding(24)
    }

    private func validate() {
        if entered == savedPIN {
            onSuccess()
        } else {
            shake.toggle()
            entered = ""
        }
    }
}

private struct PINKeypad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(1..<4, id: \.self) { col in
                        let digit = row * 3 + col
                        button(label: "\(digit)") { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: 14) {
                Color.clear.frame(width: 72, height: 72)
                button(label: "0") { onDigit(0) }
                Button(action: onDelete) {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .frame(width: 72, height: 72)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func button(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title.weight(.medium))
                .frame(width: 72, height: 72)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Circle())
        }
        .foregroundStyle(.primary)
    }
}

/// Set / change the PIN.
struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UDKey.parentPIN) private var savedPIN: String = ""

    @State private var step: Step = .enter
    @State private var first: String = ""
    @State private var second: String = ""
    @State private var error: String?

    enum Step { case enter, confirm }

    var body: some View {
        VStack(spacing: 24) {
            Text("🔐").font(.system(size: 56))
            Text(step == .enter
                 ? String(localized: "pin.setup.enter")
                 : String(localized: "pin.setup.confirm"))
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                let count = step == .enter ? first.count : second.count
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < count ? Color.primary : Color.secondary.opacity(0.25))
                        .frame(width: 18, height: 18)
                }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            PINKeypad { digit in
                if step == .enter {
                    guard first.count < 4 else { return }
                    first.append(String(digit))
                    if first.count == 4 {
                        step = .confirm
                        error = nil
                    }
                } else {
                    guard second.count < 4 else { return }
                    second.append(String(digit))
                    if second.count == 4 { commit() }
                }
            } onDelete: {
                if step == .enter, !first.isEmpty { first.removeLast() }
                else if !second.isEmpty { second.removeLast() }
            }

            Button(String(localized: "overlay.disable.confirm.no"), role: .cancel) {
                dismiss()
            }
            .padding(.top, 4)
        }
        .padding(24)
    }

    private func commit() {
        if first == second {
            savedPIN = first
            dismiss()
        } else {
            error = String(localized: "pin.setup.mismatch")
            first = ""
            second = ""
            step = .enter
        }
    }
}
