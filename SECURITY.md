# Security Policy

## Supported versions

Only the latest release on https://github.com/spreadpaper/SpreadPaper/releases receives security fixes. If you are on an older version, update first and check whether the problem is still there.

## Reporting a vulnerability

Use GitHub's private reporting: https://github.com/spreadpaper/SpreadPaper/security/advisories/new. Do not open a public issue.

Include steps to reproduce, the SpreadPaper version, your macOS version, and what an attacker could do with it.

This is a solo project, so timelines are best effort. I aim to acknowledge reports within 7 days and to ship a fix, or explain why not, within 30 days. If you have not heard back after 14 days, leave a comment on the advisory. Confirmed reports are credited in the release notes unless you prefer not to be named.

## Scope

In scope: the SpreadPaper app, the release workflow, and the website source in this repository. Out of scope: GitHub itself, third-party services, and hosting infrastructure not controlled by this project.

The app is sandboxed and runs no background process. Its only network traffic is the update check against api.github.com and raw.githubusercontent.com, once at launch and when you click Check for Updates in Settings. Examples of what counts: crafted image or preset files that crash or hijack the app, sandbox escapes, and unsafe handling of the update response.

## Ground rules

Do not test against other people's machines or accounts, and do not go further than needed to demonstrate the problem. Good-faith research under these rules will not lead to legal action from me.
