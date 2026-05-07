// Copyright © 2026 Splynek. MIT.
//
// CloudKitRelaySubmitter — iOS-side writer for the over-cellular
// relay path.  Used by both the Share Extension and the main app's
// SubmitURLView when LAN submission fails.
//
// The CKContainer identifier is hard-coded here — it's part of the
// app's Info.plist iCloud entitlement, set in App Store Connect,
// and stable for the life of the product.  Both iOS + macOS apps
// must share the same container ID so the iPhone-written records
// land in the same private database the Mac polls.

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

#if canImport(CloudKit)
public actor CloudKitRelaySubmitter {

    /// Container ID matched by both iOS Splynek Companion + macOS
    /// Splynek main app.  iOS app's Info.plist must declare:
    ///
    ///   <key>com.apple.developer.icloud-services</key>
    ///   <array><string>CloudKit</string></array>
    ///   <key>com.apple.developer.icloud-container-identifiers</key>
    ///   <array><string>iCloud.app.splynek.companion</string></array>
    ///
    /// Same goes for the macOS app.  Stable string, never changes.
    public static let containerID = "iCloud.app.splynek.companion"

    private let container: CKContainer
    private let database: CKDatabase

    public init(containerID: String = CloudKitRelaySubmitter.containerID) {
        self.container = CKContainer(identifier: containerID)
        self.database = container.privateCloudDatabase
    }

    public enum SubmitError: Error, Equatable {
        case noICloudAccount
        case quotaExceeded
        case network
        case ckError(code: Int, message: String)
    }

    /// Write a `pending` SplynekRelayJob to the user's private
    /// database.  The Mac picks it up within ~60s on its next
    /// poll.  Returns the saved record's ID so the iOS side can
    /// surface it (e.g. "Submitted — will start when Paulo's
    /// MacBook checks in.").
    public func submit(
        url: URL,
        senderDevice: String,
        targetMacUUID: String
    ) async throws -> String {
        // Confirm the user has an iCloud account first — without
        // it, save() returns a confusing notAuthenticated error.
        // We detect early so the UI surfaces a clear message.
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                throw SubmitError.noICloudAccount
            }
        } catch let err as SubmitError {
            throw err
        } catch {
            throw SubmitError.network
        }

        let relay = CloudKitRelayRecord(
            url: url.absoluteString,
            senderDevice: senderDevice,
            targetMacUUID: targetMacUUID
        )
        let record = relay.toCKRecord()
        do {
            let saved = try await database.save(record)
            return saved.recordID.recordName
        } catch let err as CKError {
            switch err.code {
            case .quotaExceeded:
                throw SubmitError.quotaExceeded
            case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
                throw SubmitError.network
            default:
                throw SubmitError.ckError(code: err.code.rawValue,
                                          message: err.localizedDescription)
            }
        } catch {
            throw SubmitError.network
        }
    }
}
#endif
