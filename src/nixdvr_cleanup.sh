#!/usr/bin/sh
#
# Copyright 2023 NIXIME@GITHUB
#

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Define our constants, paths and commands that will be needed
VERBOSE=false
DEBUG=false
ERRLVL=error
STORAGE_DIR=
STORAGE_AGE_T=0
STORAGE_AGE=0
CONFIG_FILE=/etc/nixdvr.cfg

# Define all the commands that we will be using. Make sure to do this so
# that this can be compared against the dracut config file otherwise the
# needed tools will be missing.
FIND=/usr/bin/find
#---------------------------------------------------------------

# NOTE: This requires GNU getopt.  On Mac OS X and FreeBSD, you have to install this
# separately; see below.
TEMP=$(getopt -o vdc:n: --long verbose,debug,config: -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP"

while true; do
  case "$1" in
    -v | --verbose ) VERBOSE=true; shift ;;
    -d | --debug ) DEBUG=true; VERBOSE=true; shift ;;
    -c | --config ) CONFIG_FILE="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ "x$VERBOSE" = "xtrue" ]; then
    set -ex
    ERRLVL=verbose
fi

if [ "x$DEBUG" = "xtrue" ]; then
    ERRLVL=debug
fi

if [ ! -z "$CONFIG_FILE" ]; then
    while IFS="=" read -r key value; do
        case "$key" in
        "StorageDir") STORAGE_DIR="$value" ;;
        "StorageAgeTemp") STORAGE_AGE_T="$value" ;;
        "StorageAge") STORAGE_AGE="$value" ;;
        "ConfigDir") CONFIG_DIR="$value" ;;
        esac
    done < "$CONFIG_FILE"
else
    exit 1
fi

for cfgfile in $CONFIG_DIR/*.cfg; do

    # Pull the stream name from the config file
    while IFS="=" read -r key value; do
        case "$key" in
        "STREAM_NAME") STREAM_NAME="$value" ;;
        esac
    done < "$cfgfile"

    # Process only the files within the stream folder. This should allow it to work
    # in a docker image or as a single instance on a systemd setup.
    for i in $($FIND $STORAGE_DIR/$STREAM_NAME -maxdepth 1 -type d ); do
        echo $i
        if [ "x$i" != "x$STORAGE_DIR" ]; then

            if [ $STORAGE_AGE_T -gt 0 ]; then
                old_folder="${i}/merged"
                if [ -d "$old_folder" ]; then
                    $FIND $old_folder -mtime +$STORAGE_AGE_T -name "*.mkv" -type f -delete
                fi	
            fi

            if [ $STORAGE_AGE -gt 0 ]; then
                $FIND $i -maxdepth 1 -mtime +$STORAGE_AGE -name "*.mkv" -type f -delete
            fi
        fi
    done
done
