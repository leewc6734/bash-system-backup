#!/bin/bash

export LANG=en_US.UTF-8

SERVER_PREFIX=$(hostname)
DB_NAME_MARIADB=mariadb

COMPRESS_7z='7z'
COMPRESS_xz='xz'
COMPRESS_gz='gz'
COMPRESS_bz2='bz2'

EXT_SQL='sql'
EXT_TAR_BZ2='tar.bz2'
EXT_7Z='7z'
EXT_TAR_XZ='tar.xz'
EXT_COMPRESS=$EXT_TAR_XZ

DEFAULT_COMPRESS_METHOD=$COMPRESS_xz

BAK_DATE=$(date +%F)
#BAK_DATE=$(date +%s)

# Root diectory of backup date
BACKUP_ROOT=/backup_storage/shadowserv

# System config backup setting
SERVER_CONFIG_PATH=/etc
SERVER_CONFIG_BAK_PATH=$BACKUP_ROOT/config


# Check require command
REQUIRED_CMD=($DEFAULT_COMPRESS_METHOD "mysqldump")
for i in ${REQUIRED_CMD[@]}; do
    if ! [[ -f $(which $i) ]]; then
        printf "ERROR: Required command($i) not found!\n"
        exit 1
    else
        printf "$i..... ready!\n"
    fi
done

echo ""

compress_data () {

	# $METHOD=$1
	METHOD=$1
	SOURCE=$2
	DESTINATION=$3

	case $METHOD in

		$COMPRESS_gz)
			CMD="tar zcvf $DESTINATION $SOURCE"
			;;

		$COMPRESS_bz2 | $COMPRESS_xz)
			CMD="tar jcvf $DESTINATION $SOURCE"
			;;

		$COMPRESS_7z)
			CMD="7z a $DESTINATION $SOURCE"
			;;

		*)
			printf 'Unknown compress method, abort!\n'
			exit
			;;
	esac

	echo "[command] $CMD"
	if $CMD; then
		printf "Done!\n\n"
	else
		printf "Failed!\n\n"
		exit
	fi
}

# Backup command for SERVER config
FILENAME_CONFIG=${SERVER_CONFIG_BAK_PATH}/${SERVER_PREFIX}_serverconfig_backup_${BAK_DATE}.$EXT_COMPRESS
#echo "Config name: $FILENAME_CONFIG"
#echo "CMD: $FILENAME_CONFIG $SERVER_CONFIG_PATH"
#sudo tar jcvf $FILENAME_CONFIG $SERVER_CONFIG_PATH

#7z a $FILENAME_CONFIG $SERVER_CONFIG_PATH
compress_data $DEFAULT_COMPRESS_METHOD $SERVER_CONFIG_PATH $FILENAME_CONFIG
find ${SERVER_CONFIG_BAK_PATH} -name "*.$EXT_COMPRESS" -mtime +10 -exec rm -f {} \;

# Database backup setting
DB_BAK_PATH=$BACKUP_ROOT/db
DB_FULLBAK_PATH=$BACKUP_ROOT/db_fullbackup
DB_BAK_ADMIN=root
DB_BAK_ADMIN_PASSWD=IFD1108e


# Full Backup command for Mariadb
FILE_NAME_FULLBAK=${SERVER_PREFIX}_${DB_NAME_MARIADB}_fullbackup_${BAK_DATE}
# echo "fullbackup_DB_name: $FILE_NAME_FULLBAK"
# echo "target: $DB_FULLBAK_PATH/"
# mysqldump --all-databases --single-transaction -quick --skip-lock-tables -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
# tar jcvf $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_TAR_BZ2 $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
# 7z a $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_COMPRESS $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
# if [  $? -eq 0 ]; then
#     echo "Try to delete temp SQL file -> $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL"
#     rm $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
# else
#     echo "TAR result: $?"
#     echo "Fail to compress SQL file!!!"
# fi

# Remove old backup files over 60 days
# find ${DB_FULLBAK_PATH} -name "*.$EXT_COMPRESS" -mtime +60 -exec rm -f {} \;

# Get database name from backup list
CONFIG_DB_LIST=$(dirname "$0")/conf/database_backup_list.conf
IGNORE_PATTEN="^#"

