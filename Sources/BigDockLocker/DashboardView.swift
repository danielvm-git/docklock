import SwiftUI
import CoreGraphics

struct DashboardView: View {
    @ObservedObject var viewModel: BigDockLockerViewModel

    var body: some View {
        VStack(spacing: 24) {
            header

            if !viewModel.isGranted {
                permissionWarning
            }

            displayList

            footer
        }
        .padding(28)
        .frame(width: 420, height: 480)
        .background(Theme.paper)
        .foregroundColor(Theme.ink)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Big DockLocker")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                let version =
                    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
                Text("v\(version) Signature Edition")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            StatusIndicator(isRunning: viewModel.isRunning)
        }
    }

    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.lock.fill")
                    .foregroundColor(.orange)
                Text("Accessibility Required")
                    .font(.headline)
            }
            Text("Big DockLocker needs permission to prevent the Dock from jumping between displays.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                viewModel.requestPermissions()
            }, label: {
                Text("Grant Access")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(Theme.sodalite)
        }
        .padding(20)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var displayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Map")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.muted)
                .kerning(0.5)
                .textCase(.uppercase)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.displays) { display in
                        DisplayRow(
                            display: display,
                            isLocked: viewModel.lockedDisplayID == display.id,
                            onToggle: { viewModel.toggleLock(for: display.id) }
                        )
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Divider()
                .opacity(0.5)

            HStack {
                Toggle(isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { _ in viewModel.toggleLaunchAtLogin() }
                )) {
                    Text("Launch at Login")
                        .font(.subheadline)
                        .foregroundColor(Theme.muted)
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.lockGreen))

                Spacer()

                Button(action: {
                    if viewModel.isRunning {
                        viewModel.stopEngine()
                    } else {
                        viewModel.startEngine()
                    }
                }, label: {
                    Text(viewModel.isRunning ? "Stop Engine" : "Start Engine")
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                })
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRunning ? Color.red.opacity(0.8) : Theme.sodalite)
            }
        }
    }
}

struct StatusIndicator: View {
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isRunning ? Theme.lockGreen : Color.red.opacity(0.6))
                .frame(width: 8, height: 8)
                .shadow(color: isRunning ? Theme.lockGreen.opacity(0.5) : .clear, radius: 4)

            Text(isRunning ? "LOCKED" : "IDLE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isRunning ? Theme.lockGreen : Theme.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isRunning ? Theme.lockGreen.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(20)
    }
}

struct DisplayRow: View {
    let display: DisplayInfo
    let isLocked: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Monitor Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isLocked ? Theme.sodalite : Color.gray.opacity(0.2))
                    .frame(width: 48, height: 32)

                if display.isMain {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .offset(y: -10)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(display.name)
                    .font(.system(size: 14, weight: .semibold))
                Text("Display \(display.id)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.lockGreen)
            }

            Toggle("", isOn: Binding(get: { isLocked }, set: { _ in onToggle() }))
                .toggleStyle(SwitchToggleStyle(tint: Theme.lockGreen))
                .labelsHidden()
        }
        .padding(14)
        .background(isLocked ? Theme.sodalite.opacity(0.05) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLocked ? Theme.sodalite.opacity(0.2) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
