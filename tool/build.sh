#!/usr/bin/env bash

# Gets the absolute path of the script (not where it's called from)
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOPDIR=$DIR/..

# Check dependencies
command -v pub >/dev/null 2>&1 || {
	echo "FAIL";
	echo "Please install dart-sdk, add bin to PATH, and restart this script. Aborting."
	exit 1;
}

# Get extra assets
$TOPDIR/tool/build_cmdr_pty.sh

# Build front-end -> build/web
cd $TOPDIR
pub get
pub build

# Build back-end -> build/bin
BUILDBIN=$TOPDIR/build/bin
mkdir -p $BUILDBIN
dart2js --output-type=dart --categories=Server --minify -o $BUILDBIN/main.dart $TOPDIR/bin/main.dart
rm -rf $BUILDBIN/main.dart.deps