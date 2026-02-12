import SwiftUI

@main
struct OppoEncoMonitorApp: App {
    @StateObject private var monitor = BatteryMonitor()
    
    var body: some Scene {
        MenuBarExtra {
            VStack {
                Text("Oppo Enco Air 3 Pro")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Divider()
                
                if !monitor.isConnected {
                    Text("Status: Disconnected")
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                    Divider()
                }
                
                if let left = monitor.leftBattery {
                    HStack {
                        Image(systemName: "ear.fill") // Left Earbud Icon
                        Text("Left: \(left)%")
                        if monitor.isLeftCharging {
                            Image(systemName: "bolt.fill").foregroundColor(.yellow)
                        }
                    }
                } else {
                     HStack {
                        Image(systemName: "ear.fill")
                        Text("Left: --")
                    }
                }
                
                if let right = monitor.rightBattery {
                     HStack {
                        Image(systemName: "ear.fill")
                        Text("Right: \(right)%")
                        if monitor.isRightCharging {
                            Image(systemName: "bolt.fill").foregroundColor(.yellow)
                        }
                    }
                } else {
                     HStack {
                        Image(systemName: "ear.fill")
                        Text("Right: --")
                    }
                }
                
                if let caseBat = monitor.caseBattery {
                     HStack {
                        Image(systemName: "case.fill") // Or closest sf symbol
                        Text("Case: \(caseBat)%")
                        if monitor.isCaseCharging {
                            Image(systemName: "bolt.fill").foregroundColor(.yellow)
                        }
                    }
                } else {
                     HStack {
                        Image(systemName: "case.fill")
                        Text("Case: --")
                    }
                }
                
                Divider()
                
                if let lastUpdated = monitor.lastUpdated {
                    Text("Last Updated: \(formattedTime(lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Button(monitor.isLeftRightSwapped ? "Swap L/R (Current: Swapped)" : "Swap L/R (Current: Default)") {
                    monitor.toggleSwap()
                }
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
        } label: {
            HStack(spacing: 4) {
                // Use a safe icon like "headphones" because "earbuds.case" might be invisible
                let iconName = monitor.isConnected ? "earbuds.case.fill" : "headphones"
                Image(systemName: iconName)
                if let caseBat = monitor.caseBattery {
                    Text("\(caseBat)%")
                }
                // Show bolt in menu bar if ANYTHING is charging
                if monitor.isLeftCharging || monitor.isRightCharging || monitor.isCaseCharging {
                    Image(systemName: "bolt.fill").font(.system(size: 8))
                }
            }
        }
    }
    
    func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
