#!/bin/bash

set -u

# 
# Argument defaults
# 
BIN="$( readlink -f -- "${0%/*}" )"
if [ -f $BIN ]; then
  BIN=$(dirname $BIN)
fi

IN_DIR=""
OUT_DIR=""
FILES_LIST=""
ALIAS_FILE=""
NUM_GBME_SCANS=""
BAR="# ----------------------"

#
# Functions
#
function lc() {
  wc -l $1 | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -i IN_DIR -o OUT_DIR\n\n" $(basename $0)

  echo "Required Arguments:"
  echo " -i IN_DIR (where the msh files are)"
  echo " -o OUT_DIR (where to put SNA files)"
  echo " -n NUM_GBME_SCANS"
  echo
  echo "Options"
  echo " -a ALIAS_FILE"
  echo " -l FILES_LIST"
  exit 0
}

if [[ $# == 0 ]]; then
  HELP
fi

#
# Setup
#
PROG=$(basename "$0" ".sh")
LOG="$BIN/launcher-$PROG.log"
PARAMS_FILE="$BIN/${PROG}.params"

if [[ -e $LOG ]]; then
  rm $LOG
fi

if [[ -e $PARAMS_FILE ]]; then
  echo Removing previous PARAMS_FILE \"$PARAMS_FILE\" >> $LOG
  rm $PARAMS_FILE
fi

echo $BAR >> $LOG
echo "Invocation: $0 $@" >> $LOG

#
# Get args
#
while getopts :a:i:l:n:o:h OPT; do
  case $OPT in
    a)
      ALIAS_FILE="$OPTARG"
      ;;
    i)
      IN_DIR="$OPTARG"
      ;;
    h)
      HELP
      ;;
    l)
      FILES_LIST="$OPTARG"
      ;;
    n)
      NUM_GBME_SCANS="$OPTARG"
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument." >> $LOG
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}" >> $LOG
      exit 1
  esac
done

#
# Check args
#
if [[ ${#IN_DIR} -lt 1 ]]; then
  echo "Error: No IN_DIR specified." >> $LOG
  exit 1
fi

if [[ ${#OUT_DIR} -lt 1 ]]; then
  echo "Error: No OUT_DIR specified." >> $LOG
  exit 1
fi

if [[ ! -d $IN_DIR ]]; then
  echo "Error: IN_DIR \"$IN_DIR\" does not exist." >> $LOG
  exit 1
fi

if [[ -d $OUT_DIR ]]; then
  rm -rf $OUT_DIR/*
else 
  mkdir -p $OUT_DIR
fi

# 
# Find input files
# 
MSH_FILES=$(mktemp)
if [[ -n $FILES_LIST ]]; then
  echo Taking files from list \"$FILES_LIST\" >> $LOG
  cat -n $FILES_LIST
  while read FILE; do
    BASENAME=$(basename $FILE)
    FILE_PATH="$IN_DIR/$BASENAME.msh"
    if [[ -e $FILE_PATH ]]; then
      echo $FILE_PATH >> $MSH_FILES
    else
      echo Cannot find \"$BASENAME\" in \"$IN_DIR\" >> $LOG
    fi
  done < $FILES_LIST
else 
  find $IN_DIR -type f \*.msh > $MSH_FILES
fi

NUM_FILES=$(lc $MSH_FILES)

if [[ $NUM_FILES -lt 1 ]]; then
  echo "Error: Found no MSH files in IN_DIR \"$IN_DIR\"" >> $LOG
  exit 1
fi

echo $BAR                  >> $LOG
echo Settings for run:     >> $LOG
echo "IN_DIR     $IN_DIR"  >> $LOG
echo "OUT_DIR    $OUT_DIR" >> $LOG
echo $BAR                  >> $LOG
echo "Will process $NUM_FILES msh files" >> $LOG
cat -n $MSH_FILES          >> $LOG

ALL=$OUT_DIR/all
if [[ -e $ALL.msh ]]; then
  rm $ALL.msh
fi

mash paste -l $ALL $MSH_FILES
ALL=$ALL.msh
DISTANCE_MATRIX=$OUT_DIR/dist.tab
mash dist -t $ALL $ALL > $DISTANCE_MATRIX
rm $ALL

META_DIR=$OUT_DIR/meta
LIST_ARG=""
if [[ -n $FILES_LIST ]]; then
  LIST_ARG="-l $FILES_LIST"
fi

$BIN/make-metadata-dir.pl -f $METADATA_FILE -d $META_DIR $LIST_ARG

# this will create the inverted matrix
$BIN/viz.r -f $DISTANCE_MATRIX -o $OUT_DIR

MATRIX=$OUT_DIR/matrix.tab

if [[ ! -s $MATRIX ]]; then
  echo "viz.R failed to create \"$MATRIX\"" >> $LOG
  exit 1
fi

ALIAS_FILE_ARG=""
if [[ -n $ALIAS_FILE ]]; then
  ALIAS_FILE_ARG="-a $ALIAS_FILE"
fi

$BIN/sna.r -o $OUT_DIR -f $MATRIX -n $NUM_GBME_SCANS $ALIAS_FILE_ARG

echo Done.
