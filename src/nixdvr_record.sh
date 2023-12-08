#!/usr/bin/bash
#
# Copyright 2022 NIXIME@GITHUB
#

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Define our constants, paths and commands that will be needed
VERBOSE=0
DEBUG=0
ERRLVL=fatal
DEBUG_LEVEL=
CAMERA_NAME=null

# NIXDVR Config file parameters
OUTDIR=
SEGMENT_SIZE_S=
CONFIG_DIR=

# Camera Config file parameters
STREAM_URL=
STREAM_NAME=

# Define all the commands that we will be using. Make sure to do this so
# that this can be compared against the dracut config file otherwise the
# needed tools will be missing.
FFMPEG=/usr/bin/ffmpeg
DATE=/usr/bin/date
MKDIR=/usr/bin/mkdir
ECHO=/usr/bin/echo
TR=/usr/bin/tr
#---------------------------------------------------------------


# NOTE: This requires GNU getopt.  On Mac OS X and FreeBSD, you have to install this
# separately; see below.
TEMP=$(getopt -o vds:n:c: --long verbose,debug,stream:,name:,config: -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP"

while true; do
  case "$1" in
    -v | --verbose ) VERBOSE=1; shift ;;
    -d | --debug ) DEBUG=1; VERBOSE=1; shift ;;
    -n | --name ) CAMERA_NAME=$($ECHO "$2" | $TR '[:upper:]' '[:lower:]'); shift 2 ;;
    -c | --config ) CONFIG_FILE="$2"; shift 2 ;;
    -s | --stream ) STREAM_URL="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ ! -z "$CONFIG_FILE" ]; then
    while IFS="=" read -r key value; do
        case "$key" in
        "ConfigDir") CONFIG_DIR="$value" ;;
        "StorageDir") OUTDIR="$value" ;;
        "SegmentSize_s") SEGMENT_SIZE_S="$value" ;;
        esac
    done < "$CONFIG_FILE"
else
    exit 1
fi

#
# Get the STREAM information from the camera configuration file
#
if [ ! -z "$CONFIG_DIR" ]; then
    CFGFILE=$CONFIG_DIR/$CAMERA_NAME.cfg
    if [ -e "$CFGFILE" ]; then
        while IFS="=" read -r key value; do
            case "$key" in
            "STREAM_URL") STREAM_URL="$value" ;;
            "STREAM_NAME") STREAM_NAME="$value" ;;
            "DEBUG_LEVEL") DEBUG_LEVEL="$value" ;;
            esac
        done < "$CFGFILE"
    else
        exit 1
    fi
fi

# Override config file with command line options
if [ "x$VERBOSE" = "x1" ]; then
    DEBUG_LEVEL=verbose
elif [ "x$DEBUG" = "x1" ]; then
    DEBUG_LEVEL=debug
fi

if [ "x$DEBUG_LEVEL" = "xtrace" ]; then
    set -ex
    ERRLVL=fatal
elif [ "x$DEBUG_LEVEL" = "xverbose" ]; then
    set -ex
    ERRLVL=verbose
elif [ "x$DEBUG_LEVEL" = "xdebug" ]; then
    ERRLVL=debug
else   
    ERRLVL=fatal
fi

# Handle if no STREAM_NAME is defined
if [ "x$STREAM_NAME" = "x" ]; then
    STREAM_NAME=$CAMERA_NAME
fi

# Create working directory for files to be put
WORKDIR=$OUTDIR/$STREAM_NAME/_
if [ ! -e $WORKDIR ]; then
    mkdir -p $WORKDIR
fi

#
# Record the stream, writing it to the necessary folder structure.
#
$FFMPEG \
    -hide_banner -y\
    -nostdin\
    -loglevel $ERRLVL\
    -nostats \
    -rtsp_transport tcp\
    -use_wallclock_as_timestamps 1\
    -i $STREAM_URL\
    -vcodec copy\
    -acodec copy\
    -f segment\
    -reset_timestamps 1\
    -segment_time $SEGMENT_SIZE_S\
    -segment_format mkv\
    -segment_atclocktime 1\
    -strftime 1\
    $WORKDIR/%Y%m%d_%H%M%S.mkv
