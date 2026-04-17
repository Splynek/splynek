# Show HN draft

**Title candidates — pick one:**

1. `Show HN: Splynek – a macOS download manager that uses every network interface at once`
2. `Show HN: Splynek – pure-Swift multi-interface download manager (Wi-Fi + Ethernet + tether in parallel)`
3. `Show HN: Splynek – download files over Wi-Fi AND your iPhone tether simultaneously`

Recommended: **#1**. Direct, specific, names the thing.

**Post at:** Tuesday or Wednesday, 14:00–16:00 UTC (9–11 AM ET).
That window consistently dominates Show HN visibility.

---

## Body

> Splynek is a native macOS download manager that pins every outbound
> socket to a specific NIC via IP_BOUND_IF, so it can pull the same
> file over Wi-Fi, Ethernet, and your iPhone tether *in parallel* and
> reassemble a verified file. On a flaky hotel Wi-Fi + 5G-tether
> combo I consistently see 2–3× single-path.
>
> What's in the box:
>
> - Multi-interface HTTP aggregation with keep-alive per lane
> - BitTorrent v1 + v2 + hybrid (BEP 3/6/9/10/11/52), DHT, PEX
> - LAN fleet: other Splyneks on Bonjour advertise themselves, so
>   the same file on your colleague's Mac arrives over gigabit
>   instead of the internet
> - Mobile web dashboard paired by QR code — submit URLs from your
>   iPhone's Safari share sheet
> - Local-AI URL resolution via Ollama — "the latest Ubuntu 24.04
>   desktop ISO" → direct URL, offline
> - Per-chunk SHA-256 Merkle integrity verification
> - Documented REST API + CLI + Raycast + Alfred + Chrome
>   extension + Shortcuts — every surface hits the same ingress
>   contract
>
> ~11 k lines of Swift, no third-party dependencies, Xcode-optional
> (builds via plain `swift build`). MIT. Ad-hoc signed — first launch
> needs a right-click → Open. Notarisation is on the roadmap.
>
> Demo: [splynek.app](https://splynek.app) · Source: [github.com/splynek/splynek](https://github.com/splynek/splynek)
>
> Happy to answer questions about the architecture, trade-offs (no,
> I didn't implement uTP; yes, fleet peers over public internet is
> explicitly declined for legal reasons), or what's next.

---

## Comment-seeding — prep answers in advance

HN will ask these. Have responses ready in a text file so you can
paste fast when the post is fresh:

### "Why not just use aria2?"

> aria2 doesn't bind per-interface (it'll use whatever the OS routes
> through), doesn't have a native Mac UI, doesn't do a LAN content
> cache, doesn't integrate with Shortcuts / Raycast / Alfred, and
> doesn't have any AI story. Splynek is the Mac-native
> multi-interface download manager aria2 doesn't try to be.

### "Is this like Free Download Manager / JDownloader / Motrix?"

> All three are cross-platform and don't do interface binding. FDM
> and JDownloader have a heavy Java/Electron feel; Motrix wraps
> aria2. Splynek is ~11 k lines of pure native Swift, SPM only,
> Apple-native widgets, Bonjour, Network.framework. Different thing.

### "Does it really go 2–3× faster?"

> Only if your two links are both bottlenecks AND roughly comparable
> in latency. Hotel Wi-Fi (slow, unstable) + 5G tether is the canonical
> case. On residential gigabit with nothing else, Splynek isn't faster
> than single-path — it's just as fast. The Benchmark tab inside the
> app generates a shareable PNG with your own numbers.

### "How does the LAN cache handle [hostile peer / wrong content]?"

> Every byte Splynek accepts from a fleet peer is verified against
> a SHA-256 (if the user supplied one) or a per-chunk Merkle
> manifest if a .splynek-manifest sibling exists. Mismatch = treat
> as a failed chunk, requeue, try a different mirror. A hostile
> LAN peer produces retries, not corrupted output.

### "Why not a public P2P cache?"

> Legal and operational risk I'm not willing to take on solo — see
> the MONETIZATION.md in the repo and the SECURITY.md threat model.
> I'd need to staff DMCA + NCMEC responses, run bootstrap nodes,
> accept the defendant-name exposure. Private LAN only, by design.

### "Is this just for macOS?"

> Yes. AppKit + SwiftUI + Network.framework are the load-bearing
> APIs. Linux/Windows port is not planned.

### "What about Safari / Mac App Store?"

> Both need a real Apple Developer account (€99/year). I haven't
> pulled that trigger yet — see the roadmap. Chrome extension ships
> today via load-unpacked; Safari integration uses bookmarklets.

### "Why was this not on GitHub until today?"

> It was local-only development until the stack felt coherent
> enough to maintain. v0.31 is the first public cut.

---

## After the post

- Watch the comments window for 2 hours minimum; answer everything,
  even hostile comments, politely and with specifics.
- Don't upvote your own post.
- Don't ask friends to upvote — HN's flame detector will catch it
  and flag the post.
- Cross-post to `r/macapps` + `r/selfhosted` 3–4 hours after the HN
  thread hits, linking back to HN for comments.
- Email MacStories / ATP / 9to5Mac / The Eclectic Light Company
  after first HN signal; the Mac-focused press reads HN.

## Fallback if HN is quiet

- Tuesday post at 14:00 UTC quiet? Re-submit a different angle the
  following Tuesday. Second submission with a different title is
  standard HN practice.
- Product Hunt launch: Thursday/Friday that same week. PH has its
  own audience; HN-on-Tuesday + PH-on-Thursday is the canonical
  solo-developer rollout.
