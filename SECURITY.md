# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories at https://github.com/excelano/zappel/security/advisories/new. If you would rather not use GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

Only the latest version on the App Store receives fixes. Security fixes ship through `main` and reach the App Store in the next release; there are no maintained release branches.

## Security model

**Zappel has no network surface.** It makes no network request, opens no socket and links no networking or analytics code. It requests no entitlements beyond the defaults, so it cannot reach contacts, location, health data, the microphone or anything else on the watch.

**What it keeps stays on the watch.** The best score, the last wave reached and the sound and haptics settings are kept in the app's own preferences on the watch, and removing the app removes them.
