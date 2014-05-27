#!/bin/sh
#
#/*******************************************************************
# * This file is part of the Emulex Linux Device Driver for         *
# * Fibre Channel Host Bus Adapters.                                *
# * Copyright (C) 2003-2005 Emulex.  All rights reserved.           *
# * EMULEX and SLI are trademarks of Emulex.                        *
# * www.emulex.com                                                  *
# *                                                                 *
# * This program is free software; you can redistribute it and/or   *
# * modify it under the terms of version 2 of the GNU General       *
# * Public License as published by the Free Software Foundation.    *
# * This program is distributed in the hope that it will be useful. *
# * ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND          *
# * WARRANTIES, INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY,  *
# * FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT, ARE      *
# * DISCLAIMED, EXCEPT TO THE EXTENT THAT SUCH DISCLAIMERS ARE HELD *
# * TO BE LEGALLY INVALID.  See the GNU General Public License for  *
# * more details, a copy of which can be found in the file COPYING  *
# * included with this package.                                     *
# *******************************************************************/
#
# scripts/lun_scan Rev : 1.2
# This script is provided by Emulex to use with its 7.x and 8.x linux device
# drivers for Light Pulse Fibre Channel adapters.
#
# This script performs a scan on either specific lpfc HBAs or on all
# lpfc HBAs.  When scanning an HBA, all discovered targets, and all
# luns will be probed.
#
#
# USAGE: The script is invoked with at least 1 argument. The arguments
# specify either the SCSI Host numbers corresponding to the specific
# lpfc HBA that are to be scanned, or the keyword "all" which indicates
# that all lpfc HBAs are to be scanned.
#
VERSION="1.2"
OS_REV=`uname -r | cut -c1-3`
usage()
{
        echo ""
        echo "Usage: lun_scan [ <#> [<#>] | all ]"
        echo "  where "
        echo "    <#> : is a scsi host number of a specific lpfc HBA that is to"
        echo "          be scanned. More than 1 host number can be specified. "
        echo "    all : indicates that all lpfc HBAs are to be scanned."
        echo ""
        echo "  Example:"
        echo "    lun_scan all  : Scans all lpfc HBAs"
        echo "    lun_scan 2    : Scans the lpfc HBA with scsi host number 2"
        echo "    lun_scan 2 4  : Scans the lpfc HBAs with scsi host number 2 and 4"
        echo ""
        echo "  Warning: Scanning an adapter while performing a tape backup should"
        echo "    be avoided."
        echo ""
}



abort_exit() {
        echo ""
       echo "Error: Cannot find an lpfc HBA instance with scsi host number : $host"
        echo "... Aborting lun_scan."
        echo ""
        exit 2
}



# Validate argument list
if [ $# -eq 0 -o "$1" = "--help" -o "$1" = "-h" ] ; then
    usage
    exit 1
fi

# Get list of lpfc HBAs to scan
hosts=$*;

if [ ${OS_REV} = 2.4 ]; then
    lowhost=0
    ha=`ls /proc/scsi/lpfc/?   2> /dev/null | cut -f5 -d'/'`
    hb=`ls /proc/scsi/lpfc/??  2> /dev/null | cut -f5 -d'/'`
    hc=`ls /proc/scsi/lpfc/??? 2> /dev/null | cut -f5 -d'/'`
    all_hosts="$ha $hb $hc"
    lowhost=`echo $all_hosts | sed "s/ .*//"`
else
    all_hosts=`ls -1 -d /sys/bus/pci/drivers/lpfc/*/host* | sed -e "s/.*host//"`
fi

# If all option is used get all the lpfc host numbers.
if [ "$hosts" == "all" ] ; then
    hosts="$all_hosts"
fi

if [ ${OS_REV} = 2.4 ]; then

    for host in $hosts ; do
        # Convert host number to lpfc instance number.
        instance=`expr $host - $lowhost`
        if [ ! -e /proc/scsi/lpfc/$host ] ; then
            abort_exit
        fi

        echo Scanning lpfc$instance, scsi host number : $host;
        max_lun=256
        targets=`cat /proc/scsi/lpfc/$host | grep 'lpfc*t*' | cut -f2 -d't' | cut -f1 -d' '`
        for target in $targets ; do
            # Convert target ID to decimal from Hex format
            let "dec_target = 0x$target"
            echo "   Scanning Target Id $dec_target..."
            for ((lun=0; lun<$max_lun; lun++)) ; do
               echo "scsi add-single-device $host 0 $dec_target $lun" >/proc/scsi/scsi
            done
        done
    done
else
    for host in $hosts ; do
        if [ ! -e /sys/bus/pci/drivers/lpfc/*/host$host ] ; then
            abort_exit
        fi



        echo Scanning lpfc HBA instance with scsi host number : $host;
        echo '- - -' > /sys/class/scsi_host/host$host/scan
    done
fi

