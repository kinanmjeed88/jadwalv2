# Windows packaging

The Windows workflow produces three distributable outputs from the Flutter Release bundle:

- A raw Release bundle for troubleshooting.
- `Jadwal-V2-Windows-7-<version>.zip` for portable distribution.
- `Jadwal-V2-Windows-7-<version>-Setup.exe` built with Inno Setup.

The installer is intentionally unsigned when no signing credentials are configured. For production releases, add the following GitHub Actions secrets at the repository or environment level:

- `WINDOWS_CERTIFICATE_BASE64`: Base64-encoded PFX/PKCS#12 code-signing certificate.
- `WINDOWS_CERTIFICATE_PASSWORD`: Password protecting the PFX certificate.

When both secrets are present, CI creates a temporary JSON signing configuration under the runner's temporary directory and exposes only its path and an enabled flag to later steps. The signing script reads that file, writes the PFX certificate to a separate temporary path only while invoking `signtool.exe`, and removes the PFX in a `finally` block. A final `always()` cleanup step removes the JSON configuration after packaging, including when an earlier step fails. No certificate, password, private key, or generated signing configuration belongs in the repository or uploaded artifacts.

The workflow also performs a basic Windows smoke test by launching the Release executable for a short period and failing if the process exits immediately. This verifies startup and packaging integrity; it is not a replacement for manual acceptance testing on a clean Windows machine.