# Execute individual database backup procdure in database list
while read DBNAME; do

	if ! [[ "$DBNAME" =~ $IGNORE_PATTEN ]] && ! [ -z $DBNAME ]; then
    #if ! [[ "$DBNAME" =~ $IGNORE_PATTEN ]]; then

		DB_BAK_FILENAME=${SERVER_PREFIX}_${DB_NAME_MARIADB}_${DBNAME}_backup_${BAK_DATE}

		echo
		printf "starting backup database: [$DBNAME]\n"
		printf "Filename: [$DB_BAK_FILENAME]\n"

		if [[ -d "$DB_BAK_PATH" ]]; then

			#mysqldump "$DBNAME" --single-transaction -quick --skip-lock-tables -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > "$DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL"
            #mysqldump "$DBNAME" --single-transaction -quick --skip-lock-tables --no-data -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > "$DB_BAK_PATH/${DB_BAK_FILENAME}_schema_only.$EXT_SQL"

			CMD_BACKUP_DB="mysqldump $DBNAME --single-transaction -quick --skip-lock-tables -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL"

			CMD_BACKUP_DB_SCHEME="mysqldump $DBNAME --single-transaction -quick --skip-lock-tables --no-data -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > $DB_BAK_PATH/${DB_BAK_FILENAME}_schema_only.$EXT_SQL"

			# echo "[debug] = "$CMD_BACKUP_DB
			# echo "[debug] = "$CMD_BACKUP_DB_SCHEME

			if eval $CMD_BACKUP_DB && eval $CMD_BACKUP_DB_SCHEME; then
				printf "Dump database: \"$DBNAME\" to \"$DB_BAK_PATH/\" is done.\n\n"
				printf "Compressing now...\n"

				compress_data $DEFAULT_COMPRESS_METHOD $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_COMPRESS
				# 7z a $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_COMPRESS $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL

                # Remove .sql file if compress process is done
				if [[ $? -eq 0 ]]; then
					#printf "done!\n"
                    printf "Delete temp SQL file -> $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL\n"
					rm $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL

                    # Remove old backup files over 40 days
                    find ${DB_BAK_PATH} -name "*.$EXT_COMPRESS" -mtime +40 -exec rm -f {} \;
					find ${DB_BAK_PATH} -name "*.$EXT_SQL" -mtime +40 -exec rm -f {} \;

				else
					printf "Fail to compressing SQL file: $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL"
				fi

			else
				printf "Dump database: $DBNAME failed!\n"
			fi

		else
			printf "$DB_BAK_PATH is not exists. please check and run again.\n"
		fi

        echo
    fi

done <$CONFIG_DB_LIST

# cloud service backup setting
PHPVER=php7
CLOUD_HOME=/solutions/services
CLOUD_PROJECT_BARREL=project_barrel
CLOUD_PROJECT_VIPER=project_viper
CLOUD_BAK_PATH=$BACKUP_ROOT/services

# Backup command for Cloud Service -> Barrel
FILENAME_SERVICE_BARREL=${CLOUD_BAK_PATH}/${SERVER_PREFIX}_${CLOUD_PROJECT_BARREL}_${PHPVER}_${BAK_DATE}.$EXT_COMPRESS

# Backup command for Cloud Service -> Viper
FILENAME_SERVICE_VIPER=${CLOUD_BAK_PATH}/${SERVER_PREFIX}_${CLOUD_PROJECT_VIPER}_${PHPVER}_${BAK_DATE}.$EXT_COMPRESS

# echo "service -> \"barrel\" name: $FILENAME_SERVICE_BARREL"
# echo "cloud -> barrel CMD: $FILENAME_SERVICE_BARREL ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL}"
#sudo tar jcvf $FILENAME_SERVICE_BARREL ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL}
#7z a $FILENAME_SERVICE_BARREL ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL}

compress_data $DEFAULT_COMPRESS_METHOD ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL} $FILENAME_SERVICE_BARREL
compress_data $DEFAULT_COMPRESS_METHOD ${CLOUD_HOME}/${CLOUD_PROJECT_VIPER} $FILENAME_SERVICE_VIPER

find ${CLOUD_BAK_PATH} -name "*.$EXT_COMPRESS" -mtime +60 -exec rm -f {} \;

# WEB backup setting
WEB_HOME=/solutions/www
WEB_SITE_GOLDTEKCONNECT=goldtekconnect.com
WEB_BAK_PATH=$BACKUP_ROOT/web

# Backup command for WEB Service -> goldtekconnect.com
#FILENAME_WEB=${WEB_BAK_PATH}/${SERVER_PREFIX}_${WEB_SITE_GOLDTEKCONNECT}_${PHPVER}_${BAK_DATE}.$EXT_COMPRESS
# echo "service -> \"barrel\" name: $FILENAME_WEB"
# echo "web -> goldtekconnect CMD: $FILENAME_WEB ${WEB_HOME}/${WEB_SITE_GOLDTEKCONNECT}"
#sudo tar jcvf $FILENAME_WEB ${WEB_HOME}/${WEB_SITE_GOLDTEKCONNECT}
#7z a $FILENAME_WEB ${WEB_HOME}/${WEB_SITE_GOLDTEKCONNECT}
#find ${WEB_BAK_PATH} -name "*.$EXT_COMPRESS" -mtime +10 -exec rm -f {} \;

