import SwiftUI

struct MainWatchView: View {
    @EnvironmentObject private var handler: WatchConnectivityHandler
    @Binding var openRecordingOnLaunch: Bool
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Record button
                Button {
                    showRecording = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                        Text("Opnemen")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if !handler.isPhoneReachable {
                    Label("iPhone niet bereikbaar", systemImage: "iphone.slash")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
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
