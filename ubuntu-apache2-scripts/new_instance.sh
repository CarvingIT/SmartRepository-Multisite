#!/bin/bash

if [ "$#" != "2" ]; then
    echo "You must provide two arguments - instance-identifier and email-address of the administator."
	echo "Sample usage - $ sudo new_instance.sh mycompanyname myemail@mydomain.com"
	exit
else
    echo "Creating a new instance."
fi

source config.sh
identifier=$1

## create database and a db user
output=$(mysql -e "create database $identifier; grant all privileges on $identifier.* to '$identifer'@'localhost' identified by '${identifier}123'" 2>&1)

if [ $? != 0 ]; then
	echo "!!!!!! ERROR !!!!!!"
	echo $output
	echo "Aborting the execution"
	exit
fi

#echo $identifier.$domain

## create a virtual host file

vhost="<VirtualHost *:80>
ServerName $identifier.$domain
ServerAdmin $webmaster_email
DocumentRoot /var/www/html/smart-repository/public
ErrorLog \${APACHE_LOG_DIR}/$identifier-error.log
CustomLog \${APACHE_LOG_DIR}/$identifier-access.log combined
        ## env
        SetEnv APP_NAME \"$identifier\" 
        SetEnv APP_DEBUG false
        SetEnv APP_URL http://$identifier.$domain
        SetEnv APP_DOMAIN $identifier.$domain
        SetEnv DB_CONNECTION mysql
        SetEnv DB_HOST 127.0.0.1
        SetEnv DB_PORT 3306
        SetEnv DB_DATABASE $identifier
        SetEnv DB_USERNAME $identifier
        SetEnv DB_PASSWORD ${identifier}123
        SetEnv BROADCAST_DRIVER log
        SetEnv CACHE_DRIVER file
        SetEnv QUEUE_CONNECTION sync
        SetEnv SESSION_DRIVER file
        SetEnv SESSION_LIFETIME 120
        #SetEnv MAIL_DRIVER smtp
        #SetEnv MAIL_HOST smtp.sendgrid.net
        #SetEnv MAIL_PORT 587
        #SetEnv MAIL_USERNAME apikey
        #SetEnv MAIL_PASSWORD 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
        #SetEnv MAIL_ENCRYPTION tls
        #SetEnv MAIL_FROM_ADDRESS info@carvingit.com
        #SetEnv MAIL_FROM_NAME \"Smart Repository\"
</VirtualHost>
"
## VirtualHost configuration
echo "$vhost" > /etc/apache2/sites-available/$identifier.conf
echo "Vhost configuration created."
cd /etc/apache2/sites-enabled
ln -s ../sites-available/$identifier.conf
cd

## create environment
mkdir -p /etc/apache2/SR-environments

env="
export APP_NAME=\"$identifier\"
export APP_ENV=prod
export APP_KEY=base64:SxJVboZ2Umgn+CmdKZUrcLB+TOmw56WknnZZrVkEMTo=
export APP_CYPHER=MjAyMi0xMi0zMQ==
export APP_DEBUG=false
export LOCALE=en
export LOG_CHANNEL=stack
export DB_CONNECTION=mysql
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_DATABASE=$identifier
export DB_USERNAME=$identifier
export DB_PASSWORD=${identifier}123
"

echo "$env" > /etc/apache2/SR-environments/$identifier.env
VHOST_ENV=/etc/apache2/SR-environments/$identifier.env
echo "Using this environment - $VHOST_ENV"
cd /var/www/html/smart-repository
echo "Creating schema and seeding the new DB"
source $VHOST_ENV
php artisan migrate:fresh --seed

## create an administrator
php artisan SR:MakeAdmin $2
