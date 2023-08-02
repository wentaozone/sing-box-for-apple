import ApplicationLibrary
import Libbox
import Library
import SwiftUI

struct MainView: View {
    @Environment(\.scenePhase) var scenePhase

    @State private var selection = NavigationPage.dashboard
    @State private var extensionProfile: ExtensionProfile?
    @State private var profileLoading = true
    @State private var logClient: LogClient!
    @State private var importRemoteProfile: LibboxImportRemoteProfile?

    var body: some View {
        viewBuilder {
            if profileLoading {
                ProgressView().onAppear {
                    Task.detached {
                        logClient = LogClient(SharedPreferences.maxLogLines)
                        await loadProfile()
                    }
                }
            } else {
                TabView(selection: $selection) {
                    ForEach(NavigationPage.allCases, id: \.self) { page in
                        NavigationStackCompat {
                            page.contentView
                                .navigationTitle(page.title)
                                .focusSection()
                        }
                        .tag(page)
                        .tabItem { page.label }
                    }
                }
            }
        }
        .onChangeCompat(of: scenePhase) { newValue in
            if newValue == .active {
                Task.detached {
                    await loadProfile()
                }
            }
        }
        .environment(\.selection, $selection)
        .environment(\.extensionProfile, $extensionProfile)
        .environment(\.logClient, $logClient)
        .environment(\.importRemoteProfile, $importRemoteProfile)
        .onOpenURL(perform: openURL)
    }

    private func openURL(url: URL) {
        if url.host == "import-remote-profile" {
            var error: NSError?
            importRemoteProfile = LibboxParseRemoteProfileImportLink(url.absoluteString, &error)
            if error != nil {
                return
            }
            if selection != .profiles {
                selection = .profiles
            }
        }
    }

    private func loadProfile() async {
        defer {
            profileLoading = false
        }
        if ApplicationLibrary.inPreview {
            return
        }
        if let newProfile = try? await ExtensionProfile.load() {
            if extensionProfile == nil || extensionProfile?.status == .invalid {
                newProfile.register()
                extensionProfile = newProfile
            }
        } else {
            extensionProfile = nil
        }
    }

    private func connectLog() {
        guard let profile = extensionProfile else {
            return
        }
        guard let logClient else {
            return
        }
        if profile.status.isConnected, !logClient.isConnected {
            logClient.reconnect()
        }
    }
}
