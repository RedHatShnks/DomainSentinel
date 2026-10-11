<div align="center">

```
    ____                        _       _____            _   _            _
   |  _ \  ___  _ __ ___   __ _(_)_ __ |  ___|__ _ __   | |_(_)_ __   ___| |
   | | | |/ _ \| '_ ` _ \ / _` | | '_ \| |_  / _ \ '_ \  | __| | '_ \ / _ \ |
   | |_| | (_) | | | | | | (_| | | | | |  _| \  __/ | | | | |_| | | | |  __/ |
   |____/ \___/|_| |_| |_|\__,_|_|_| |_|_|    \___|_| |_|  \__|_|_| |_|\___|_|
```

**Advanced Domain Reconnaissance & OSINT**

*Six stages. One domain. Zero API keys.*

</div>

---

## ⚡ What it does

Point it at a domain. Get back a folder full of everything public.

```
    ┌──────────────────────────────────────────────────────┐
    │  1. Subdomains  →  subfinder + crt.sh + Certspotter  │
    │  2. Live hosts  →  httpx (status · title · tech · IP)│
    │  3. Takeover    →  subzy (dangling CNAME detection)  │
    │  4. JS secrets  →  Wayback + CDX + regex + entropy   │
    │  5. WHOIS + DNS →  registrar · SPF · DMARC · MX      │
    │  6. Geolocation →  city · ISP · ASN per public IP    │
    └──────────────────────────────────────────────────────┘
```

**Does:** collect public data, probe HTTP, fingerprint infrastructure
**Does not:** exploit, log in, brute-force, submit forms, execute JS, modify anything

---

## 🛠 Requirements

- Linux or macOS · Bash 4.3+
- `curl` · `jq` · `dig` · `whois` · `go`

Auto-installed on first run if missing:
`subfinder` · `httpx` · `subzy` · `waybackurls`

**No API keys. Ever.**

---

## 📦 Install

```bash
git clone https://your-host/domainsentinel.git
cd domainsentinel
chmod +x DomainSentinel.sh
```

Optional PATH install:

```bash
sudo cp DomainSentinel.sh /usr/local/bin/DomainSentinel
```

Verify:

```bash
bash -n DomainSentinel.sh && echo "syntax OK"
```

---

## 🚀 Run

```bash
./DomainSentinel.sh <domain> [output_base]
```

| Argument | Required | Default |
|----------|----------|---------|
| `<domain>` | ✅ | — |
| `[output_base]` | ❌ | `./domainsentinel-results` |

```bash
./DomainSentinel.sh example.com
./DomainSentinel.sh example.com scans
./DomainSentinel.sh example.com /home/kali/recon
./DomainSentinel.sh                 # interactive mode
```

### Live output

```
   ▸ Stage 1/6  Subdomain enumeration
  [10:00:05] Started Subdomain enumeration
  ✔ subfinder=41  crt.sh=22  unique=52
  [10:00:42] Finished
  state=completed detail=subfinder=41  crt.sh=22  unique=52

   ▸ Stage 2/6  Live host discovery
  [10:00:42] Started Live host discovery
  ✔ live hosts=14
  ...

   ╭────────────────────────────────────────────╮
   │  Scan complete  •  2m 44s
   ╰────────────────────────────────────────────╯
```

---

## 🔍 The six stages

| # | Stage | Source | Finds |
|---|-------|--------|-------|
| 1 | **Subdomains** | subfinder · crt.sh · Certspotter | Every hostname ever certified |
| 2 | **Live hosts** | httpx | Status · title · tech · IP · CNAME |
| 3 | **Takeover** | subzy | Dangling third-party CNAMEs |
| 4 | **JS secrets** | Wayback · CDX | API keys · tokens · private keys |
| 5 | **WHOIS + DNS** | `whois` · `dig` | Registrar · MX · SPF · DMARC |
| 6 | **Geolocation** | ip-api.com | City · ISP · ASN per IP |

**Stage 1** — every TLS certificate ever issued is in a public ledger. Even
decommissioned subdomains are still listed there.

**Stage 2** — one HTTP request per subdomain. Tells you what's alive and what
it runs.

**Stage 3** — looks for DNS records pointing at services whose resources are
gone. Candidate signal only; manual validation required.

**Stage 4** — Wayback holds "deleted" JavaScript. API keys from 2019 are still
there.

