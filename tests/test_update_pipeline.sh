#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'gpgconf --kill gpg-agent >/dev/null 2>&1 || true; rm -rf -- "$test_root"' EXIT
export GNUPGHOME="$test_root/gnupg"
mkdir -m700 "$GNUPGHOME"
gpg --batch --passphrase '' --quick-generate-key "DeblissOS disposable test" ed25519 sign 1d
fingerprint=$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')
bash "$repo_root/scripts/build-tools-deb.sh" "$test_root/build1"
bash "$repo_root/scripts/build-tools-deb.sh" "$test_root/build2"
package="$test_root/build1/deblissos-tools_0.1.0_all.deb"
cmp "$package" "$test_root/build2/deblissos-tools_0.1.0_all.deb"
dpkg-deb -x "$package" "$test_root/unpacked"
cmp "$repo_root/scripts/return-to-student-session.sh" "$test_root/unpacked/usr/sbin/deblissos-return-to-student"
test -x "$test_root/unpacked/usr/sbin/deblissos-return-to-student"
! test -e "$test_root/unpacked/usr/local"
dpkg-deb -e "$package" "$test_root/control"
test "$(find "$test_root/control" -type f | wc -l)" -eq 1
bash "$repo_root/scripts/build-apt-repository.sh" "$test_root/repository" testing "$fingerprint" "$package"
gpgv --keyring "$test_root/repository/deblissos-archive-keyring.gpg" "$test_root/repository/dists/testing/InRelease"
gpgv --keyring "$test_root/repository/deblissos-archive-keyring.gpg" "$test_root/repository/dists/testing/Release.gpg" "$test_root/repository/dists/testing/Release"
mkdir -p "$test_root/apt/lists/partial" "$test_root/apt/cache/archives/partial" "$test_root/download"
touch "$test_root/apt/status"
printf 'deb [signed-by=%s] file:%s testing main\n' "$test_root/repository/deblissos-archive-keyring.gpg" "$test_root/repository" > "$test_root/apt/sources.list"
apt_options=(
  -o "Dir::Etc::sourcelist=$test_root/apt/sources.list"
  -o "Dir::Etc::sourceparts=-"
  -o "Dir::Etc::parts=-"
  -o "Dir::Etc::main=-"
  -o "Dir::State=$test_root/apt"
  -o "Dir::State::status=$test_root/apt/status"
  -o "Dir::Cache=$test_root/apt/cache"
  -o "APT::Sandbox::User=$(id -un)"
  -o APT::Get::List-Cleanup=0
)
apt-get "${apt_options[@]}" update
(cd "$test_root/download" && apt-get "${apt_options[@]}" download deblissos-tools=0.1.0)
cmp "$package" "$test_root/download/deblissos-tools_0.1.0_all.deb"
# Modified metadata must fail signature verification and APT update.
printf 'tampered\n' >> "$test_root/repository/dists/testing/Release"
if gpgv --keyring "$test_root/repository/deblissos-archive-keyring.gpg" "$test_root/repository/dists/testing/Release.gpg" "$test_root/repository/dists/testing/Release"; then
  echo "Tampered metadata accepted" >&2
  exit 1
fi
sed -i 's/Origin: DeblissOS/Origin: ModifiedOS/' "$test_root/repository/dists/testing/InRelease"
mkdir -p "$test_root/apt/rejected-lists/partial"
if apt-get "${apt_options[@]}" -o "Dir::State::lists=$test_root/apt/rejected-lists" -o APT::Update::Error-Mode=any update; then
  echo "APT accepted tampered InRelease" >&2
  exit 1
fi
echo "PASS: reproducible package, payload, signed APT index, verified download, and tamper rejection"
