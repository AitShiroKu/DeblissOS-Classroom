#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${1:-"$repo_root/dist"}
command -v dpkg-deb >/dev/null
mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
install -Dm644 "$repo_root/packaging/deblissos-tools/control" "$stage/DEBIAN/control"
install -Dm755 "$repo_root/scripts/return-to-student-session.sh" "$stage/usr/sbin/deblissos-return-to-student"
install -Dm644 "$repo_root/packaging/deblissos-tools/Return-to-Student.desktop" "$stage/usr/share/applications/deblissos-return-to-student.desktop"
install -Dm644 "$repo_root/docs/distro-updates.md" "$stage/usr/share/doc/deblissos-tools/README.md"
version=$(sed -n 's/^Version: //p' "$stage/DEBIAN/control")
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1767225600}
find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
dpkg-deb --root-owner-group --build "$stage" "$output_dir/deblissos-tools_${version}_all.deb"
