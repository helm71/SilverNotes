import SwiftUI

struct MainWatchView: View {
    @EnvironmentObject private var handler: WatchConnectivityHandler
    @Binding var openRecordingOnLaunch: Bool
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Record button — zelfde stijl als complicatie-icoon
                Button {
                    showRecording = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                            // Rode opname-stip rechtsonder
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .offset(x: 20, y: 20)
                        }
                        Text("Opnemen")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if !handler.isPhoneReachable {
                    Label("iPhone niet bereikbaar", systemImage: "iphone.slash")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Button {
                    exit(0)
                } label: {
                    Text("Sluiten")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .navigationTitle("SilverNotes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showRecording) {
            VoiceRecordingWatchView()
        }
        .onAppear {
            if openRecordingOnLaunch {
                openRecordingOnLaunch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showRecording = true
                }
            }
        }
    }
}
