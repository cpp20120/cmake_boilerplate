# Security Policy

This policy applies to the **cmake_boilerplate** repository, its bootstrap and
packaging scripts, CMake modules, and official source-based vcpkg ports.

## Supported versions

Security fixes are considered for the current default branch and the latest
published release. Older releases are not guaranteed to receive backports.
See [Releases](https://github.com/cpp20120/cmake_boilerplate/releases).

## Reporting a vulnerability

**Do not disclose an unpatched vulnerability in a public issue or discussion.**

Please use [GitHub Security Advisories](https://github.com/cpp20120/cmake_boilerplate/security/advisories)
and select **Report a vulnerability**. The repository must have private
vulnerability reporting enabled for that button to be available.

Include the affected revision/release, operating system, toolchain, steps to
reproduce, potential impact, and any relevant logs. Please redact tokens,
passwords, and other sensitive data.

Particularly relevant issues include unsafe bootstrap downloads or execution,
unexpected privilege escalation, untrusted inputs to build/packaging scripts,
and supply-chain vulnerabilities.

The maintainer aims to acknowledge private reports within 14 days and coordinate
a fix and disclosure where possible. This is a best-effort project maintained
by an individual; no contractual response or remediation SLA is offered.

For non-security bugs, use
[GitHub Issues](https://github.com/cpp20120/cmake_boilerplate/issues).
