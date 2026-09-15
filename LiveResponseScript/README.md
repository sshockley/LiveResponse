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

## Creating app registration

The WindowsDefenderATP resource app ID is always `fc780465-2017-40d4-a0c5-307022471b92` every tenant.  Running these commands needs a privileged role (Privileged Role Administrator or Global Administrator) for the consent step.

### Azure CLI

```bash
MDE_API=fc780465-2017-40d4-a0c5-307022471b92

# Uncomment if running in gov clouds
# az cloud set --name AzureUSGovernment

az login --tenant "$TENANT_ID" --allow-no-subscriptions

# The MDE resource SP must exist before roles can be assigned against it.
# Missing SP is what produces AADSTS650052 later.
az ad sp show --id $MDE_API >/dev/null 2>&1 || az ad sp create --id $MDE_API

APP_ID=$(az ad app create \
  --display-name "MDE Live Response (headless)" \
  --sign-in-audience AzureADMyOrg \
  --query appId -o tsv)

az ad sp create --id "$APP_ID"

for ROLE in Machine.LiveResponse Machine.Read.All Library.Manage; do
  ROLE_ID=$(az ad sp show --id $MDE_API --query "appRoles[?value=='$ROLE'].id | [0]" -o tsv)
  az ad app permission add --id "$APP_ID" --api $MDE_API --api-permissions "$ROLE_ID=Role"
done

az ad app permission admin-consent --id "$APP_ID"

echo "ClientId: $APP_ID"
az ad app permission list-grants --id "$APP_ID" -o table
```

### Microsoft Graph PowerShell

```powershell
Install-Module Microsoft.Graph.Applications -Scope CurrentUser

$mdeApiAppId = 'fc780465-2017-40d4-a0c5-307022471b92'
$roleNames   = 'Machine.LiveResponse','Machine.Read.All','Library.Manage'

Connect-MgGraph -TenantId $tid `
    -Scopes Application.ReadWrite.All,AppRoleAssignment.ReadWrite.All
# add -Environment USGov for GCC High, USGovDoD for DoD

$mdeSp = Get-MgServicePrincipal -Filter "appId eq '$mdeApiAppId'"
if (-not $mdeSp) { $mdeSp = New-MgServicePrincipal -AppId $mdeApiAppId }

$resourceAccess = foreach ($r in $roleNames) {
    @{ Id = ($mdeSp.AppRoles | Where-Object Value -EQ $r).Id; Type = 'Role' }
}

$app = New-MgApplication `
    -DisplayName 'MDE Live Response (headless)' `
    -SignInAudience AzureADMyOrg `
    -RequiredResourceAccess @(@{
        ResourceAppId  = $mdeApiAppId
        ResourceAccess = @($resourceAccess)
    })

$sp = New-MgServicePrincipal -AppId $app.AppId

# Admin consent is one app role assignment per permission
foreach ($ra in $resourceAccess) {
    New-MgServicePrincipalAppRoleAssignment `
        -ServicePrincipalId $sp.Id -PrincipalId $sp.Id `
        -ResourceId $mdeSp.Id -AppRoleId $ra.Id | Out-Null
}

"ClientId: $($app.AppId)"
"ObjectId: $($app.Id)"     # keep this, the certificate step needs it
```

Notes for all methods:

- Remove `Library.Manage` if you are not using the `library` verbs.
- Role assignments can take a minute to show up in tokens. A 403 on the first run that clears by itself is usually propagation.
- `New-MgApplication` publishes no credential. The app cannot authenticate until you attach the certificate below.

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

Clouds: `-Cloud Commercial|UsGovGcc|UsGovGccHigh|UsGovDoD`. Override the host with `-ApiBaseUri https://eu.api.security.microsoft.com` for lower latency. Verify gov hostnames against current docs as they can change.

Other parameters: `-MachineId`, `-DownloadPath`, `-LogPath`, `-PollIntervalSeconds`, `-ActionTimeoutMinutes`, `-Comment`, `-CommandWrapperScript`.

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

Note: Using `-keypbe`/`-certpbe` keeps the bundle readable by modern .NET. If loading fails on older runtimes, re-export with `-legacy`.

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

## Attaching the certificate

Only the public cert gets uploaded to Entra. The `.pfx` and `.key` stay on your machine.  Treat these like passwords.

### Entra Portal

App registration > Certificates & secrets > Certificates > Upload certificate, then select
`lr-app.cer`.

### Azure CLI

```bash
# --append is load bearing. Without it, every existing credential on the app is removed.
az ad app credential reset --id "$APP_ID" --cert @lr-app.cer --append

az ad app credential list --id "$APP_ID" --cert -o table
```

The CLI wants a PEM or base64 `.cer`. `Export-Certificate -Type CERT` on Windows writes DER,
which it will reject, so convert first:

```powershell
[Convert]::ToBase64String($cert.RawData) | Set-Content .\lr-app-b64.cer -Encoding ascii
```

### Microsoft Graph PowerShell

`-KeyCredentials` replaces the whole collection, so read the existing entries and pass them back alongside the new one. Loading through `X509Certificate2` makes this format-agnostic, since
`RawData` is DER whether the file on disk was PEM or DER.

```powershell
$appObjectId = '<ObjectId from the app registration step>'

$pub = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    (Resolve-Path ./lr-app.cer).Path)

$new = @{
    Type        = 'AsymmetricX509Cert'
    Usage       = 'Verify'
    Key         = $pub.RawData
    DisplayName = 'CN=mde-live-response'
}

$existing = (Get-MgApplication -ApplicationId $appObjectId).KeyCredentials
Update-MgApplication -ApplicationId $appObjectId -KeyCredentials @($existing + $new)

(Get-MgApplication -ApplicationId $appObjectId).KeyCredentials |
    Select-Object DisplayName, StartDateTime, EndDateTime, @{n='Thumbprint';e={
        [BitConverter]::ToString($_.CustomKeyIdentifier).Replace('-','') }}
```

### Then

```powershell
$pfxPwd = Read-Host 'PFX password' -AsSecureString
./Invoke-MdeLiveResponse.ps1 -TenantId $tid -ClientId $cid `
    -CertificatePath ./lr-app.pfx -CertificatePassword $pfxPwd -DeviceName ws-eng-042
```

Notes:

- Change the script to store the `.pfx` in SecretManagement or a KMS.
- Rotate before expiry: generate a new pair, attach the new `.cer`, cut over, then delete the old credential in Entra. Two certs can be registered at once, so there is no outage window.
- The app's `Machine.LiveResponse` grant is tenant-wide. Treat this credential as equivalent to SYSTEM on every onboarded device in scope.

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
