# DeblissOS updates

Status: tested prototype for https://github.com/AitShiroKu/DeblissOS-Classroom. No production signing key or client source has been deployed. Debian security repositories remain independent.

## Package ownership

`deblissos-tools` 0.1.0 installs the session helper in `/usr/sbin` and an application-menu entry in `/usr/share/applications`. It has no maintainer scripts, triggers, services, automatic upgrades, or profile migrations. Installing it does not restart SDDM or terminate sessions. It requires password-protected sudo and does not grant student privileges.

The current Ansible desktop shortcut still calls the helper in `/usr/local/sbin`. These files remain Ansible-owned. For the pilot, test the package menu entry separately; after package acceptance, change the managed admin desktop shortcut to `/usr/sbin/deblissos-return-to-student` and retire the old helper in a controlled migration. Until then, package upgrades affect only the new menu entry. Do not assume the old shortcut receives package fixes.

Keep school-specific firewall sources, Veyon keys, and account enrollment in Ansible. Future config packages need explicit conffile and migration design. Never modify live student Plasma profiles from package install hooks.

## Build and test

On Debian 13 (also used as the target for integration tests):

```sh
bash scripts/build-tools-deb.sh dist
dpkg-deb --info dist/deblissos-tools_0.1.0_all.deb
bash tests/test_update_pipeline.sh
```

Build uses a fixed default `SOURCE_DATE_EPOCH`; release automation may set it to the source commit timestamp. Version lives in `packaging/deblissos-tools/control`. Publish each version only once; bump it for every payload change. The GitHub workflow builds reproducibly and uploads a `.deb` artifact, without signing or publishing.

## Sign a repository

Use a dedicated OpenPGP signing key in an external protected key store. Back it up outside the repository; never commit its private key or passphrase. Use a disposable key for tests. Supply its full fingerprint:

```sh
bash scripts/build-apt-repository.sh apt-repository testing FULL_FINGERPRINT dist/deblissos-tools_0.1.0_all.deb
```

Requires `apt-utils`, `dpkg`, `gnupg`, and `gzip`. The output directory must be new. The builder supports architecture-independent packages, indexed for amd64 and arm64; target runtime acceptance is currently limited to Debian 13 Plasma X11. Keep an archive of older packages and publication trees. When replacing a live repository, retain historical pool files so clients using older indexes can still download them. Deploy the complete tree atomically. This builder creates one suite per output tree; merge suites in staging before publishing a combined site.

GitHub Pages can host the static tree at `https://aitshiroku.github.io/DeblissOS-Classroom/`. This is the intended URL, not yet a working APT endpoint. Source repository: `https://github.com/AitShiroKu/DeblissOS-Classroom`; local remote is `origin`. Keep signed public repository content on a separate `apt-public` branch. For the first pilot, sign locally and publish the resulting public tree; no private signing material needs to go to GitHub.

The manual `Publish signed APT repository` workflow checks out `apt-public`, verifies its metadata against repository variable `APT_SIGNING_FINGERPRINT`, checks package indexes with APT, and deploys through GitHub Pages. Set Pages source to **GitHub Actions** and protect the `github-pages` environment. Create the signing key locally, record its full fingerprint independently, set the variable to that fingerprint, and push only the generated public tree to `apt-public`. Include an empty `.nojekyll` file. The root must contain `dists/testing/InRelease`, `pool/`, and `deblissos-archive-keyring.gpg`; retain older pool files on every publication. Dispatch the workflow only after clone acceptance. A copied public key does not establish trust without matching the independently configured fingerprint.

The workflow publishes only when manually dispatched from the default branch. It has no signing secrets and does not promote packages into stable. Keep production signing credentials out of pull-request jobs.

The repository currently has no metadata expiry policy; signatures verify integrity but cannot prevent replay of an old valid snapshot. Define an appropriate `Valid-Until` interval and scheduled refresh before unattended production distribution.

## Enroll a pilot client

Transfer the public keyring over an already trusted management connection. Verify its full fingerprint independently against the release record; downloading a key and packages from the same unverified location does not establish trust. Install it root-owned, mode 0644, at `/usr/share/keyrings/deblissos-archive-keyring.gpg`. Create `/etc/apt/sources.list.d/deblissos.sources` with real values:

```text
Types: deb
URIs: https://aitshiroku.github.io/DeblissOS-Classroom/
Suites: testing
Components: main
Signed-By: /usr/share/keyrings/deblissos-archive-keyring.gpg
```

Then inspect and install during maintenance:

```sh
sudo apt update
apt-cache policy deblissos-tools
sudo apt install deblissos-tools
sudo /usr/sbin/deblissos-return-to-student --dry-run
```

Test the menu action as admin with a single existing student session. Verify student cannot use sudo. On a disposable clone, upgrade from the previous package and repeat switching without a duplicate student login. This GUI acceptance is required in addition to automated metadata/signature tests.

After testing, publish the same `.deb` bytes in `stable` with newly signed suite metadata. Keep classroom clients on `stable`; do not enable automatic DeblissOS upgrades until maintenance scheduling and recovery are tested. An internal LAN mirror or offline `.deb` delivery can use the same packages. Offline packages must be checked against a trusted signed manifest or verified APT metadata, not an unsigned checksum downloaded alongside them.

For a faulty tools release, publish a new higher version containing the known-good payload. Keep previous signed artifacts and a VM snapshot; config migrations in future packages will need separate recovery procedures. Record source commit, package version, SHA256, signing fingerprint, acceptance results, and release date.
