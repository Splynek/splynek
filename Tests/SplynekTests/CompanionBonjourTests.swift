import Foundation
import SplynekCompanionCore

/// S4 iOS Companion (2026-05-07): tests for `SplynekTXTRecord`, the
/// pure decoder that maps a Bonjour TXT-record dict to the iOS-side
/// `Discovered` model.  Pure-Swift; doesn't touch `Network.framework`.
enum CompanionBonjourTests {

    static func run() {
        TestHarness.suite("SplynekTXTRecord — required keys") {

            TestHarness.test("Missing uuid → nil") {
                let txt: [String: String] = ["name": "Mac", "ver": "0.19"]
                try expect(SplynekTXTRecord.decode(txt, serviceName: "Splynek-abc") == nil)
            }

            TestHarness.test("Minimal valid record decodes") {
                let txt: [String: String] = ["uuid": "abc"]
                let got = SplynekTXTRecord.decode(txt, serviceName: "Splynek-abc")
                try expect(got?.uuid == "abc")
                try expect(got?.swarmCapable == false)
                try expect(got?.version == "?")
            }
        }

        TestHarness.suite("SplynekTXTRecord — optional fields") {

            TestHarness.test("Display name falls back to service name when 'name' absent") {
                let txt: [String: String] = ["uuid": "u1"]
                let got = SplynekTXTRecord.decode(txt, serviceName: "Splynek-abcd1234")
                try expect(got?.displayName == "Splynek-abcd1234")
            }

            TestHarness.test("Display name uses 'name' when present") {
                let txt: [String: String] = ["uuid": "u1", "name": "Paulo's MacBook"]
                let got = SplynekTXTRecord.decode(txt, serviceName: "Splynek-abc")
                try expect(got?.displayName == "Paulo's MacBook")
            }

            TestHarness.test("swarm=1 sets swarmCapable") {
                let txt: [String: String] = ["uuid": "u1", "swarm": "1"]
                let got = SplynekTXTRecord.decode(txt, serviceName: "_")
                try expect(got?.swarmCapable == true)
            }

            TestHarness.test("swarm=0 leaves swarmCapable false") {
                let txt: [String: String] = ["uuid": "u1", "swarm": "0"]
                let got = SplynekTXTRecord.decode(txt, serviceName: "_")
                try expect(got?.swarmCapable == false)
            }

            TestHarness.test("Version surfaces from 'ver'") {
                let txt: [String: String] = ["uuid": "u1", "ver": "0.19"]
                let got = SplynekTXTRecord.decode(txt, serviceName: "_")
                try expect(got?.version == "0.19")
            }
        }
    }
}
