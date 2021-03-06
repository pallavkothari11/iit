#!/bin/sh
# SPDX-FileCopyrightText: 2021 Splunk, Inc. <sales@splunk.com>
# SPDX-License-Identifier: Apache-2.0

. `dirname $0`/common.sh

CMD='who -H'
HEADER='USERNAME        LINE        HOSTNAME                                  TIME'
HEADERIZE='{NR == 1 && $0 = header}'
FORMAT='{length(hostname) || hostname=$NF; gsub("[)(]", "",hostname); time=$3; for (i=4; i<=lastTimeColumn; i++) time = time " " $i}'
PRINTF='{if (NR == 1) {print $0} else {printf "%-14s  %-10s  %-40.40s  %-s\n", $1,$2,hostname,time}}'

if [ "x$KERNEL" = "xLinux" ] ; then
	FILL_BLANKS='{hostname = ""; lastTimeColumn = NF-1; if (NF < 5) {hostname = "<console>"; lastTimeColumn = NF}}'
elif [ "x$KERNEL" = "xSunOS" ] ; then
	FILL_BLANKS='{hostname = ""; lastTimeColumn = NF-1; if (NF < 6) {hostname = "<console>"; lastTimeColumn = NF}}'
elif [ "x$KERNEL" = "xAIX" ] ; then
	FILL_BLANKS='{hostname = ""; lastTimeColumn = NF-1; if (NF < 6) {hostname = "<console>"; lastTimeColumn = NF}}'
elif [ "x$KERNEL" = "xHP-UX" ] ; then
    CMD='who -HR'
    FILL_BLANKS='{hostname = ""; lastTimeColumn = NF-1; if (NF < 5) {hostname = "<console>"; lastTimeColumn = NF}}'
elif [ "x$KERNEL" = "xDarwin" ] ; then
	FILL_BLANKS='{hostname = ""; lastTimeColumn = NF-1; if (NF < 6) {hostname = "<console>"; lastTimeColumn = NF}}'
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
	FILL_BLANKS='{hostname = ""; lastTimeColumn = NF-1; if (NF < 6) {hostname = "<console>"; lastTimeColumn = NF}}'
fi

assertHaveCommand $CMD

out=`$CMD | tee $TEE_DEST | $AWK "$HEADERIZE $FILL_BLANKS $FORMAT $PRINTF"  header="$HEADER"`
lines=`echo "$out" | wc -l`
if [ $lines -gt 1 ]; then
	echo "$out"
	echo "Cmd = [$CMD];  | $AWK '$HEADERIZE $FILL_BLANKS $FORMAT $PRINTF' header=\"$HEADER\"" >> $TEE_DEST
else
	echo "No data is present" >> $TEE_DEST
fi
