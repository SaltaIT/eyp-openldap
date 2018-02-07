#!/bin/bash

function initbck
{
	mkdir -p $DESTINATION
	BACKUPTS=$(date +%Y%m%d%H%M)

	CURRENTBACKUPLOG="$LOGDIR/$BACKUPTS.log"

	BCKFAILED=999

	if [ -z "$LOGDIR" ];
	then
		exec 2>&1
	else
		exec >> $CURRENTBACKUPLOG 2>&1
	fi
}

function backup_config
{
	SLAPCAT=$(which slapcat 2>/dev/null)
	if [ -z "$SLAPCAT" ];
	then
		echo "slapcat not found"
		BCKFAILED=1
	else
		mkdir -p  $DESTINATION/$BACKUPTS

		$SLAPCAT -b cn=config > $DESTINATION/$BACKUPTS/config.ldif

		if [ $? -eq 0 ];
		then
			echo OPENLDAPBACKUP: config OK
			if [ "$BCKFAILED" -eq 999 ]; then BCKFAILED=0; fi
		else
			echo OPENLDAPBACKUP: FAILED: config
			BCKFAILED=1
		fi

		if [ ! -z "$GZIPBIN" ];
		then
			if [ -f "$DESTINATION/$BACKUPTS/config.ldif" ];
			then
				$GZIPBIN $DESTINATION/$BACKUPTS/config.ldif
			fi
		fi

	fi
}

function backup_bdb_hdb
{
	for DB in $($LDAPSEARCH -LLL -Y EXTERNAL -H ldapi:/// -s sub -b cn=config '(|(olcDatabase=hdb)(olcDatabase=bdb))' dn 2>/dev/null | awk '{ print $NF }')
	do
		#echo $DB
		SUFFIX=$($LDAPSEARCH -LLL -Y EXTERNAL -H ldapi:/// -s sub -b "$DB" olcSuffix 2>/dev/null | grep ^olcSuffix | awk '{ print $NF }')
		#echo $SUFFIX

		mkdir -p "$DESTINATION/$BACKUPTS/$DB"

		SLAPCAT=$(which slapcat 2>/dev/null)
		if [ -z "$SLAPCAT" ];
		then
			echo "slapcat not found"
			BCKFAILED=1
		else
			$SLAPCAT -b $SUFFIX > $DESTINATION/$BACKUPTS/$SUFFIX.ldif

			if [ $? -eq 0 ];
			then
				echo OPENLDAPBACKUP: $DB $SUFFIX OK
				if [ "$BCKFAILED" -eq 999 ]; then BCKFAILED=0; fi
			else
				echo OPENLDAPBACKUP: FAILED: $DB $SUFFIX
				BCKFAILED=1
			fi

			#
			# NO CANVIAR A BACKUPS INLINE
			#
			#[root@ldap backup]# (echo hola; exit 1); echo $?
			#hola
			#1
			#[root@ldap backup]# (echo hola; exit 1) | gzip >/dev/null; echo $?
			#0


			if [ ! -z "$GZIPBIN" ];
			then
				if [ -f "$DESTINATION/$BACKUPTS/$SUFFIX.ldif" ];
				then
					$GZIPBIN $DESTINATION/$BACKUPTS/$SUFFIX.ldif
				fi
			fi
		fi
	done
}

function backup_mdb
{

	for DB in $($LDAPSEARCH -LLL -Y EXTERNAL -H ldapi:/// -s sub -b cn=config '(olcDatabase=mdb)' dn 2>/dev/null | awk '{ print $NF }')
	do
		DATADIR=$($LDAPSEARCH -LLL -Y EXTERNAL -H ldapi:/// -s sub -b $DB '(&(objectclass=olcMdbConfig)(olcDatabase=mdb))' olcDbDirectory 2>/dev/null | grep "^olcDbDirectory" | awk '{ print $NF }')

		if [ -z "$DATADIR" ];
		then
			echo "MDB: no DATADIR found"
			BCKFAILED=1
		else
			MDBCOPY=$(which mdb_copy 2>/dev/null)
			if [ -z "$MDBCOPY" ];
			then
				echo "mdb_copy not found, please install lmdb"
				BCKFAILED=1
			else

				mkdir -p "$DESTINATION/$BACKUPTS/$DB"

				$MDBCOPY "$DATADIR" "$DESTINATION/$BACKUPTS/$DB"

				if [ $? -eq 0 ];
				then
					echo OPENLDAPBACKUP: $DB OK
					if [ "$BCKFAILED" -eq 999 ]; then BCKFAILED=0; fi
				else
					echo OPENLDAPBACKUP: FAILED: $DB
					BCKFAILED=1
				fi
			fi
		fi
	done
}

function cleanup
{
	if [ -z "$RETENTION" ];
	then
		echo "OPENLDAPBACKUP: cleanup skipped, no RETENTION defined"
	else
		find $DESTINATION -type f -mtime +$RETENTION -delete
		find $DESTINATION -type d -empty -delete
	fi
}

function mailer
{
	MAILCMD=$(which mail 2>/dev/null)
	if [ -z "$MAILCMD" ];
	then
		echo "mail not found, skipping"
	else
		if [ -z "$MAILTO" ];
		then
			echo "OPENLDAPBACKUP: mail skipped, no MAILTO defined"
			exit $BCKFAILED
		else
			if [ -z "$LOGDIR" ];
			then
				if [ "$BCKFAILED" -eq 0 ];
				then
					echo "OK" | $MAILCMD -s "$IDHOST-OpenLDAP-OK" $MAILTO
				else
					echo "ERROR - no log file configured" | $MAILCMD -s "$IDHOST-OpenLDAP-ERROR" $MAILTO
				fi
			else
				if [ "$BCKFAILED" -eq 0 ];
				then
					$MAILCMD -s "$IDHOST-OpenLDAP-OK" $MAILTO < $CURRENTBACKUPLOG
				else
					$MAILCMD -s "$IDHOST-OpenLDAP-ERROR" $MAILTO < $CURRENTBACKUPLOG
				fi
			fi
		fi
	fi
}

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

BASEDIRBCK=$(dirname $0)
BASENAMEBCK=$(basename $0)
IDHOST=${IDHOST-$(hostname -s)}

if [ ! -z "$1" ];
then
. $1
else
. $BASEDIRBCK/${BASENAMEBCK%%.*}.config 2>/dev/null
fi

LDAPSEARCH=$(which ldapsearch 2>/dev/null)
if [ -z "$LDAPSEARCH" ];
then
	echo "ldapsearch not found"
	exit 1
fi

GZIPBIN=$(which gzip 2>/dev/null)

initbck

backup_config

backup_mdb

backup_bdb_hdb

cleanup

mailer
