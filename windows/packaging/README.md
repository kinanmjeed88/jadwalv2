# Windows packaging

The Windows workflow produces three distributable outputs from the Flutter Release bundle:

- A raw Release bundle for troubleshooting.
- `Jadwal-V2-Windows-<version>.zip` for portable distribution.
- `Jadwal-V2-Windows-<version>-Setup.exe` built with Inno Setup.

The installer is intentionally unsigned when no signing credentials are configured. For production releases, add the following GitHub Actions secrets at the repository or environment level:

- `WINDOWS_CERTIFICATE_BASE64`: Base64-encoded PFX/PKCS#12 code-signing certificate.
- `WINDOWS_CERTIFICATE_PASSWORD`: Password protecting the PFX certificate.

When both secrets are present, CI signs the Release executable before creating the ZIP and installer, then signs the generated installer. The signing certificate is written only to the ephemeral CI runner and is deleted after signing. No certificate, password, or private key belongs in the repository.

The workflow also performs a basic Windows smoke test by launching the Release executable for a short period and failing if the process exits immediately. This verifies startup and packaging integrity; it is not a replacement for manual acceptance testing on a clean Windows machine.
