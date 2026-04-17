import SwiftUI
import Foundation

/// Entry point that Sources/Splynek/main.swift calls. Kept as a tiny
/// public wrapper so the library doesn't have to expose every type
/// that `SplynekApp` touches as `public` — the executable just needs
/// to know how to start the app.
public enum SplynekBootstrap {
    public static func run() {
        SplynekApp.main()
    }
}
