#!/bin/bash

INIT="${INIT_PROJECT}"
TEMP_DIR="/app"
APPLICATION_DIR="/var/www/html"
BACKUP_URL="${BACKUP_URL}"
REPO_URL="${REPO_URL}";
BITRIX_SETUP="https://www.dropbox.com/s/94y1sjjtdnwb0to/restore.php?dl=0"

#check http status of remote file
function destinationExists(){
   if [[ `wget -S --spider $1  2>&1 | grep 'HTTP/1.1 200 OK'` ]];
    then echo "true";
    else echo "false";
  fi
}

#get a file size of remote file in MB
function getFileSize() {
  FILE_SIZE=`wget -S --spider $1 2>&1 | awk '/Content-Length/ { print $2 }'`;
  if [[ ${FILE_SIZE} > 0 ]];
    then echo $((${FILE_SIZE} / 1024 / 1024));
    else echo "0";
  fi
}

#clean temp dir
rm -rf ${TEMP_DIR}/*

# Bitrix not installed
if [ ! -d "${APPLICATION_DIR}/bitrix" ]; then
  #clean application dir
  rm -rf ${APPLICATION_DIR}/*

  EXISTS=true
  COUNTER=0

# Download
  while [ ${EXISTS} = true ]
       do
           URL=${BACKUP_URL}
           if (( ${COUNTER} > 0 )); then
               URL+=".${COUNTER}"
           fi

           EXISTS=$(destinationExists "${URL}")
           FILE_SIZE=$(getFileSize "${URL}");

           if (( ${FILE_SIZE} < 10 ));
              then EXISTS=false;
           fi

           if [ ${EXISTS} = true ];
              then wget ${URL} -P ${TEMP_DIR}
           fi

           let COUNTER=COUNTER+1
  done
        # Full archive name without path
        ARCHIVE="${BACKUP_URL##*/}"
        # Archive name without .tar.gz
        ARCHIVE_NAME="${ARCHIVE::-7}"

        cat ${TEMP_DIR}/${ARCHIVE}* > ${TEMP_DIR}/archive.tar.gz
        rm -rf ${TEMP_DIR}/${ARCHIVE}*
        # Extract
        tar -xzf ${TEMP_DIR}/archive.tar.gz -C ${TEMP_DIR}
        # Delete archive
        rm ${TEMP_DIR}/archive.tar.gz
        # Restore project from archive
        if [ ${INIT} = true ];
            then
              cp -R ${TEMP_DIR}/* ${APPLICATION_DIR}
              wget ${BITRIX_SETUP} -O ${APPLICATION_DIR}/restore.php
        else
            # Copy database file to root folder
            if [ -f "${TEMP_DIR}/bitrix/backup/${ARCHIVE_NAME}.sql" ];
                then mv ${TEMP_DIR}/bitrix/backup/${ARCHIVE_NAME}.sql ${TEMP_DIR}/bitrix.sql
            fi

            if [ -f "${TEMP_DIR}/bitrix/backup/${ARCHIVE_NAME}_after_connect.sql" ];
                then mv ${TEMP_DIR}/bitrix/backup/${ARCHIVE_NAME}_after_connect.sql ${TEMP_DIR}/bitrix_after_connect.sql
            fi

            rm -rf ${APPLICATION_DIR}/
            git clone ${REPO_URL} ${APPLICATION_DIR}
            cp -R ${TEMP_DIR}/bitrix ${APPLICATION_DIR}
            cp ${TEMP_DIR}/bitrix.sql ${APPLICATION_DIR}/bitrix.sql
            cp ${TEMP_DIR}/bitrix_after_connect.sql ${APPLICATION_DIR}/bitrix_after_connect.sql
        fi
        #clean temp dir
        rm -rf ${TEMP_DIR}/*
fi

# Run PHP-FPM
php-fpm
