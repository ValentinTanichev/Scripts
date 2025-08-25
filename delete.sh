#!/usr/bin/env zsh
set -o errexit -o pipefail

# Archiving settings for SINGLE files (not links)
ARCHIVE_DIR="${HOME}/.local/share/delete-archive"
mkdir -p -- "$ARCHIVE_DIR"

usage() {
    echo "Usage: $0 <path_to_file_or_link> [...]" >&2
    exit 1
}

(( $# >= 1 )) || usage

archive_and_delete() {
    local path="$1"
    local base ts out
    base="$(basename -- "$path")"
    ts="$(date +'%Y%m%d-%H%M%S')"
    out="${ARCHIVE_DIR}/${base}.${ts}.tar.gz"
    tar -czf "$out" -C "$(dirname -- "$path")" -- "$base"
    rm -f -- "$path"
    echo "The file is archived in: $out"
    echo "Original file deleted: $path"
}

for item in "$@"; do
    if [[ ! -e "$item" && ! -L "$item" ]]; then
        echo "Not found: $item" >&2
        continue
    fi

    #Symbolic link
    if [[ -L "$item" ]]; then
        target="$(readlink -- "$item" || true)"
        rm -f -- "$item"
        echo "Only symlink removed: $item"
        [[ -n "$target" ]] && echo "The link pointed to: $target"
        continue
    fi

    #Hard link to a regular file
    if [[ -f "$item" ]]; then
        # Get the number of links and inodes via GNU stat
        nlink="$(stat -c '%h' -- "$item")"
        inode="$(stat -c '%i' -- "$item")"
        dev_mountpoint="$(df -P -- "$item" | awk 'NR==2{print $6}')"

        if [[ "$nlink" -gt 1 ]]; then
            echo "File found with multiple hard links (nlink=$nlink), inode=$inode"
            echo "Searching for all paths on the same partition (${dev_mountpoint})..."
            # -samefile ensures that both device and inode match; -xdev will not go beyond the FS
            mapfile -t links < <(find "$dev_mountpoint" -xdev -samefile "$item" 2>/dev/null || true)

            rm -f -- "$item"
            echo "ONLY selected hardlink removed: $item"
            echo "List of hard links:"
            for l in "${links[@]}"; do
                echo "$l"
            done
            continue
        fi
    fi

    #Regular file or object
    if [[ -f "$item" ]]; then
        archive_and_delete "$item"
    else
        rm -rf -- "$item"
        echo "Deleted: $item"
    fi
done
