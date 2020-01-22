#!/bin/bash

export LANG=en_US.UTF-8

SERVER_PREFIX=$(hostname)
DB_NAME_MARIADB=mariadb

BACKUP_ROOT=/backup_storage/cserv-dev
EXT_SQL=sql
EXT_TAR_BZ2=tar.bz2
EXT_7Z=7z
EXT_COMPRESS=$EXT_7Z

BAK_DATE=$(date +%F)
#BAK_DATE=$(date +%s)

# System config backup setting
SERVER_CONFIG_PATH=/etc
SERVER_CONFIG_BAK_PATH=$BACKUP_ROOT/config


# Check require command
REQUIRED_CMD=("7z" "mysqldump")
for i in ${REQUIRED_CMD[@]}; do
    if ! [[ -f $(which $i) ]]; then
        printf "ERROR: Required command($i) not found!\n"
        exit 1
    else
        printf "$(which -a $i) ..... ready!\n"
    fi
done


# Backup command for SERVER config
FILENAME_CONFIG=${SERVER_CONFIG_BAK_PATH}/${SERVER_PREFIX}_serverconfig_backup_${BAK_DATE}.$EXT_COMPRESS
#echo "Config name: $FILENAME_CONFIG"
#echo "CMD: $FILENAME_CONFIG $SERVER_CONFIG_PATH"
#sudo tar jcvf $FILENAME_CONFIG $SERVER_CONFIG_PATH
7z a $FILENAME_CONFIG $SERVER_CONFIG_PATH
find ${SERVER_CONFIG_BAK_PATH} -name "*.$EXT_COMPRESS" -mtime +10 -exec rm -f {} \;


# Database backup setting
DB_BAK_PATH=$BACKUP_ROOT/db
DB_FULLBAK_PATH=$BACKUP_ROOT/db_fullbackup
DB_BAK_ADMIN=root
DB_BAK_ADMIN_PASSWD=IFD1108e


# Full Backup command for Mariadb
FILE_NAME_FULLBAK=${SERVER_PREFIX}_${DB_NAME_MARIADB}_fullbackup_${BAK_DATE}
#echo "fullbackup_DB_name: $FILE_NAME_FULLBAK"
#echo "target: $DB_FULLBAK_PATH/"
#mysqldump --all-databases --single-transaction -quick --skip-lock-tables -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
#tar jcvf $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_TAR_BZ2 $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
#7z a $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_COMPRESS $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
if [  $? -eq 0 ]; then
    echo "Try to delete temp SQL file -> $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL"
    rm $DB_FULLBAK_PATH/$FILE_NAME_FULLBAK.$EXT_SQL
else
    echo "TAR result: $?"
    echo "Fail to compress SQL file!!!"
fi

# Remove old backup files over 60 days
find ${DB_FULLBAK_PATH} -name "*.$EXT_COMPRESS" -mtime +60 -exec rm -f {} \;

# Get database name from backup list
CONFIG_DB_LIST=$(dirname "$0")/conf/database_backup_list.conf
IGNORE_PATTEN='^#'

# Execute individual database backup procdure in database list
while read DBNAME ; do
    
    if ! [[ "$DBNAME" =~ $IGNORE_PATTEN ]]; then
	
		DB_BAK_FILENAME=${SERVER_PREFIX}_${DB_NAME_MARIADB}_${DBNAME}_backup_${BAK_DATE}
	
		echo
		printf "starting backup database: [$DBNAME]\n"
		printf "Filename: [$DB_BAK_FILENAME]\n"

		if [[ -d "$DB_BAK_PATH" ]]; then
			mysqldump "$DBNAME" --single-transaction -quick --skip-lock-tables -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > "$DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL"
            mysqldump "$DBNAME" --single-transaction -quick --skip-lock-tables --no-data -u $DB_BAK_ADMIN -p$DB_BAK_ADMIN_PASSWD > "$DB_BAK_PATH/${DB_BAK_FILENAME}_schema_only.$EXT_SQL"

			if [[ $? -eq 0 ]]; then
				printf "Dump database: $DBNAME to $DB_BAK_PATH/ is done.\n"
				printf "Compressing now...\n"

				7z a $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_COMPRESS $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL

                # Remove .sql file if compress process is done
				if [[ $? -eq 0 ]]; then
					printf "done!\n"
                    printf "Try to delete temp SQL file -> $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL\n"
					rm $DB_BAK_PATH/$DB_BAK_FILENAME.$EXT_SQL

                    # Remove old backup files over 40 days
                    find ${DB_BAK_PATH} -name "*.$EXT_COMPRESS" -mtime +40 -exec rm -f {} \;

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
CLOUD_BAK_PATH=$BACKUP_ROOT/services

# Backup command for Cloud Service -> barrel
FILENAME_SERVICE_BARREL=${CLOUD_BAK_PATH}/${SERVER_PREFIX}_${CLOUD_PROJECT_BARREL}_${PHPVER}_${BAK_DATE}.$EXT_COMPRESS
# echo "service -> \"barrel\" name: $FILENAME_SERVICE_BARREL"
# echo "cloud -> barrel CMD: $FILENAME_SERVICE_BARREL ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL}"
#sudo tar jcvf $FILENAME_SERVICE_BARREL ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL}
7z a $FILENAME_SERVICE_BARREL ${CLOUD_HOME}/${CLOUD_PROJECT_BARREL}
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


