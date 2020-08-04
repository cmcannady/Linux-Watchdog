#!/bin/sh

# Include PATH for root
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

# *** ***************************************************************** ***
# ***                                                                   ***
# *** Casey Cannady (casey.cannady@hcl.com)                             ***
# *** BigFix Professional Services                                      ***
# *** HCL Software                                                      ***
# *** 08/01/2020                                                        ***
# ***                                                                   ***
# *** This script MUST be run as root on the BESClient endpoints.       ***
# ***                                                                   ***
# *** This bash script is provided "as-is" and without warranty.        ***
# ***                                                                   ***
# *** ***************************************************************** ***

# Declare variables for script
declare -i NoPID=1
CoreDump="False"
ExitCode="0"
LogName="besclient_watchdog.log"
LogPath="/var/log"
LogFile="$LogPath/$LogName"
LogIndent="     "
RestartSvcs="False"

# Declare patterns for service case statements
Pattern0="no process"
Pattern1="*Active: active (exited)*"
Pattern2="*dead but subsys locked*"
Pattern3="*is stopped*"

# Declare start timestamp of script
StartTimestamp=$(date)

# Check for existance of log file and setup if necessary
if [ ! -f "$LogFile" ]; then
    mkdir -p $LogPath
    touch $LogFile
    chmod u=rw,g=rw $LogFile
fi

# Start logging to defined file
echo "--------------------------------------------------" >> $LogFile
echo "$StartTimestamp :: BESClient Watchdog has started." >> $LogFile

# Store the PID of BESClient process
BESClientPID=$(pidof -s BESClient)
if [ -z "$BESClientPID" ]; then
    echo "$LogIndent Unable to obtain the process ID of the BESClient service." >> $LogFile
    BESClientPID=0
else
    echo "$LogIndent The process ID of the BESClient is $BESClientPID." >> $LogFile
fi

# Store the status of the BESClient service
if [ "$BESClientPID" -gt "$NoPID" ]; then
    BESClientStatus=$(service besclient status)
    if [ "$?" -ne "0" ]; then
        ExitCode="999" && echo "$LogIndent Failed to retrieve status of BESClient service. Exit code $ExitCode." >> $LogFile
    fi
else
    BESClientStatus=$Pattern0
    echo "$LogIndent Unable to obtain BESClient service status." >> $LogFile
fi

# Case statement to check BESClient status text for known BAD states
case "$BESClientStatus" in
    $Pattern0 ) echo "$LogIndent The BESClient process is not running." >> $LogFile && RestartSvcs="True";;
    $Pattern1 ) echo "$LogIndent The BESClient status reports as active but exited." >> $LogFile && RestartSvcs="True";;
    $Pattern2 ) echo "$LogIndent The BESClient status reports dead but subsys locked." >> $LogFile && RestartSvcs="True";;
    $Pattern3 ) echo "$LogIndent The BESClient status reports as stopped." >> $LogFile && RestartSvcs="True";;
    * ) echo "$LogIndent The BESClient (PID#$BESClientPID) status is as expected." >> $LogFile;;
esac

# Drop two events to the script log
echo "$LogIndent The restart services flag is $RestartSvcs." >> $LogFile
echo "$LogIndent The core dump flag is $CoreDump." >> $LogFile

# Should we take core dumps of the BESClient process
if [ "$CoreDump" == "True" ]; then
    # Generate core dump of BESClient PID
    gcore $BESClientPID
    if [ "$?" -ne "0" ]; then ExitCode="997" && echo "$LogIndent Failed to create core dump of BESClient PID $BESClientPID. Exit code $ExitCode." >> $LogFile; fi
fi

# Termination and restarting of BES services when required
if [ "$RestartSvcs" == "True" ]; then
    # Isssue standard service stop command for BESClient
    service besclient stop
    if [ "$?" -ne "0" ]; then
        if [ "$BESClientPID" -ne "0" ]; then
            kill -9 $BESClientPID
            echo "$LogIndent BESClient service failed to stop." >> $LogFile
        else
            echo "$LogIndent BESClient service has no active PID." >> $LogFile
        fi
    else
        echo "$LogIndent BESClient service has been stopped successfully." >> $LogFile
    fi

    # Restart BESClient service
    service besclient start
    if [ "$?" -ne "0" ]; then ExitCode="995" && echo "$LogIndent Failed to start BESClient service. Exit code $ExitCode." >> $LogFile; else echo "$LogIndent The BESClient service has been restarted." >> $LogFile; fi
else
    echo "$LogIndent No restarting of BESClient service was necessary." >> $LogFile
fi

# *** ************************************************************ ***
# ***                                                              ***
# *** STUB FOR INTEGRATING WITH ENTERPRISE NOTIFICATION WEBSERVICE ***
# ***                                                              ***
# *** ************************************************************ ***

    # Check exit code variable for non-zero value
    if [ "$ExitCode" -ne "0" ]; then
        echo "$LogIndent Something has gone wrong and needs to be reported accordingly via the enterprise notification service. Exit code $ExitCode." >> $LogFile
    fi

# *** ************************************************************ ***
# ***                                                              ***
# *** STUB FOR INTEGRATING WITH ENTERPRISE NOTIFICATION WEBSERVICE ***
# ***                                                              ***
# *** ************************************************************ ***

# Declare end timestamp of script
EndTimestamp=$(date)

# End logging to defined file
echo "$EndTimestamp :: BESClient Watchdog has finished." >> $LogFile
echo $LogIndent >> $LogFile

# We're done!
exit $ExitCode