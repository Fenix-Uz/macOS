#!/bin/sh

if [ $# -ne 1 ]; then
    echo usage: $0 plist-file
    exit 1
fi

plist="$1"
dir="$(dirname "$plist")"

buildnum=$(/usr/libexec/Plistbuddy -c "Print CFBundleVersion" "$plist")
# Empty or non-numeric CFBundleVersion (fresh state, or a build-setting
# substitution that didn't expand) → seed to 0 so expr can bump it to 1.
case "$buildnum" in
    ''|*[!0-9]*) buildnum=0 ;;
esac

buildnum=$(expr $buildnum + 1)
/usr/libexec/Plistbuddy -c "Set CFBundleVersion $buildnum" "$plist"