#!/bin/sh
# SPDX-FileCopyrightText: 2021 Splunk, Inc. <sales@splunk.com>
# SPDX-License-Identifier: Apache-2.0

# suggested command for testing reads: $ find / -type f 2>/dev/null | xargs wc &> /dev/null &

. `dirname $0`/common.sh

HEADER='Device          rReq_PS      wReq_PS        rKB_PS        wKB_PS  avgWaitMillis   avgSvcMillis   bandwUtilPct'
HEADERIZE="BEGIN {print \"$HEADER\"}"
PRINTF='{printf "%-10s  %11s  %11s  %12s  %12s  %13s  %13s  %13s\n", device, rReq_PS, wReq_PS, rKB_PS, wKB_PS, avgWaitMillis, avgSvcMillis, bandwUtilPct}'

if [ "x$KERNEL" = "xLinux" ] ; then
	CMD='iostat -xk 1 2'
	assertHaveCommand $CMD
	FILTER='/^$/ {next} /^Device/ {for (i = 1; i <= NF; i++) {if ($i == "svctm") { svctm=i; } else if ($i == "%util") {putil=i;} } reportOrd++; next} (reportOrd<2) {next}'
	FORMAT='{device=$1; rReq_PS=$4; wReq_PS=$5; rKB_PS=$6; wKB_PS=$7; avgQueueSZ=$9; avgWaitMillis=$10; avgSvcMillis=$svctm; bandwUtilPct=$putil}'
	HEADER='Device          rReq_PS      wReq_PS        rKB_PS        wKB_PS       avgQueueSZ   avgWaitMillis   avgSvcMillis   bandwUtilPct'
	HEADERIZE="BEGIN {print \"$HEADER\"}"
	PRINTF='{printf "%-10s  %11s  %11s  %12s  %12s  %13s  %13s  %13s  %13s\n", device, rReq_PS, wReq_PS, rKB_PS, wKB_PS, avgQueueSZ, avgWaitMillis, avgSvcMillis, bandwUtilPct}'
elif [ "x$KERNEL" = "xSunOS" ] ; then
	CMD='iostat -xn 1 2'
	assertHaveCommand $CMD
	FILTER='/[)(]|device statistics/ {next} /device/ {reportOrd++; next} (reportOrd==1) {next}'
	FORMAT='{device=$NF; rReq_PS=$1; wReq_PS=$2; rKB_PS=$3; wKB_PS=$4; avgWaitMillis=$7; avgSvcMillis=$8; bandwUtilPct=$10}'
elif [ "x$KERNEL" = "xAIX" ] ; then
	CMD='iostat  1 2'
	FILTER='/^cd/ {next} /^Disks:/ {reportOrd++; next} (reportOrd<2) {next}'
	FORMAT='{device=$1; rReq_PS="?"; wReq_PS="?"; rKB_PS=$5; wKB_PS=$6; avgWaitMillis="?"; avgSvcMillis="?"; bandwUtilPct=$2}'
elif [ "x$KERNEL" = "xDarwin" ] ; then
	CMD="eval $SPLUNK_HOME/bin/darwin_disk_stats ; sleep 2; echo Pause; $SPLUNK_HOME/bin/darwin_disk_stats"
	assertHaveCommandGivenPath $CMD
	FILTER='BEGIN {FS="|"; after=0} /^Pause$/ {after=1; next} !/Bytes|Operations/ {next} {devices[$1]=$1; values[after,$1,$2]=$3; next}'
	FORMAT='avgSvcMillis=bandwUtilPct="?";'
	FUNC1='function getDeltaPS(disk, metric) {delta=values[1,disk,metric]-values[0,disk,metric]; return delta/2.0}'
	# Calculates the latency by pulling the read and write latency fields from darwin__disk_stats and evaluating their sum
	LATENCY='function getLatency(disk) {read=getDeltaPS(disk,"Latency Time (Read)"); write=getDeltaPS(disk,"Latency Time (Write)"); return expr read + write;}'
	FUNC2='function getAllDeltasPS(disk) {rReq_PS=getDeltaPS(disk,"Operations (Read)"); wReq_PS=getDeltaPS(disk,"Operations (Write)"); rKB_PS=getDeltaPS(disk,"Bytes (Read)")/1024; wKB_PS=getDeltaPS(disk,"Bytes (Write)")/1024; avgWaitMillis=getLatency(disk);}'
	SCRIPT="$HEADERIZE $FILTER $FUNC1 $LATENCY $FUNC2 END {$FORMAT for (device in devices) {getAllDeltasPS(device); $PRINTF}}"
	$CMD | tee $TEE_DEST | awk "$SCRIPT"  header="$HEADER"
	echo "Cmd = [$CMD];  | awk '$SCRIPT' header=\"$HEADER\"" >> $TEE_DEST
	exit 0 
elif [ "x$KERNEL" = "xHP-UX" ] ; then
    assertHaveCommand sar
    CMD='sar -bd 2'
    FILTER='(NR<=5) {next} (NF==0) {next}'
    FORMAT='{q="?"} (NR%2) {rReq_PS=$3; wReq_PS=$6; rKB_PS=q; wKB_PS=q} (NR % 2 == 1) {device=$1; bandwUtilPct=$2; avgWaitMillis=$6; avgSvcMillis=$7; printf "%-10s  %11s  %11s  %12s  %12s  %13s %13s  %13s\n", device, rReq_PS, wReq_PS, rKB_PS, wKB_PS, avgWaitMillis, avgSvcMillis, bandwUtilPct}'
    PRINTF='{foo="bar"}'
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
	CMD='iostat -x -c 2'
	assertHaveCommand $CMD
	FILTER='/device statistics/ {next} /device/ {reportOrd++; next} (reportOrd==1) {next}'
	FORMAT='{device=$1; rReq_PS=$2; wReq_PS=$3; rKB_PS=$4; wKB_PS=$5; avgWaitMillis="?"; avgSvcMillis=$7; bandwUtilPct=$8}'
fi

$CMD | tee $TEE_DEST | awk "$HEADERIZE $FILTER $FORMAT $PRINTF"  header="$HEADER"
echo "Cmd = [$CMD];  | awk '$HEADERIZE $FILTER $FORMAT $PRINTF' header=\"$HEADER\"" >> $TEE_DEST
