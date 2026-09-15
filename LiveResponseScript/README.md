# MDE Live Response: headless client

REPL-style client for Microsoft Defender for Endpoint Live Response

## Files

| File | Purpose |
|---|---|
| `Invoke-MdeLiveResponse.ps1` | The client. Auth, device resolution, command loop, result retrieval. |
| `Invoke-LRCommand.ps1` | Library wrapper that backs the `cmd` verb. Upload to the tenant library once. |

## Requirements

- PowerShell 7.2+
- Live Response enabled
- "Live response unsigned script execution" enabled, unless library scripts are signed
- Target device's RBAC group has a remediation level assigned
- Entra app registration, admin-consented, with application permissions:

  | Permission | Needed for |
  |---|---|
  | `Machine.LiveResponse` | everything |
  | `Machine.Read.All` | resolving device names, `actions` |
  | `Library.Manage` | `library` verbs |

## Authentication

```powershell
# Certificate (preferred, no shared secret at rest)
./Invoke-MdeLiveResponse.ps1 -TenantId $tid -ClientId $cid `
    -CertificatePath ./lr-app.pfx -CertificatePassword $pfxPwd -DeviceName ws-eng-042

# Secret from environment
$env:MDE_CLIENT_SECRET = '...'   # or omit and be prompted
./Invoke-MdeLiveResponse.ps1 -TenantId $tid -ClientId $cid -DeviceName ws-eng-042

# Delegated
./Invoke-MdeLiveResponse.ps1 -TenantId $tid -ClientId $cid -UseDeviceCode -DeviceName ws-eng-042
```

Clouds: `-Cloud Commercial|UsGovGcc|UsGovGccHigh|UsGovDoD`. Override the host with
`-ApiBaseUri https://eu.api.security.microsoft.com` for lower latency. Verify gov hostnames
against current docs. Microsoft has changed them before.

Other parameters: `-MachineId`, `-DownloadPath`, `-LogPath`, `-PollIntervalSeconds`,
`-ActionTimeoutMinutes`, `-Comment`, `-CommandWrapperScript`.

## Certificate setup

Entra pins the public key and does no chain validation so we can use self-signed certificates.

### Linux / macOS (openssl)

```bash
# Generate key and public cert files
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
  -keyout lr-app.key -out lr-app.cer \
  -subj "/CN=mde-live-response"

# Save as PKCS#12 for the script (prompts for a password, set one)
openssl pkcs12 -export -out lr-app.pfx \
  -inkey lr-app.key -in lr-app.cer -name "mde-live-response" \
  -keypbe AES-256-CBC -certpbe AES-256-CBC -macalg sha256

# Key material no longer needed on disk unencrypted
shred -u lr-app.key
chmod 600 lr-app.pfx

# SHA-1 thumbprint, compare to what Entra shows after upload
openssl x509 -in lr-app.cer -noout -fingerprint -sha1
```

Explicit `-keypbe`/`-certpbe` keeps the bundle readable by .NET. If loading fails on an older
runtime, re-export with `-legacy`.

### Windows (PowerShell)

```powershell
# Generate key pair in the user store
$cert = New-SelfSignedCertificate `
    -Subject 'CN=mde-live-response' `
    -CertStoreLocation Cert:\CurrentUser\My `
    -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
    -KeyExportPolicy Exportable -KeySpec Signature `
    -NotAfter (Get-Date).AddYears(1)

# Save public cert for Entra
Export-Certificate -Cert $cert -FilePath .\lr-app.cer -Type CERT

# Save PKCS#12 bundle for the script
$pfxPwd = Read-Host 'PFX password' -AsSecureString
Export-PfxCertificate `
    -Cert $cert `
    -FilePath .\lr-app.pfx `
    -Password $pfxPwd `
    -CryptoAlgorithmOption AES256_SHA256

# Print SHA-1 thumbprint to confirm against Entra
$cert.Thumbprint

# Lock down the bundle
icacls .\lr-app.pfx /inheritance:r /grant:r "$($env:USERNAME):(R)"

# Optional: drop the store copy once the .pfx is backed up
Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)"
```

Keep the last step if you want the file to be the single copy of the credential. Skip it if you would rather load from the store, which takes a small edit to the script's `Certificate` parameter
set since it currently accepts a file path only.

`-CryptoAlgorithmOption AES256_SHA256` avoids the legacy TripleDES default. Remove that parameter if you're running from Windows Server 2012 R2 and earlier.

### Both paths

Upload **only** `lr-app.cer`, under App registration > Certificates & secrets > Certificates >
Upload certificate. The `.pfx` and `.key` stay on your machine.

Then:

```powershell
$pfxPwd = Read-Host 'PFX password' -AsSecureString
./Invoke-MdeLiveResponse.ps1 -TenantId $tid -ClientId $cid `
    -CertificatePath ./lr-app.pfx -CertificatePassword $pfxPwd -DeviceName ws-eng-042
```

Notes:

- Store the `.pfx` in SecretManagement or your KMS rather than next to the script.
- Rotate before expiry: generate a new pair, upload the new `.cer`, cut over, then delete the
  old credential in Entra. Two certs can be registered at once, so there is no outage window.
- The app's `Machine.LiveResponse` grant is tenant-wide. Treat this credential as equivalent to
  SYSTEM on every onboarded device in scope.

## First run

```
library upload ./Invoke-LRCommand.ps1 "Analyst command channel"
```

Read `Invoke-LRCommand.ps1` before uploading. It executes arbitrary strings as SYSTEM on the endpoint. That widens what any holder of `Machine.LiveResponse` can do, compared with a library
of narrow, purpose-built scripts.

## Verbs

```
machine                        target device details
open <name|id>                 retarget
actions [n]                    recent API-initiated actions on this device
cancel <actionId> [comment]    cancel a pending action
comment <text>                 audit comment applied to new actions
last                           reprint last RunScript output
help | exit

library                        list library files
library upload <path> [desc]
library delete <fileName>

run <ScriptName> [args]        RunScript from library
cmd <powershell>               arbitrary PowerShell via the wrapper
get <remote\path>              collect a file
put <libraryFileName>          stage a file in the device working dir
```

### Chaining

Normally each action/command needs its own session.  You can chain them together to avoid the delay of multiple sessions.

```
run Collect-Artifacts.ps1 --get C:\Windows\Temp\out.zip
put winpmem.exe --run Dump-Memory.ps1 -full --get C:\Windows\Temp\mem.raw.gz
```

## Output

- `RunScript` results print to console; raw text cached for `last`
- `GetFile` results ungzip into `./lr-downloads` (`-DownloadPath`)
- Session transcript: `./lr-session-<timestamp>.jsonl` (`-LogPath`). Useful as case evidence,
  since tenant-side you otherwise only have the Action center record

## Limits

| | |
|---|---|
| `runliveresponse` calls | 10/min |
| Concurrent sessions | 25 tenant-wide |
| Per device | one session at a time (`400 ActiveRequestAlreadyExists`) |
| `RunScript` timeout | 10 min, server-side |
| Offline device | action queues up to 3 days |
| Result download link | valid 30 min, regenerable |

429s are retried with `Retry-After`; tokens refresh automatically.

Expect roughly 10 to 40 seconds per command, unlike the sub-second response of the portal console.

## Usage Notes

- Actions started from the portal Device page don't appear in the `machineactions` API, so `actions` shows API-initiated ones only.
- A failed command in a chain aborts everything after it.
- Backslashes in `GetFile` paths are escaped by the script; don't pre-escape them.
- All actions are logged tenant-side and attributed to the app registration, not to you.  Use `comment` to record case context.
