#!/bin/bash

WORKDIR="$(pwd)"
TMP="$WORKDIR/tmp"
TARGETDIR="$HOME"
SUFFIX="patch"

# TODO: Like gnu stow, add support for different workspaces. i.e. all commands should take
# an additional positional parameters that creates that subdir for everything. Then patches
# to similar things can be applied together, like edit Hyprdots, apply Hyprdots, etc. Or
# something like edit Asus, apply Asus if you have machine specific configuration

subcmd__apply() {
  find "$WORKDIR" -type f -name "*.$SUFFIX" | while read -r file; do
    relfile="${file#"$WORKDIR/"}"
    relfile="${relfile%".$SUFFIX"}"

    if patch --dry-run -R -s -f "$TARGETDIR/$relfile" "$file" >&/dev/null; then
      continue
    fi

    echo "Applying patch: $relfile"
    patch -s "$TARGETDIR/$relfile" "$file"
  done
}

subcmd__reset() {
  find "$TMP" -type f | while read -r file; do
    relfile="${file#"$TMP/"}"

    if diff -q "$TMP/$relfile" "$TARGETDIR/$relfile" >/dev/null; then
      continue
    fi

    echo "Reverting changes to $relfile..."
    mv "$TMP/$relfile" "$TARGETDIR/$relfile"
  done
}

subcmd__edit() {
  while [[ $# -gt 0 ]]; do
    relpath="${1#$TARGETDIR/}"

    find "$TARGETDIR/$relpath" -type f | while read -r file; do
      relfile="${file#"$TARGETDIR/"}"
      tmpfile="$TMP/$relfile"

      if [ -f "$tmpfile" ]; then
        continue
      fi

      echo "Saving: $relfile"
      mkdir -p "$TMP/$(dirname $relfile)"
      cp "$file" "$tmpfile"

      patchfile="$WORKDIR/$relfile.$SUFFIX"
      if [ -f "$patchfile" ]; then
        patch -R -s "$tmpfile" "$patchfile"
      fi
    done

    shift
  done
}

subcmd__finish() {
  find "$TMP" -type f | while read -r file; do
    relfile="${file#"$TMP/"}"
    filediff="$(diff "$TMP/$relfile" "$TARGETDIR/$relfile")"

    if [ -z "$filediff" ]; then
      continue
    fi

    echo "Creating patch: $relfile"

    mkdir -p "$WORKDIR/$(dirname $relfile)"
    echo "$filediff" >"$WORKDIR/$relfile.$SUFFIX"
  done

  rm -rf "$TMP"
}

print_help() {
  cat <<EOF
dotpatcher - create and manage patches to dotfiles

Usage: dotpatcher.sh [SUBCOMMAND] [OPTION]...

Subcommands:
  apply           Applies stored patches to files
  edit [path]...  Edit files in path(s)
  reset           Discard current edits
  finish          Save current edits as patches

Flags:
  -t, --targetdir DIR   Directory to apply patches (default: $HOME)
  -w, --workdir DIR     Directory to store patches (default: $(pwd))
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
    print_help
    exit 1
    ;;
  --t | --targetdir)
    TARGETDIR="$2"
    shift
    shift
    ;;
  -w | --workdir)
    WORKDIR="$2"
    shift
    shift
    ;;
  -* | --*)
    echo "Unknown subcommand $1"
    exit 1
    ;;
  *)
    subcmd=$1
    shift

    if type "subcmd__$subcmd" >/dev/null 2>&1; then
      "subcmd__$subcmd" "$@"
    else
      echo "Unknown command: $subcmd"
      exit 1
    fi

    break
    ;;
  esac
done
