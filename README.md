<div align="center">

```
<img width="576" height="576" alt="9OuQxbM7fNKYv0O0Q06KnrTnCWj_0Q4umHLGu9R08HOkcvUqzeHoFET7FIc49bgKNEcF4nO2hVTr2ghcz_GBP_lO6IxXq0CxLM5bMP5C3PPOR9roejDEpphkwsxXt9gDZJf7b9M49M6Vo0ukWd8SzpYFDg40iGpjqTEDSls_GQGas6QFZC1EzNxOwLl_HN2K" src="https://github.com/user-attachments/assets/402d8fa9-79fb-41c8-a451-004b9a2cc06d" />


```

**Advanced Domain Reconnaissance & OSINT**

![bash](https://img.shields.io/badge/Bash-4.3%2B-4EAA25?logo=gnu-bash&logoColor=white)
![platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-2E3440?logo=linux&logoColor=white)
![version](https://img.shields.io/badge/version-1.2.4-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![keys](https://img.shields.io/badge/API%20keys-not%20required-brightgreen)


</div>

---

## What DomainSentinel does

Point it at a domain. Get back a folder full of everything public.


It takes a domain name and collects public information about it. That is all.

It looks up what subdomains exist by reading public certificate logs. It sends one HTTP request to each subdomain to see if it responds. It checks whether any subdomain points at a third-party service that no longer exists. It downloads archived JavaScript files and scans them for leaked API keys. It queries WHOIS for registration details. It queries DNS for records. It sends the resulting IP addresses to a geolocation API.

It writes everything into a folder. It does not upload anything. It does not modify anything on the target. It does not try to log in anywhere. It does not run exploits. It does not brute-force. It does not submit forms. It does not execute any code it downloads.

The only traffic sent to the target is ordinary HTTP requests during the live-host and takeover stages. Everything else is a query to a public third-party database.


**Does:** collect public data, probe HTTP, fingerprint infrastructure

**Doesn't:** exploit, log in, brute-force, submit forms, execute JS, modify

---

## 🛠 Requirements

| | |
|---|---|
| 🖥️ OS | Linux or macOS |
| 🐚 Shell | Bash 4.3+ |
| 🧰 Core tools | `curl` `jq` `dig` `whois` `go` |
| 🤖 Auto-installed | `subfinder` `httpx` `subzy` `waybackurls` |

> 🔑 **No API keys. Ever.**

---

## 📦 Install

```bash
git clone https://your-host/domainsentinel.git
cd domainsentinel
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
```

| Argument | Required |
|:---------|:--------:|
| 🎯 `<domain>` | ✅ | — |
| 📁 `[output_base]` | ✅ |
**Examples:**

```bash
./DomainSentinel.sh example.com
./DomainSentinel.sh example.com scans
./DomainSentinel.sh example.com /home/kali/recon
./DomainSentinel.sh                # interactive mode
```

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
  ...

   ╭────────────────────────────────────────────╮
   │  ✅ Scan complete  •  2m 44s
   ╰────────────────────────────────────────────╯
```

---

## 🔍 The six stages

| # | Icon | Stage | Source | Finds |
|:-:|:----:|:------|:-------|:------|
| 1 | 🌐 | **Subdomains** | subfinder · crt.sh · Certspotter | Every hostname ever certified |
| 2 | 📡 | **Live hosts** | httpx | Status · title · tech · IP · CNAME |
| 3 | ⚠️ | **Takeover** | subzy | Dangling third-party CNAMEs |
| 4 | 🔑 | **JS secrets** | Wayback · CDX | API keys · tokens · private keys |
| 5 | 📖 | **WHOIS + DNS** | `whois` · `dig` | Registrar · MX · SPF · DMARC |
| 6 | 🗺️ | **Geolocation** | ip-api.com | City · ISP · ASN per IP |

**🌐 Stage 1** — every TLS certificate ever issued is in a public ledger. Even
decommissioned subdomains are still listed there.

**📡 Stage 2** — one HTTP request per subdomain. Tells you what is alive and
what it runs.

**⚠️ Stage 3** — looks for DNS records pointing at services whose resources
are gone. Candidate signal only; manual validation required.

**🔑 Stage 4** — Wayback holds "deleted" JavaScript. API keys from 2019 are
still there.

**📖 Stage 5** — WHOIS registration, plus every DNS record type and DMARC.

**🗺️ Stage 6** — approximate network location per IP. Not a physical location.

---

## 📂 Output

One directory per scan:

```
📁
output_base/
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
| 📜 | `crtsh.txt` | Subdomains from CT sources |
| 📋 | `subdomains.txt` | Merged deduplicated list |
| 📡 | `live_hosts.txt` | Human-readable host report |
| 🧾 | `live_hosts.jsonl` | Structured host data |
| ⚠️ | `takeover_vuln.txt` | Takeover candidates |
| 🪵 | `takeover_subzy_raw.log` | Raw subzy output |
| 🗂️ | `js_files.txt` | Collected `.js` URLs |
| 🔎 | `js_scan_raw.txt` | Raw secret matches with source URLs |
| 🔒 | `secrets.txt` | Redacted readable findings |
| 🎯 | `secrets_unique.txt` | Deduplicated findings |
| 🗺️ | `ip_geolocation.txt` | Readable geolocation |
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

Overall Status       : ✅ PASS
══════════════════════════════════════════════════════════════════
```

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
