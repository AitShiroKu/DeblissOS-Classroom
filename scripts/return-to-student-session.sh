#!/usr/bin/env bash
set -Eeuo pipefail

# Resume the existing student graphical session without starting another login.
student_user=${DEBLISSOS_STUDENT_USER:-student}
seat_name=${DEBLISSOS_SEAT:-seat0}
dry_run=false
if [[ ${1:-} == --dry-run ]]; then
  dry_run=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--dry-run]" >&2
  exit 2
fi

if [[ $dry_run == false && $(id -u) -ne 0 ]]; then
  echo 'Administrator authentication is required.' >&2
  exit 1
fi

preferred=()
fallback=()
while read -r session_id _; do
  [[ $session_id =~ ^[0-9]+$ ]] || continue
  properties=$(loginctl show-session "$session_id" -p Name -p Seat -p Class -p Type -p Service --no-pager 2>/dev/null) || continue
  [[ $properties == *"Name=$student_user"* ]] || continue
  [[ $properties == *"Seat=$seat_name"* ]] || continue
  [[ $properties == *'Class=user'* ]] || continue
  [[ $properties == *'Type=x11'* ]] || continue
  fallback+=("$session_id")
  if [[ $properties == *'Service=sddm-autologin'* ]]; then
    preferred+=("$session_id")
  fi
done < <(loginctl list-sessions --no-legend --no-pager)

if (( ${#preferred[@]} == 1 )); then
  target=${preferred[0]}
elif (( ${#preferred[@]} == 0 && ${#fallback[@]} == 1 )); then
  target=${fallback[0]}
else
  echo "Cannot choose a unique existing $student_user session on $seat_name (autologin: ${#preferred[@]}, graphical: ${#fallback[@]})." >&2
  exit 1
fi

vt=$(loginctl show-session "$target" -p VTNr --value 2>/dev/null)
if [[ ! $vt =~ ^[1-9][0-9]*$ ]]; then
  echo "Student session $target has no valid VT." >&2
  exit 1
fi

echo "Returning to existing $student_user session $target on VT$vt."
if [[ $dry_run == false ]]; then
  loginctl activate "$target"
fi
