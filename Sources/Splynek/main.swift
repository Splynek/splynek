// Splynek's executable target is a three-line shim. All of the code
// lives in the SplynekCore library target so the XCTest target can
// @testable import it; this file exists only because SPM needs a
// reachable `main` to produce a `.app`-shaped binary.
import SplynekCore

SplynekBootstrap.run()
