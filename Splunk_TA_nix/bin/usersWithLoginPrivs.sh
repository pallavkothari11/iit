#!/bin/sh
# SPDX-FileCopyrightText: 2021 Splunk, Inc. <sales@splunk.com>
# SPDX-License-Identifier: Apache-2.0

. `dirname $0`/common.sh

HEADER='USERNAME                      UID                             GID                             HOME_DIR                                                      USER_INFO'
HEADERIZE="BEGIN {print \"$HEADER\"}"

CMD='cat /etc/passwd'
AWK_IFS='-F:'

FILTER='($NF !~ /sh$/) {next}'
PRINTF='{printf "%-30.30s %-30.30s %-30.30s  %-60.60s  %s\n", $1, $3, $4, $6, $5}'

if [ "x$KERNEL" = "xLinux" ] ; then
	FILL_BLANKS='{$5 || $5 = "?"; length($4) || $4 = "?"; length($3) || $3 = "?"}'
elif [ "x$KERNEL" = "xSunOS" ] ; then
	FILL_BLANKS='{$5 || $5 = "?"; length($4) || $4 = "?"; length($3) || $3 = "?"}'
elif [ "x$KERNEL" = "xAIX" ] ; then
	FILL_BLANKS='{$5 || $5 = "?"; length($4) || $4 = "?"; length($3) || $3 = "?"}'
elif [ "x$KERNEL" = "xHP-UX" ] ; then
	FILL_BLANKS='{$5 || $5 = "?"; length($4) || $4 = "?"; length($3) || $3 = "?"}'
elif [ "x$KERNEL" = "xDarwin" ] ; then
	CMD='dscacheutil -q user'
	AWK_IFS=''
	MASSAGE='/^name: / {username = $2} /^uid: / {UID = $2} /^gid: / {GID = $2} /^dir: / {homeDir = $2} /^shell: / {shell = $2} /^gecos: / {userInfo = $2; for (i=3; i<=NF; i++) userInfo = userInfo " " $i} !/^gecos: / {next}'
	FILTER='{if (shell !~ /sh$/) next; if (homeDir ~ /^[0-9]+$/) next}'
	PRINTF='{printf "%-30.30s %-30.30s %-30.30s %-60.60s  %s\n", username, length(UID) ? UID : "?", length(GID)  ? GID : "?", length(homeDir) ? homeDir : "?", userInfo}'
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
	FILL_BLANKS='{$5 || $5 = "?"; length($4) || $4 = "?"; length($3) || $3 = "?"}'
fi

assertHaveCommand $CMD
$CMD | tee $TEE_DEST | $AWK $AWK_IFS "$HEADERIZE $MASSAGE $FILTER $FILL_BLANKS $PRINTF"  header="$HEADER"
echo "Cmd = [$CMD];  | $AWK $AWK_IFS '$HEADERIZE $MASSAGE $FILTER $FILL_BLANKS $PRINTF' header=\"$HEADER\"" >> $TEE_DEST
