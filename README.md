# DeblissOS Classroom

Debian 13 classroom desktop tooling and update delivery prototype.

This initial change packages the tested existing-student-session return helper as `deblissos-tools` and provides build and signed APT publication tooling. It does not include the complete classroom image or Ansible configuration.

See [update delivery](docs/distro-updates.md) for package ownership, Debian build/test commands, signing, pilot enrollment, and release requirements.

GitHub Actions builds package artifacts. A separate manually dispatched Pages workflow verifies a locally signed `apt-public` branch against an independently configured fingerprint before deployment. No production signing key or live APT endpoint is included.
