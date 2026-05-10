import Foundation
@testable import SplynekCore

/// Tests for persistent API tokens — Sprint 4 PRO-PLUS-IPHONE
/// (2026-05-10).  Pure-logic + disk-store invariants exercised
/// here; the FleetCoordinator integration is tested separately.
enum APITokenTests {

    static func run() {
        TestHarness.suite("API tokens — model + validator") {

            TestHarness.test("Generated secret is 64 hex chars") {
                let s = APIToken.generateSecret()
                try expect(s.count == 64,
                           "expected 64 chars, got \(s.count)")
                let hex = Set("0123456789abcdef")
                try expect(s.allSatisfy { hex.contains($0) },
                           "non-hex char in secret: \(s)")
            }

            TestHarness.test("Two generated secrets differ") {
                let a = APIToken.generateSecret()
                let b = APIToken.generateSecret()
                try expect(a != b,
                           "secret generator collision on first try")
            }

            TestHarness.test("Token defaults to read+write scope") {
                let t = APIToken(label: "Raycast")
                try expect(t.scope == .readWrite,
                           "expected default readWrite, got \(t.scope)")
            }

            TestHarness.test("Add + look up + revoke") {
                var store = APITokenStore.empty
                let t = APIToken(label: "test")
                store.add(t)
                try expect(store.tokens.count == 1, "add failed")
                try expect(store.token(matching: t.secret)?.id == t.id,
                           "lookup by secret failed")
                store.revoke(id: t.id)
                try expect(store.tokens.isEmpty, "revoke failed")
                try expect(store.token(matching: t.secret) == nil,
                           "lookup after revoke should fail")
            }

            TestHarness.test("recordUse stamps lastUsedAt") {
                var store = APITokenStore.empty
                let t = APIToken(label: "test")
                store.add(t)
                try expect(store.tokens[0].lastUsedAt == nil,
                           "fresh token should have no lastUsedAt")
                let now = Date()
                store.recordUse(secret: t.secret, at: now)
                try expect(store.tokens[0].lastUsedAt != nil,
                           "recordUse should stamp lastUsedAt")
            }

            TestHarness.test("recordUse on unknown secret is no-op") {
                var store = APITokenStore.empty
                store.add(APIToken(label: "real"))
                let preCount = store.tokens.count
                store.recordUse(secret: "ghost-secret", at: Date())
                try expect(store.tokens.count == preCount,
                           "store should not grow on unknown-secret use")
            }
        }

        TestHarness.suite("API tokens — validator") {

            TestHarness.test("Empty presented token is rejected") {
                let d = APITokenValidator.decide(
                    presented: "",
                    webToken: "abc",
                    store: .empty,
                    kind: .read
                )
                try expect(d == .rejected,
                           "empty presented should reject; got \(d)")
            }

            TestHarness.test("Session webToken match accepts both kinds") {
                let dRead = APITokenValidator.decide(
                    presented: "abc", webToken: "abc",
                    store: .empty, kind: .read
                )
                let dWrite = APITokenValidator.decide(
                    presented: "abc", webToken: "abc",
                    store: .empty, kind: .write
                )
                try expect(dRead == .acceptedSessionToken,
                           "session read rejected: \(dRead)")
                try expect(dWrite == .acceptedSessionToken,
                           "session write rejected: \(dWrite)")
            }

            TestHarness.test("readWrite API token accepts both kinds") {
                let t = APIToken(label: "rw")
                let store = APITokenStore(tokens: [t])
                let dr = APITokenValidator.decide(
                    presented: t.secret, webToken: "different",
                    store: store, kind: .read
                )
                let dw = APITokenValidator.decide(
                    presented: t.secret, webToken: "different",
                    store: store, kind: .write
                )
                try expect(dr == .acceptedAPIToken(id: t.id),
                           "rw token read rejected: \(dr)")
                try expect(dw == .acceptedAPIToken(id: t.id),
                           "rw token write rejected: \(dw)")
            }

            TestHarness.test("readOnly API token accepts read, rejects write") {
                let t = APIToken(label: "ro", scope: .readOnly)
                let store = APITokenStore(tokens: [t])
                let dr = APITokenValidator.decide(
                    presented: t.secret, webToken: "different",
                    store: store, kind: .read
                )
                let dw = APITokenValidator.decide(
                    presented: t.secret, webToken: "different",
                    store: store, kind: .write
                )
                try expect(dr == .acceptedAPIToken(id: t.id),
                           "ro token read rejected: \(dr)")
                try expect(dw == .rejected,
                           "ro token write should reject: \(dw)")
            }

            TestHarness.test("Unknown secret rejects regardless of kind") {
                let store = APITokenStore(tokens: [APIToken(label: "real")])
                let dr = APITokenValidator.decide(
                    presented: "ghost", webToken: "session",
                    store: store, kind: .read
                )
                try expect(dr == .rejected, "ghost secret should reject")
            }
        }

        TestHarness.suite("API tokens — disk store") {

            TestHarness.test("Round-trip preserves tokens") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("api-tokens-test-\(UUID()).json")
                APITokenStoreFile._testOverrideURL = tmp
                defer {
                    try? FileManager.default.removeItem(at: tmp)
                    APITokenStoreFile._testOverrideURL = nil
                }
                let file = APITokenStoreFile()
                let t = APIToken(label: "raycast", scope: .readOnly)
                file.mutate { $0.add(t) }
                let read = file.read()
                try expect(read.tokens.count == 1, "round-trip lost token")
                try expect(read.tokens[0].label == "raycast",
                           "round-trip lost label")
                try expect(read.tokens[0].scope == .readOnly,
                           "round-trip lost scope")
                try expect(read.tokens[0].secret == t.secret,
                           "round-trip lost secret")
            }
        }
    }
}
