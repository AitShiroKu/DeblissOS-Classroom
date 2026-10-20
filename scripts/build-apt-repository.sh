#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# -lt 4 ]]; then
  echo "Usage: $0 OUTPUT_DIR testing|stable SIGNING_FINGERPRINT PACKAGE.deb [...]" >&2
  exit 2
fi
output_dir=$1
suite=$2
fingerprint=$3
shift 3
[[ $suite == testing || $suite == stable ]] || { echo "Invalid suite" >&2; exit 2; }
[[ $fingerprint =~ ^[A-Fa-f0-9]{40}$ || $fingerprint =~ ^[A-Fa-f0-9]{64}$ ]] || { echo "Use a full signing fingerprint" >&2; exit 2; }
for tool in apt-ftparchive dpkg-deb gpg gzip sha256sum; do command -v "$tool" >/dev/null; done
# Always build a fresh tree. Existing repositories must be preserved by the publisher.
[[ ! -e $output_dir ]] || { echo "Output already exists; choose a new directory" >&2; exit 1; }
for package in "$@"; do
  [[ $(dpkg-deb -f "$package" Architecture) == all ]] || { echo "Only Architecture: all supported" >&2; exit 1; }
done
mkdir -p -- "$output_dir/pool/main" "$output_dir/dists/$suite/main/binary-amd64" "$output_dir/dists/$suite/main/binary-arm64"
output_dir=$(cd -- "$output_dir" && pwd)
for package in "$@"; do
  name=$(dpkg-deb -f "$package" Package)
  version=$(dpkg-deb -f "$package" Version)
  [[ $name =~ ^[a-z0-9][a-z0-9+.-]+$ && $version =~ ^[A-Za-z0-9.+:~_-]+$ ]] || exit 2
  destination="$output_dir/pool/main/${name}_${version}_all.deb"
  [[ ! -e $destination ]] || { echo "Duplicate package version" >&2; exit 1; }
  cp -- "$package" "$destination"
done
cd -- "$output_dir"
for arch in amd64 arm64; do
  apt-ftparchive packages pool > "dists/$suite/main/binary-$arch/Packages"
  gzip -n -9 -c "dists/$suite/main/binary-$arch/Packages" > "dists/$suite/main/binary-$arch/Packages.gz"
done
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=DeblissOS \
  -o APT::FTPArchive::Release::Label=DeblissOS \
  -o "APT::FTPArchive::Release::Suite=$suite" \
  -o "APT::FTPArchive::Release::Codename=$suite" \
  -o "APT::FTPArchive::Release::Architectures=amd64 arm64" \
  -o APT::FTPArchive::Release::Components=main \
  -o APT::FTPArchive::Release::Description="DeblissOS classroom tools" \
  release "dists/$suite" > "dists/$suite/Release"
gpg --batch --yes --local-user "$fingerprint" --digest-algo SHA256 --clearsign --output "dists/$suite/InRelease" "dists/$suite/Release"
gpg --batch --yes --local-user "$fingerprint" --digest-algo SHA256 --armor --detach-sign --output "dists/$suite/Release.gpg" "dists/$suite/Release"
gpg --batch --export-options export-minimal --export "$fingerprint" > deblissos-archive-keyring.gpg
sha256sum pool/main/*.deb > SHA256SUMS
echo "Built signed $suite repository in $output_dir"
