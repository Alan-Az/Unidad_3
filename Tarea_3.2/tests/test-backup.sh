#!/usr/bin/env bash
set -Eeuo pipefail

script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/backup.sh"
root="$(mktemp -d)"
trap 'rm -rf -- "$root"' EXIT
source_dir="$root/source"
destination="$root/backups"
secondary="$root/secondary"
restore_dir="$root/restore"
mkdir -p "$source_dir" "$secondary"
reject_root="$root/rejections"
mkdir -p "$reject_root"
assert_rejected_secondary() {
    local name="$1" reject_source="$2" reject_destination="$3" reject_secondary="$4" destination_preexists="$5"
    local state="$reject_root/$name.state"
    if bash "$script_path" --source "$reject_source" --destination "$reject_destination" --state "$state" --mode full --secondary "$reject_secondary" >/dev/null 2>&1; then
        printf 'FAIL: secondary destination case %s was accepted\n' "$name" >&2
        exit 1
    fi
    [[ ! -e "$state" ]]
    [[ ! -e "$reject_destination/backup.log" ]]
    [[ ! -e "$reject_destination/.backup.lock" ]]
    [[ ! -e "$reject_destination/.backup-state.snar" ]]
    if [[ "$destination_preexists" == 'no' && -e "$reject_destination" ]]; then
        printf 'FAIL: rejected case %s created the primary destination\n' "$name" >&2
        exit 1
    fi
    local output
    for output in "$reject_destination"/unidad3_*; do
        [[ ! -e "$output" ]] || { printf 'FAIL: rejected case %s created a backup\n' "$name" >&2; exit 1; }
    done
    printf 'PASS: secondary destination %s rejected without backup output\n' "$name"
}
reject_source="$reject_root/source"
mkdir -p "$reject_source"
assert_rejected_secondary equal_source "$reject_source" "$reject_root/dest-equal-source" "$reject_source" no
mkdir -p "$reject_source/secondary"
assert_rejected_secondary inside_source "$reject_source" "$reject_root/dest-inside-source" "$reject_source/secondary" no
mkdir -p "$reject_root/dest-equal-primary"
assert_rejected_secondary equal_primary "$reject_source" "$reject_root/dest-equal-primary" "$reject_root/dest-equal-primary" yes
mkdir -p "$reject_root/dest-inside-primary/secondary"
assert_rejected_secondary inside_primary "$reject_source" "$reject_root/dest-inside-primary" "$reject_root/dest-inside-primary/secondary" yes
nested="$source_dir/nested-backups"
if bash "$script_path" --source "$source_dir" --destination "$nested"; then
    printf 'FAIL: nested destination was accepted\n' >&2
    exit 1
fi
[[ ! -e "$nested" ]]
printf 'version one' > "$source_dir/keep.txt"
printf 'must disappear' > "$source_dir/remove.txt"

bash "$script_path" --source "$source_dir" --destination "$destination" --state "$root/state.snar" --mode full --secondary "$secondary"
full_archive=$(compgen -G "$destination/*_full.tar.gz")
[[ -f "$secondary/$(basename -- "$full_archive")" ]]
[[ -f "$secondary/$(basename -- "$full_archive").sha256" ]]
secondary_archive="$secondary/$(basename -- "$full_archive")"
read -r copied_expected _ < "$full_archive.sha256"
read -r copied_actual _ < <(sha256sum -- "$secondary_archive")
read -r copied_sidecar _ < "$secondary_archive.sha256"
[[ "$copied_expected" == "$copied_actual" && "$copied_expected" == "$copied_sidecar" ]]
full=( "$destination"/*_full.tar.gz )
[[ ${#full[@]} -eq 1 ]]
read -r expected _ < "${full[0]}.sha256"
corrupt="$root/corrupt.tar.gz"
cp -- "$full_archive" "$corrupt"
cp -- "$full_archive.sha256" "$corrupt.sha256"
printf x >> "$corrupt"
bad_restore="$root/bad-restore"
if bash "$script_path" --restore "$corrupt" --target "$bad_restore" --force; then
    printf 'FAIL: corrupt archive was accepted\n' >&2
    exit 1
fi
[[ ! -e "$bad_restore" ]]
read -r actual _ < <(sha256sum -- "${full[0]}")
[[ "$expected" == "$actual" ]]

printf 'version two' > "$source_dir/keep.txt"
rm -- "$source_dir/remove.txt"
printf 'new file' > "$source_dir/new.txt"
bash "$script_path" --source "$source_dir" --destination "$destination" --state "$root/state.snar" --mode incremental
incremental=( "$destination"/*_incremental.tar.gz )
[[ ${#incremental[@]} -eq 1 ]]

bash "$script_path" --restore "${full[0]}" --target "$restore_dir" --force
bash "$script_path" --restore "${incremental[0]}" --target "$restore_dir" --force
[[ "$(<"$restore_dir/keep.txt")" == 'version two' ]]
[[ -f "$restore_dir/new.txt" ]]
[[ ! -e "$restore_dir/remove.txt" ]]
printf 'PASS: full, incremental, checksum, and restore assertions\n'
