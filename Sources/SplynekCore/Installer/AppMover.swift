import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// AppMover copies a .app bundle into a destination directory using
// FileManager.copyItem.  No code execution, no shell-out, no
// installer scripts.  Splynek does NOT auto-launch the moved .app —
// that's a deliberate choice for 2.5.2 separation: "we install" must
// not blur into "we run."  The post-install card surfaces the
// installed location; the user double-clicks to launch.
// =====================================================================

/// v1.8: the simplest installer in the pipeline — for spec kinds
/// `.appBundle` (a bare .app the user dropped in) and the inner
/// payload of `.dmg` / `.appArchive` after the disk image / zip
/// has been mounted / extracted.
///
/// Behaviour:
///   - Resolve destination → typically `/Applications/<name>.app`.
///     If a previous install of the same bundle ID exists, we
///     copy with a suffix (`<name> 2.app`) and let the
///     `InstalledAppRegistry` decide whether to delete the old one.
///   - Copy via `FileManager.copyItem(at:to:)`.  Atomic at the
///     filesystem level (mac uses APFS clone-on-copy when possible).
///   - Read the destination's `Info.plist` to extract the version
///     string for the registry record.
///
/// Sandbox concerns:
///   - Free DMG build of Splynek runs unsandboxed → can write
///     to /Applications directly.
///   - MAS sandboxed build needs the user to pick `/Applications`
///     (or a sub-directory) once via NSOpenPanel and we persist a
///     security-scoped bookmark.  The pipeline routes that through
///     `appScopedDestination` if set, otherwise it falls back to
///     the standard /Applications location.
///
/// Why not /usr/sbin/installer for .app?  Because .app is just a
/// directory — `installer(8)` doesn't deal with .app, only .pkg.
/// FileManager is the canonical and Apple-blessed path.
enum AppMover {

    enum Failure: Error, LocalizedError, Sendable {
        case sourceNotFound
        case destinationUnwriteable(String)
        case copyFailed(String)
        case infoPlistUnreadable

        var errorDescription: String? {
            switch self {
            case .sourceNotFound:                  return "The .app bundle to install isn't where I expected."
            case .destinationUnwriteable(let s):   return "Can't write to the install destination: \(s)"
            case .copyFailed(let s):               return "Copy failed: \(s)"
            case .infoPlistUnreadable:             return "Couldn't read the bundle's Info.plist."
            }
        }
    }

    /// Result of a successful move.
    struct Outcome: Sendable {
        let installedAt: URL
        let bundleID: String?
        let displayVersion: String?
    }

    /// Move a `.app` into its install destination.
    ///
    /// - Parameters:
    ///   - source: the `.app` bundle Splynek just downloaded /
    ///     extracted / unpacked.
    ///   - destinationDirectory: where to place it.  Defaults to
    ///     `/Applications`.  Pass a user-picked URL (with active
    ///     security scope, if MAS-sandboxed) to redirect.
    ///   - replaceExisting: if true, an existing install of the same
    ///     name is moved to the trash before the new one is copied
    ///     in.  Defaults to false (we add a suffix instead) so the
    ///     pipeline can never silently overwrite an unrelated app
    ///     just because the name collides.
    /// - Returns: the final installed URL + parsed bundle metadata.
    static func install(
        source: URL,
        destinationDirectory: URL = URL(fileURLWithPath: "/Applications"),
        replaceExisting: Bool = false
    ) throws -> Outcome {
        let fm = FileManager.default

        guard fm.fileExists(atPath: source.path) else {
            throw Failure.sourceNotFound
        }
        guard fm.isWritableFile(atPath: destinationDirectory.path) else {
            throw Failure.destinationUnwriteable(destinationDirectory.path)
        }

        let appName = source.lastPathComponent
        var destination = destinationDirectory.appendingPathComponent(appName)

        if fm.fileExists(atPath: destination.path) {
            if replaceExisting {
                // Move the old version to the trash so the user can recover.
                var resultingItem: NSURL? = nil
                try fm.trashItem(at: destination, resultingItemURL: &resultingItem)
            } else {
                // Suffix " 2", " 3", … until we find a free slot.
                let baseName = (appName as NSString).deletingPathExtension
                let ext = (appName as NSString).pathExtension
                var suffix = 2
                while fm.fileExists(atPath: destination.path) {
                    let suffixed = "\(baseName) \(suffix).\(ext)"
                    destination = destinationDirectory.appendingPathComponent(suffixed)
                    suffix += 1
                    if suffix > 100 {
                        throw Failure.copyFailed("Too many existing installations to suffix around.")
                    }
                }
            }
        }

        // The actual copy.  APFS clone-on-copy makes this fast on
        // modern Macs even for multi-GB .app bundles.
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw Failure.copyFailed(error.localizedDescription)
        }

        // Read the freshly-installed bundle's Info.plist to pull the
        // bundle ID + version for the registry record.  Failure here
        // is non-fatal — the install succeeded; we just don't have
        // metadata to track auto-update against.
        let (bundleID, version) = readBundleMetadata(at: destination)

        return Outcome(
            installedAt: destination,
            bundleID: bundleID,
            displayVersion: version
        )
    }

    /// Read `CFBundleIdentifier` and `CFBundleShortVersionString` from
    /// the .app's `Info.plist`.  Returns `(nil, nil)` if anything
    /// can't be read — install is not gated on this.
    static func readBundleMetadata(at appURL: URL) -> (bundleID: String?, version: String?) {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            return (nil, nil)
        }
        let bid = plist["CFBundleIdentifier"] as? String
        let ver = plist["CFBundleShortVersionString"] as? String
        return (bid, ver)
    }
}
