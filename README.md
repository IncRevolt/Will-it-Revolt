# Will It Revolt?

A tiny, read-only checker that tells you whether a Windows PC is a good
candidate for the **RR Turbo** Classic Hardware Recovery Kit from
[Renewable Revolt](https://renewablerevolt.org) — a veteran-owned 501(c)(3)
nonprofit that rescues older computers from the landfill.

It looks at your machine's specs and gives you a plain-English verdict. It
**reads only** — it changes nothing, installs nothing, needs no administrator
rights, and sends nothing anywhere. Everything runs and stays on your PC.

---

## How to run it

1. Download **`Will-It-Revolt.zip`** from the
   [latest release](../../releases/latest).
2. Right-click the zip → **Extract All** (don't run it from inside the zip).
3. Double-click **`Will-It-Revolt.bat`**.
4. Read the result, then close the window.

That's it. No setup, no account, no admin prompt.

### "Windows protected your PC" (SmartScreen)

Because this is a small script from an independent nonprofit, Windows may show
a blue **SmartScreen** box the first time. That's normal for any new tool that
isn't code-signed. Click **More info → Run anyway**. You can read exactly what
the script does in `Will-It-Revolt.ps1` before you run it — it's plain text.

---

## What the result means

The checker reads your CPU, memory, storage, firmware, and the Windows 11
"walls" (TPM, Secure Boot, the SSE4.2 CPU floor), then gives one of three
verdicts:

| Verdict | Meaning |
|---|---|
| 🟢 **Revolts well** | 8 GB+ RAM and clears the floor — clean, fast Windows 11 with room to multitask. |
| 🟡 **Revolts — entry tier** | Meets the 4 GB floor — runs great for one task at a time (web, email, documents, a chatbot). Tight if you stack many apps or tabs. |
| 🔴 **Won't Revolt** | Below the floor, or has a wall it can't pass. The checker tells you exactly what it's short on. |

It also reports the **on-device AI tier** your hardware can support (RR AI is a
free download that sizes itself to your machine).

### Turn-key activation read

If your PC has a Windows license built into its firmware, the checker tells you
whether RR Turbo will **activate on its own**:

- **YES** — Windows Home is in your firmware; RR Turbo activates automatically, no key needed.
- **PRO** — Windows Pro is in your firmware; you'll use your own Pro key.
- **MAYBE** — no firmware license found; Windows may ask for a key.

---

## What it checks (and what it never does)

**Reads:** processor (cores/threads/speed), installed RAM, system-drive size
and free space, 64-bit status, GPU/VRAM, TPM version, Secure Boot and UEFI
state, the SSE4.2 CPU floor, and any Windows license embedded in firmware.

**Never does:** no writes, no installs, no registry changes, no admin rights,
no network calls, no telemetry, no data leaves your computer. You can confirm
all of this by reading `Will-It-Revolt.ps1` — it's short and commented.

---

## Files in this repo

- `Will-It-Revolt.bat` — the double-click launcher.
- `Will-It-Revolt.ps1` — the checker itself (plain-text PowerShell).
- `Will-It-Revolt.zip` — both files together, attached to each release.

## Verify your download (optional)

`Will-It-Revolt.zip`

```
SHA-256: d89fc9d5fe1fba4884bf336230f83c5a303ff39e135cb567927977b630a10923
```

On Windows, check it with:

```powershell
Get-FileHash .\Will-It-Revolt.zip -Algorithm SHA256
```

The hash it prints should match the line above.

---

## About

RR Turbo turns a "too old for Windows 11" machine into a clean, fast, modern PC
— keeping usable hardware out of the waste stream. Learn more at
**[renewablerevolt.org](https://renewablerevolt.org)**.

## License

Released under the [Apache License 2.0](LICENSE) — © 2026 Renewable Revolt, Inc.

Free to use, read, modify, and share. The license includes a patent grant and
preserves attribution via the [NOTICE](NOTICE) file. Note Section 6: it does
**not** grant any right to the "Renewable Revolt" or "RR Turbo" names — those
remain our trademarks.