**Stage 5** — WHOIS registration, plus every DNS record type and DMARC.

**Stage 6** — approximate network location per IP. Not a physical location.

---

## 📂 Output

One directory per scan:

```
domainsentinel-results/example.com/
```

<details>
<summary><b>Click to expand file list</b></summary>

| File | Contents |
|------|----------|
| `target_info.txt` | Target and scan metadata |
| `whois.txt` | Raw WHOIS |
| `whois_summary.txt` | Parsed WHOIS fields |
| `dns_records.txt` | All DNS records |
| `subfinder.txt` | Subdomains from subfinder only |
| `crtsh.txt` | Subdomains from CT sources |
| `subdomains.txt` | Merged deduplicated list |
| `live_hosts.txt` | Human-readable host report |
| `live_hosts.jsonl` | Structured host data |
| `takeover_vuln.txt` | Takeover candidates |
| `takeover_subzy_raw.log` | Raw subzy output |
| `js_files.txt` | Collected `.js` URLs |
| `js_scan_raw.txt` | Raw secret matches with source URLs |
| `secrets.txt` | Redacted readable findings |
| `secrets_unique.txt` | Deduplicated findings |
| `ip_geolocation.txt` | Readable geolocation |
| `ip_geolocation.json` | Structured geolocation |
| `summary.txt` | Executive summary |
| `recon.log` | Full timestamped log |

</details>

Empty stages write a `# no data:` marker — files are never blank.

### Reading `summary.txt`

```
══════════════════════════════════════════════════════════════════
                  Passive OSINT Recon Summary
══════════════════════════════════════════════════════════════════

Target               : example.com
Output Directory     : ./domainsentinel-results/example.com
Scan Duration        : 02m 44s

Registrar            : Example Registrar, LLC
Registrant Org       : Redacted/Unknown

Main IP Address      : 93.184.216.34
Geolocation          : Norwell, Massachusetts, United States
ISP / ASN            : Edgecast Inc. (AS15133 Edgecast Inc.)

Subfinder Results    : 41
crt.sh Results       : 22
Unique Subdomains    : 52
Live Hosts           : 14

Takeover Candidates  : ✓ None
JavaScript Files     : 136
Secrets Found        : ✓ None

Overall Status       : PASS
══════════════════════════════════════════════════════════════════
```

> **`PASS` ≠ secure.** It means the executed checks found nothing to review.
> `REVIEW REQUIRED` appears when takeover candidates or secrets exist.

---

## ⚙ Configuration

Top of `DomainSentinel.sh`:

| Variable | Default |
|----------|---------|
| `DS_TAGLINE` | `Advanced Domain Reconnaissance & OSINT` |
| `DS_DEFAULT_OUT` | `./domainsentinel-results` |
| `DS_TIMEOUT_NET` | `15` |
| `DS_TIMEOUT_LONG` | `45` |
| `DS_TIMEOUT_SUBFINDER` | `180` |
| `DS_GEO_BATCH_MAX` | `100` |

Override per-run:

```bash
DS_TIMEOUT_LONG=90 ./DomainSentinel.sh example.com
```

---

## 🩺 Troubleshooting

| Problem | Fix |
|---------|-----|
| `crt.sh HTTP 502` | crt.sh offline. Re-run later. Other sources still work. |
| `crt.sh HTTP 000` | Network issue reaching crt.sh. |
| Wrong `httpx` binary | `export PATH="$HOME/go/bin:$PATH" && hash -r` |
| No subdomains | Domain has no certs, or all CT sources down. |
| No live hosts | Target doesn't serve HTTP. Try `curl -I https://example.com`. |
| ip-api rate limit | Wait 60 s. Free tier is 45 req/min. |
| Scan slow | External sources slow. Every call has a hard timeout. |
| `permission denied` | `chmod +x DomainSentinel.sh` |

Failed stages explain themselves in their output file with a `# no data:`
marker. Full details in `recon.log`.

---

## ⚖ Legal

Stages 2 and 3 send HTTP requests to the target.

**Before running:**
- You own the domain, **or**
- You have written authorization from the owner.

Unauthorized use may violate computer-misuse laws. You are responsible for
your use.

---

## 📜 License

MIT — see [`LICENSE`](LICENSE).

---

<div align="center">

*Built for researchers who read logs and respect scope.*

</div>
