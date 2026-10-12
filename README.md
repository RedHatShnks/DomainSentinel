<div align="center">

<img width="276" height="276" alt="DomainSentinel" src="https://github.com/user-attachments/assets/402d8fa9-79fb-41c8-a451-004b9a2cc06d" />

**Domain Reconnaissance & OSINT**

![bash](https://img.shields.io/badge/Bash-4.3%2B-4EAA25?logo=gnu-bash&logoColor=white)
![platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-2E3440?logo=linux&logoColor=white)
![version](https://img.shields.io/badge/version-1.3.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![keys](https://img.shields.io/badge/API%20keys-not%20required-brightgreen)

</div>

---

## What DomainSentinel does

DomainSentinel is a domain reconnaissance and intelligence tool designed to collect, analyze, and organize publicly available information about a target domain. It provides subdomain enumeration, live host discovery, subdomain takeover checks, WHOIS lookups, IP geolocation, and JavaScript secret scanning to identify potentially exposed API keys, tokens, and other sensitive information. By consolidating these capabilities into a single workflow, DomainSentinel helps security researchers and system administrators map a domain’s external attack surface, uncover potential security risks, and improve overall security visibility. The tool uses public data sources and does not send exploit traffic or actively probe target services.

**Does:** collect public data, probe HTTP, fingerprint infrastructure

**Doesn't:** exploit, log in, brute-force, submit forms, execute JS, modify

---

## 🛠 Requirements

| | |
|---|---|
| 🖥️ OS | Linux or macOS |
| 🐚 Shell | Bash 4.3+ |
| 🧰 Core tools | `curl` `jq` `dig` `whois` `go` |
| 🤖 Auto-installed | `subfinder` `httpx` `subzy` `waybackurls` `dnsx` |

The tool checks every required binary before the scan starts. Missing system
packages are installed through the detected package manager (`apt`, `dnf`,
`yum`, `pacman`). Missing Go tools are installed into `~/go/bin`. Nothing is
installed if it is already present.

No API keys are required for any stage.

---

## 📦 Install

```bash
git clone https://github.com/RedHatShnks/DomainSentinel.git
cd DomainSentinel
chmod +x DomainSentinel.sh
```

**Verify the file is intact:**

```bash
bash -n DomainSentinel.sh && echo "✅ syntax OK"
```

---

## 🚀 Run

```bash
./DomainSentinel.sh <domain> [output_base]
./DomainSentinel.sh                # interactive mode
```

| Argument | Required | Default |
|:---------|:--------:|:--------|
| 🎯 `<domain>` | ✅ | — |
| 📁 `[output_base]` | ❌ | `./domainsentinel-results` |

The final output path is always `<output_base>/<domain>/`.

### 🎬 Live output

```
   ▸ Stage 1/6  Subdomain enumeration
  [10:00:05] Started Subdomain enumeration
  ✔ subfinder=41  crt.sh=22  unique=52
  [10:00:42] Finished
  state=completed detail=subfinder=41  crt.sh=22  unique=52

   ▸ Stage 2/6  Live host discovery
  [10:00:42] Started Live host discovery
  ✔ live hosts=14
  [10:02:18] Finished
  state=completed detail=live hosts=14

   ▸ Stage 3/6  Subdomain takeover detection
  [10:02:18] Started Subdomain takeover detection
  ✔ candidates=0
  [10:02:35] Finished
  state=no_results detail=candidates=0

   ▸ Stage 4/6  Historical JavaScript scan
  [10:02:35] Started Historical JavaScript scan
  [10:02:38] Historical URLs=251  JS URLs=23
  ✔ js_files=23  scanned=23  findings=2
  [10:03:12] Finished
  state=completed detail=js_files=23  scanned=23  findings=2

   ▸ Stage 5/6  WHOIS & DNS records
  [10:03:12] Started WHOIS & DNS records
  ✔ registrar=Example Registrar, LLC
  [10:03:17] Finished
  state=completed detail=registrar=Example Registrar, LLC

   ▸ Stage 6/6  IP geolocation
  [10:03:17] Started IP geolocation
  ✔ unique public IPs=3
  [10:03:21] Finished
  state=completed detail=unique public IPs=3

```

No completion box at the end. The full result lives in `summary.txt`.

---

## 🔍 The six stages

| # | Icon | Stage | Source | Finds |
|:-:|:----:|:------|:-------|:------|
| 1 | 🌐 | **Subdomains** | subfinder · crt.sh · Certspotter · URLScan · HackerTarget | Every hostname ever certified |
| 2 | 📡 | **Live hosts** | httpx | Status · title · tech · server · IP · CNAME |
| 3 | ⚠️ | **Takeover** | subzy | Dangling third-party CNAMEs with confidence |
| 4 | 🔑 | **JS secrets** | Wayback · CDX | 28 credential patterns across 10 service categories |
| 5 | 📖 | **WHOIS + DNS** | `whois` · `dnsx` · `dig` | Registrar · MX · SPF · DMARC |
| 6 | 🗺️ | **Geolocation** | ip-api.com | City · ISP · ASN · Cloud · Reverse DNS |

**🌐 Stage 1** — every TLS certificate ever issued is in a public ledger. Even
decommissioned subdomains are still listed there. Five sources are queried; a
wildcard DNS check filters false positives before the live-host stage.

**📡 Stage 2** — one HTTP request per subdomain. Captures status, title,
technologies, server header, content length, resolved IP, and CNAME. If httpx
returns nothing, the stage falls back to DNS-only liveness.

**⚠️ Stage 3** — looks for DNS records pointing at services whose resources
are gone. Candidate signal only; manual validation required. Output includes a
confidence column.

**🔑 Stage 4** — Wayback holds "deleted" JavaScript. The scanner checks 28
patterns across cloud providers, payment processors, messaging services, email
and SMS services, package registries, cryptographic material, and database
connection strings.

**📖 Stage 5** — WHOIS registration plus every DNS record type and DMARC.
Uses `dnsx` when available; falls back to `dig`.

**🗺️ Stage 6** — approximate network location per IP. Each entry includes
city, region, country, ISP, ASN, cloud provider classification (AWS, GCP,
Azure, Cloudflare, DigitalOcean, etc.), and reverse DNS. Not a physical
location.

---

## 📂 Output

One directory per scan:

```
DomainSentinel/
└── output_base/
    └── <domain>/
        ├── target_info.txt
        ├── whois.txt
        ├── whois_summary.txt
        ├── dns_records.txt
        ├── subfinder.txt
        ├── crtsh.txt
        ├── subdomains.txt
        ├── live_hosts.txt
        ├── live_hosts.jsonl
        ├── takeover_vuln.txt
        ├── takeover_subzy_raw.log
        ├── js_files.txt
        ├── js_scan_raw.txt
        ├── secrets.txt
        ├── secrets_unique.txt
        ├── ip_geolocation.txt
        ├── ip_geolocation.json
        ├── summary.txt
        └── recon.log
```

<details>
<summary><b>📄 Click to expand file list</b></summary>

| Icon | File | Contents |
|:----:|:-----|:---------|
| ℹ️ | `target_info.txt` | Target and scan metadata |
| 📖 | `whois.txt` | Raw WHOIS |
| 📝 | `whois_summary.txt` | Parsed WHOIS fields |
| 🌐 | `dns_records.txt` | All DNS records |
| 🔍 | `subfinder.txt` | Subdomains from subfinder only |
| 📜 | `crtsh.txt` | Subdomains from CT and fallback sources |
| 📋 | `subdomains.txt` | Merged deduplicated list |
| 📡 | `live_hosts.txt` | Human-readable host report |
| 🧾 | `live_hosts.jsonl` | Structured host data |
| ⚠️ | `takeover_vuln.txt` | Takeover candidates with confidence |
| 🪵 | `takeover_subzy_raw.log` | Raw subzy output |
| 🗂️ | `js_files.txt` | Collected `.js` URLs |
| 🔎 | `js_scan_raw.txt` | Raw secret matches with source URLs |
| 🔒 | `secrets.txt` | Redacted readable findings |
| 🎯 | `secrets_unique.txt` | Deduplicated findings |
| 🗺️ | `ip_geolocation.txt` | Readable geolocation with cloud labels |
| 🌍 | `ip_geolocation.json` | Structured geolocation |
| 📊 | `summary.txt` | Executive summary |
| 📓 | `recon.log` | Full timestamped log |

</details>

Empty stages write a `# no data:` marker — files are never blank.

### 📊 Reading `summary.txt`

```
══════════════════════════════════════════════════════════════════
                  Passive OSINT Recon Summary
══════════════════════════════════════════════════════════════════

Target               : example.com
Output Directory     : ./domainsentinel-results/example.com
Scan Duration        : 02m 44s

Registrar            : Example Registrar, LLC
Registrant Org       : Redacted/Unknown
Registrant Address   : Redacted/Unknown
Registrant Phone     : Redacted/Unknown

Main IP Address      : 93.184.216.34
Geolocation          : Norwell, Massachusetts, United States
ISP / ASN            : Edgecast Inc. (AS15133 Edgecast Inc.)
Unique Live IPs      : 3

Subfinder Results    : 41
crt.sh Results       : 22
Unique Subdomains    : 52
Live Hosts           : 14

Takeover Candidates  : ✓ None
JavaScript Files     : 136
Secrets Found        : ✓ None

Overall Status       : ✅ PASS
══════════════════════════════════════════════════════════════════
```

**`PASS` ≠ secure.** It means the executed checks found nothing to review.
`REVIEW REQUIRED` appears when takeover candidates or secrets exist.

---

## ⚙️ Configuration

Constants at the top of `DomainSentinel.sh`:

| 🔧 Variable | 🎛️ Default |
|:------------|:-----------|
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

| 🚨 Problem | 🛠️ Fix |
|:-----------|:-------|
| `crt.sh HTTP 502` | crt.sh offline. Other CT sources still work. |
| `crt.sh HTTP 000` | Network issue reaching crt.sh. |
| Wrong `httpx` binary | `export PATH="$HOME/go/bin:$PATH" && hash -r` |
| No subdomains | Domain has no certs, or all CT sources down. |
| No live hosts | Target doesn't serve HTTP. Try `curl -I https://example.com`. |
| ip-api rate limit | Wait 60 s. Free tier is 45 req/min. |
| Scan slow | External sources slow. Every call has a hard timeout. |
| `permission denied` | `chmod +x DomainSentinel.sh` |

Failed stages write a `# no data:` marker in their output file explaining the
reason. Full details in `recon.log`.

---

## ⚖️ Legal

**Stages 2 and 3 send HTTP requests to the target.**

✅ You own the domain, **or**
✅ You have written authorization from the owner

Unauthorized use may violate computer-misuse laws. You are responsible for
your use.

---

## 📜 License

**MIT** — see [`LICENSE`](LICENSE).

---

<div align="center">

**Made for researchers who read logs and respect scope.**

`🔎` `🛡️` `📡` `🗺️` `🔑` `⚖️`

</div>
