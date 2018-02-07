#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

function printusage
{
  echo "$0 [-w <VAL>] [-c <VAL>] -v <DATAFILE>"
  echo -e "\t-w 80 by default"
  echo -e "\t-c 90 by default"
}

while getopts 'v:w:c:' OPTION
do
  case $OPTION in
  w)
  WVAL="$OPTARG"
        ;;
  c)
  CVAL="$OPTARG"
        ;;
  v)
        DATAFILE="$OPTARG"
        ;;
  ?)
  echo Argument invalid
  printusage
        exit 3
        ;;
  esac
done

WARNING=${WVAL-80}
CRITICAL=${CVAL-90}

if [ -z "$DATAFILE" ];
then
  printusage
  exit 3
fi

if [ ! -f "$DATAFILE" ];
then
  echo "$DATAFILE not found"
  exit 3
fi

USED=$(ls -ks $DATAFILE | awk '{ print $1 }')
MAXSIZE=$(ls -kl $DATAFILE | awk '{ print $5 }')
USEDP=$(printf "%0.5f" $(echo "($USED/$MAXSIZE)*100" | bc -l))
USEDPV=$(echo $USEDP | sed 's/\..*//')

STATUS="$DATAFILE $USEDP% used| used=$USED; maxsize=$MAXSIZE;"

if [ -z "$USEDPV" ];
then
  echo "UNKNOWN"
  exit 3;
elif [ $USEDPV -ge $CRITICAL ];
then
  echo CRITICAL - $STATUS
  exit 2
elif [ $USEDPV -ge $WARNING ];
then
  echo WARNING - $STATUS
  exit 1
else
  echo OK - $STATUS
  exit 0
fi
