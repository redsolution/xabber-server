#!/bin/bash
ERROR_TEXT=$(tput setaf 1)
SUCCESS_TEXT=$(tput setaf 2)
NORMAL_TEXT=$(tput setaf 255)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
UNDER=$(tput smul)
NOUNDER=$(tput rmul)

userexecutor=$( whoami )
dirowner=''
system=$( uname -m )
DEFGROUP=$( id -gn )
XABBERUSER='xabberserver'
XABBERGROUP='xabberserver'
GROUP=''
SUDO=''
installpath=''
systemuser=''
DOMAIN=''
EMAIL=''
DBPASS=''
DBUSER='xabber_server_user'
DB='xabber_server_db'
LOG='/dev/null'
XABBER=''
check=0
installation_path=''
final_installation_path=''
new_ui_version=''
new_xmpp_version=''
new_xabber_web_version=''
current_ui_version=''
current_xmpp_version=''
current_xabber_web_version=''
db_migrations='db_migration'
user=''
group=''

function restart_server() {
echo "Reloading systemctl"
sudo systemctl daemon-reload
sudo systemctl start xabberserver.service
}

function upgrade_configs() {
echo "Updating system files to new"
mkdir -m 755 /etc/xabber/
EXP00="s#INSTALL_PATH#$final_installation_path#g"
EXP01="s#USER#$user#g"
EXP02="s#GROUP#'$group'#g"
sh -c "sed -e $EXP00 <$final_installation_path/xabberserver.service0 >$final_installation_path/xabberserver.service1"
sh -c "sed -e $EXP01 <$final_installation_path/xabberserver.service1 >$final_installation_path/xabberserver.service"
sh -c "sed -e $EXP02 <$final_installation_path/xabberserver.service >/etc/systemd/system/xabberserver.service"
sh -c "sed -e $EXP00 <$final_installation_path/xabber_server.ini0 >/etc/xabber/xabber_server.ini"
rm $final_installation_path/xabberserver.service
rm $final_installation_path/xabberserver.service1
rm $final_installation_path/xabberserver.service0
rm $final_installation_path/xabber_server.ini0
rm $final_installation_path/setup.sh
chmod 755 /etc/xabber/xabber_server.ini
}

function full_upgrade_xmppserverui() {
  echo "Upgrade xmppserverui"
  cp $final_installation_path/xmppserverui/xmppserverui.sqlite3 $final_installation_path
  rm -fr $final_installation_path/xmppserverui
  cp -rp xmppserverui/ $final_installation_path
  $final_installation_path/xmppserverui/xabber-server migrate
  touch $final_installation_path/.installation_lock
}

function upgrade_xmpp() {
set +e
echo "Upgrade from " $current_xmpp_version " to " $new_xmpp_version
lib_path="$final_installation_path/lib"
echo $lib_path
if [ "$final_installation_path" != "" ]; then
if [ -d $lib_path ]; then
  echo "Deleting old files"
  rm -fr $final_installation_path/lib/*
  rm -fr $final_installation_path/bin/*
  rm -fr $final_installation_path/erts*
  rm -fr $final_installation_path/var/lib/ejabberd/*
  echo "Copy new files to " $final_installation_path
  cp -rp lib  $final_installation_path
  cp -rp etc  $final_installation_path
  cp -rp psql_lib $final_installation_path
  cp -rp erts* $final_installation_path
  cp -rp bin $final_installation_path
  chown -R $user:$group $final_installation_path
  #find $final_installation_path -type f -exec chmod 644 {};
  #find $final_installation_path -type d -exec chmod 755 {};
  #find $final_installation_path/xmppserverui -maxdepth 1 -type f -exec chmod 755 {};
  sql_migration
  search_in_config
fi
fi
}

function sql_migration() {
echo "Try to do SQL Migrations"
CONFIG_FILE="$final_installation_path/etc/ejabberd/ejabberd.yml"
if [ -f $CONFIG_FILE ]; then
sql_server=$(grep sql_server $CONFIG_FILE | awk '{print $2}' | sed -e 's/"//g')
sql_username=$(grep sql_username $CONFIG_FILE | awk '{print $2}' | sed -e 's/"//g')
sql_password=$(grep sql_password $CONFIG_FILE | awk '{print $2}' | sed -e 's/"//g')
sql_database=$(grep sql_database $CONFIG_FILE | awk '{print $2}' | sed -e 's/"//g')
PGPASSWORD=$sql_password $final_installation_path/psql -U $sql_username -d $sql_database -h $sql_server -c '\l' > /dev/null
  if [ $? -eq 0 ]; then
    migrations=$(ls $db_migrations)
    echo "Start database migration"
    for migration in $migrations; do
    ver=$(echo $migration | sed -e 's/.sql//g' )
    res2=$(echo $ver $current_xmpp_version | awk  '{if ($2 >= $1) {print 0} else if ($2 < $1){ print 1}}')
    if [ $res2 -eq 1 ]; then
      echo "Migration database to " $ver
      PGPASSWORD=$sql_password $final_installation_path/psql -U $sql_username -d $sql_database -h $sql_server -f $db_migrations/$migration
    fi
    done
  else
    "Cannot connect to database. Please do manual migration"
  fi

fi
}

function search_in_config() {
CONFIG_FILE="$final_installation_path/etc/ejabberd/ejabberd.yml"
if [ -f $CONFIG_FILE ]; then
conf_migrations=$(ls config_migrations)
for conf_migration in $conf_migrations; do
    ver=$(echo $conf_migration | sed -e 's/.sh//g' )
    res2=$(echo $ver $current_xmpp_version | awk  '{if ($2 >= $1) {print 0} else if ($2 < $1){ print 1}}')
    if [ $res2 -eq 1 ]; then
      echo "Migration config to " $ver
      bash config_migrations/$conf_migration $CONFIG_FILE $final_installation_path
    fi
done
else
   echo "No cofig"
   exit 1
fi
}

function full_update() {
upgrade_xmpp
upgrade_configs
full_upgrade_xmppserverui
restart_server
}


function full_update_ask() {
  answer5="emp"
  while [ "$answer5" != "" -o "$answer5" != "yes" -o "$answer5" != "no" -o "$answer5" != "n" -o "$answer5" != "y" -o "$answer5" != "Y" -o "$answer5" != "YES" -o "$answer5" != "N" -o "$answer5" != "NO" ]; do
  if [ "$answer5" = "yes" -o "$answer5" = "y" -o "$answer5" = "" -o "$answer5" = "Y" -o "$answer5" = "YES" ]; then
  	full_update
  	break
  elif [ "$answer5" = "no" -o "$answer5" = "n" -o "$answer5" == "N" -o "$answer5" == "NO" ]; then
  	exit 1
  	break
  else
  	echo "Do you want to continue? [Y/n]"
  	read answer5
  fi
  done
}

function update_ask() {
  answer4="emp"
  while [ "$answer4" != "" -o "$answer4" != "yes" -o "$answer4" != "no" -o "$answer4" != "n" -o "$answer4" != "y" -o "$answer4" != "Y" -o "$answer4" != "YES" -o "$answer4" != "N" -o "$answer4" != "NO" ]; do
  if [ "$answer4" = "yes" -o "$answer4" = "y" -o "$answer4" = "" -o "$answer4" = "Y" -o "$answer4" = "YES" ]; then
  	update_server
  	break
  elif [ "$answer4" = "no" -o "$answer4" = "n" -o "$answer4" == "N" -o "$answer4" == "NO" ]; then
  	exit 1
  	break
  else
    echo "Update can delete your previous cached information in mnesia tables."
    echo "Your server will be stoped during update"
  	echo "Do you want to continue? [Y/n]"
  	read answer4
  fi
  done
}

function search_versions() {
final_installation_path=$installation_path
lastsymbol=${final_installation_path: -1}
if [ "$lastsymbol" = "/" ]; then
  final_installation_path=${final_installation_path%?}
fi
echo $final_installation_path
echo "Searching versions"
versions="$(find $installation_path -name version -type f)"
if [ "$versions" != "" ]
then
for version in $versions; do
  xmpp_server=$(grep 'xabber-xmpp-server' $version)
  if [ "$xmpp_server" != "" ]; then
    new_xmpp_version=$(grep PROJECT_VERSION version | awk '{print $3}')
    current_xmpp_version=$(grep PROJECT_VERSION $version | awk '{print $3}')
    echo "Found server version " $current_xmpp_version
    res=$(echo $new_xmpp_version $current_xmpp_version | awk  '{if ($2 >= $1) {print 0} else if ($2 < $1){ print 1}}')
    if [ $res -eq 1 ]; then
     upgrade_xmpp
     restart_server
    fi
  fi
done
else
    echo "No readable versions were found. We will made full update of server."
    echo "It will rewrite your configuration files"
    full_update_ask
fi
}

function update_server() {
echo "Start updating server"
SYSTEMD_FILE="/etc/systemd/system/xabberserver.service"
if [ -f $SYSTEMD_FILE ]
then
  sudo systemctl stop xabberserver.service
  user=$(grep User /etc/systemd/system/xabberserver.service | sed -e 's/=/ /g' | awk '{print $2}')
  group=$(grep Group /etc/systemd/system/xabberserver.service | sed -e 's/=/ /g' | awk '{print $2}')
  installation_path0= grep PIDFile $SYSTEMD_FILE | sed -e "s/=/ /g" | awk {'print $2'} | sed -e "s/xabber_server.pid//g" > /dev/null
  installation_path=$(grep PIDFile $SYSTEMD_FILE | sed -e "s/=/ /g" | awk {'print $2'} | sed -e "s/xabber_server.pid//g")
  if [ -f $installation_path0 ]
  then
    search_versions
  fi
else
  installation_path=""
  echo "No previous installed Xabber Server was found"
  echo "Please ensure what your server is stopped and continue"
  echo -n "Enter your path to the Xabber Server. Please, enter absolute path. [ /opt/xabberserver/xabberserver/ ] : "
  read installpath
  if [ -f $installation_path ]
  then
    search_versions
  else
    echo "Wrong path."
    install_regime
  fi
fi
}

function create_self_signed_cert() {
apt-get install openssl >> $LOG
openssl req -new -x509 -newkey rsa:4096 -days 3650 -nodes -out $installdir/ser.pem -keyout $installdir/ser.pem -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=$DOMAIN" >> $LOG
}

function create_predifined() {
PRECONFIG="$installdir/xmppserverui/predefined_config.json"
echo "{" > $PRECONFIG
echo "  \"virtual_host\": \"$DOMAIN\"," >> $PRECONFIG
echo "  \"http_host\": \"$XABBER\"," >> $PRECONFIG
echo "  \"db_host\": \"localhost\"," >> $PRECONFIG
echo "  \"db_name\": \"$DB\"," >> $PRECONFIG
echo "  \"db_user\": \"$DBUSER\"," >> $PRECONFIG
echo "  \"db_password\": \"$DBPASS\"" >> $PRECONFIG
echo "}" >> $PRECONFIG
chmod 755 $PRECONFIG
chown $systemuser:"$GROUP" $PRECONFIG
}

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="OK"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo -ne ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

function printTable()
{
    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                # Add Header Or Body

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

function removeEmptyLines()
{
    local -r content="${1}"

    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString()
{
    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString()
{
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString()
{
    local -r string="${1}"

    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}


function dns_instructions() {
echo "${UNDER}Please ensure, that you configured your DNS correctly:${NOUNDER}"
echo ""
echo "To make XMPP work on your server, you need to set up SRV records for domain $DOMAIN. It will allow XMPP clients to correctly find the location of your server using Domain Name System (DNS). You need to add several types of DNS records to make things work"
echo ""
echo "A record for subdomain $DOMAIN to make server management panel available from the Internet on this address"
echo ""
echo "SRV records to help XMPP clients and servers find your server"
echo ""
echo "${UNDER}A Record${NOUNDER}"
echo ""
for item in ${IPNOW[*]}
do
printf "%20s	IN	A	%s\n" $XABBER $item
done
echo ""
echo "${UNDER}SRV Records${NOUNDER}"
echo ""
printTable ',' "Service,Protocol,Priority,Weight,Port,Target,TTL (seconds)\n_xmpp-client,TCP,10,5,5222,$XABBER,Default\n_xmpp-server,TCP,10,5,5269,$XABBER,Default"
exit 2
}


function check_srv() {
XABBER="xabber.$DOMAIN"
IPNOW=$( ./dig +short myip.opendns.com @resolver1.opendns.com )
AREC="A record for $XABBER"
SRVClient="SRV record for client"
SRVServer="SRV record for server"

if [[ $IPNOW == "" ]]; then
IPNOW=$( hostname -I )
fi

echo ""
start_spinner "A record for $XABBER"
SERVERIP=$( ./dig +short $XABBER )
if [[ " ${IPNOW[@]} " =~ " $SERVERIP " && $SERVERIP != "" ]]; then
stop_spinner 0
else
stop_spinner 1
check=1
fi

start_spinner "SRV record for client"
SRV_CLIENT=$( ./dig +short SRV _xmpp-client._tcp.$DOMAIN | awk '{print $4}' )
if [[ " ${SRV_CLIENT[@]} " =~ " $XABBER. " && $XABBER != "" ]]; then
stop_spinner 0
else
stop_spinner 1
check=1
fi

start_spinner "SRV record for server"
SRV_SERVER=$( ./dig +short SRV _xmpp-server._tcp.$DOMAIN | awk '{print $4}' )
if [[ " ${SRV_SERVER[@]} " =~ " $XABBER. " && $XABBER != "" ]]; then
stop_spinner 0
else
stop_spinner 1
check=1
fi
echo ""
}

function create_db_user() {
apt-get install -y sudo
start_spinner "Creating user for database"
DBPASS=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 )
sudo -i -u postgres psql -c "create role $DBUSER with password '$DBPASS' LOGIN;" >> $LOG
sudo -i -u postgres psql -c "create database $DB owner $DBUSER;" >> $LOG
stop_spinner $?
}

function default_install_database() {
start_spinner "Installing PostgreSQL"
apt-get install -y sudo postgresql postgresql-contrib >> $LOG
DBPASS=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 )
sudo -i -u postgres psql -c "create role $DBUSER with password '$DBPASS' LOGIN;" >> $LOG
sudo -i -u postgres psql -c "create database $DB owner $DBUSER;" >> $LOG
stop_spinner $?
}

function ask_to_install_database() {
set +e
dpkg -l | awk '{print $2}' | grep -e '^postgresql$' && create_db_user ||  default_install_database
set -e
}


function install_cert() {
start_spinner "Installing certificates"
rm $installdir/certs/server.pem >> $LOG
ln -s /etc/letsencrypt/live/$XABBER/* $installdir/certs/ >> $LOG
find /etc/letsencrypt/ -type d -exec chmod 755 {} \; >> $LOG
find /etc/letsencrypt/archive/ -type f -exec chmod 644 {} \; >> $LOG
chown -R $systemuser:"$GROUP" $installdir/certs/ >> $LOG
stop_spinner $?
}

function get_cert() {
start_spinner "Installing certbot"
apt-get install -y certbot python-certbot-apache  >> $LOG
stop_spinner $?
[ -d /var/lib/letsencrypt ] && chmod 755 /var/lib/letsencrypt || mkdir -m 755 /var/lib/letsencrypt
certbot certonly --apache --agree-tos -m $EMAIL -d $XABBER
}

function configure_apache() {
start_spinner "Installing Apache"
apt-get install -y apache2
a2enmod headers proxy proxy_http ssl proxy_wstunnel rewrite
a2dissite 000-default.conf
EXP="s#DOMAIN#$XABBER#g"
sh -c "sed -e $EXP <001-site-default.conf >/etc/apache2/sites-available/001-site-default.conf"
cp well-known.apache /etc/apache2/conf-available/letsencrypt.conf
a2ensite 001-site-default
a2enconf letsencrypt.conf
systemctl restart apache2
stop_spinner $?
}

function configure_ssl_apache() {
  start_spinner "Configuring SSL for Apache"
  EXP="s#DOMAIN#$XABBER#g"
  sh -c "sed -e $EXP <001-site.conf >/etc/apache2/sites-available/001-site.conf"
  sh -c "sed -e $EXP <001-site-ssl.conf >/etc/apache2/sites-available/001-site-ssl.conf"
  a2dissite 001-site-default.conf
  a2ensite 001-site
  a2ensite 001-site-ssl.conf
  systemctl restart apache2
  stop_spinner $?
}

function get_email() {

while [ "$EMAIL" = "" ]; do
  if [ -n "$EMAIL" ]; then
    echo ""
  else
    printf "Enter your email for important account notifications from Letsencrypt (e.g. ${BOLD}user@domain.com${NORMAL}): "
    read EMAIL
  fi
done

regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

if [[ ! $EMAIL =~ $regex ]] ; then
echo "$EMAIL is not valid"
exit 2
fi
}

function get_info_and_decide() {
start_spinner "Check system for necessary packages"
apt-get update >> $LOG
apt-get install -y bsdmainutils apt-utils >> $LOG
stop_spinner $?
while [ "$DOMAIN" = "" ]; do
  if [ -n "$DOMAIN" ]; then
    echo "Check $DOMAIN"
  else
    echo ""
    printf "Enter your domain for Xabber Server (e.g. ${BOLD}example.com${NORMAL} ): "
    read DOMAIN
  fi
done
check_srv
if [[ $check -eq 0 ]]; then
get_email
quick_install
else
dns_instructions
fi

}

function quick_install() {
installpath='/opt/xabberserver'
systemuser=$XABBERUSER
GROUP=$XABBERGROUP

mkdir -p $installpath
configure_apache >> $LOG
get_cert
configure_ssl_apache >> $LOG
ask_to_install_database
copy_to_directory
LOG="$installdir/installation.log"
touch $LOG
chown -R $systemuser:"$GROUP" $LOG
chmod 755 $LOG
install_cert
create_predifined
systemctl enable xabberserver.service
systemctl start xabberserver.service
printf "To continue installation process, open https://%s\n" $XABBER
}

function createuserfunc()
{
user=''
password=''
superuser=''
superpass=''
while [ "$user" = "" -o "$password" = "" -o "$superuser" = "" -o "$superpass" = ""]; do

  if [ -n "$superuser" ]; then
    echo "User set to $user"
  else
    echo -n "Enter superuser to connect to postgresql (e.g. postgres): "
    read user
  fi

  if [ -n "$superpass" ]; then
    echo "Password set"
  else
    echo -n "Enter password for superuser to connect to postgresql (e.g. qwerty12345): "
    read -s password
    echo ""
  fi

  if [ -n "$user" ]; then
    echo "User set to $user"
  else
    echo -n "Enter username for a new user (e.g. postgresuser): "
    read user
  fi

  if [ -n "$password" ]; then
    echo "Password set"
  else
    echo -n "Enter password for a new user (e.g. qwerty12345): "
    read -s password
    echo ""
  fi

done
cmd="DO \$body\$ BEGIN IF NOT EXISTS (SELECT FROM   pg_catalog.pg_user WHERE  usename = '$user') THEN CREATE ROLE $user LOGIN PASSWORD '$password'; END IF;END \$body\$;"


echo "Connecting to database"
PGPASSWORD=$superpass $installpath/psql -U $superuser -d $base -h $host -c '\l' >/dev/null 2>/dev/null
if [ $? -eq 0 ]; then

PGPASSWORD=$superpass $installpath/psql -U $superuser -h $host -c "$cmd"
PGPASSWORD=$superpass $installpath/psql -U $superuser -h $host -c "CREATE DATABASE $base OWNER $user;"
PGPASSWORD=$password $installpath/psql -U $user -d $base -h $host -f pg.sql
else
echo "Can't connect to database. Maybe you enter wrong data. Try one more time"
createuserfunc
fi
}

function auto()
{
host=''
user=''
password=''
base=''
while [ "$host" = "" -o "$base" = "" ]; do

  if [ -n "$host" ]; then
    echo "Host set to $host"
  else
    echo -n "Enter host to connect to postgresql (e.g. localhost): "
    read host
  fi

  if [ -n "$base" ]; then
    echo "Database set to $base"
  else
    echo -n "Enter database to connect to postgresql (e.g. mydatabase): "
    read base
  fi

  if [ -n "$user" ]; then
    echo "User set to $user"
  else
    echo -n "Enter username to connect to postgresql (e.g. postgresuser): "
    read user
  fi

  if [ -n "$password" ]; then
    echo "Password set"
  else
    echo -n "Enter password to connect to postgresql (e.g. qwerty12345): "
    read -s password
    echo ""
  fi

done


echo "Connecting to database"
PGPASSWORD=$password $installpath/psql -U $user -d $base -h $host -c '\l'
if [ $? -eq 0 ]; then
    EXP1="s/SERVER/\"$host\"/g"
    EXP2="s/DATABASE/\"$base\"/g"
    EXP3="s/USERNAME/\"$user\"/g"
    EXP4="s/PASSWORD/\"$password\"/g"
    $SUDO sh -c "sed -e $EXP1 <$installpath/etc/ejabberd/ejabberd.yml.ORIG1 >$installpath/etc/ejabberd/ejabberd.yml.ORIG2"
    $SUDO sh -c "sed -e $EXP2 <$installpath/etc/ejabberd/ejabberd.yml.ORIG2 >$installpath/etc/ejabberd/ejabberd.yml.ORIG3"
    $SUDO sh -c "sed -e $EXP3 <$installpath/etc/ejabberd/ejabberd.yml.ORIG3 >$installpath/etc/ejabberd/ejabberd.yml.ORIG4"
    $SUDO sh -c "sed -e $EXP4 <$installpath/etc/ejabberd/ejabberd.yml.ORIG4 >$installpath/etc/ejabberd/ejabberd.yml"
    $SUDO rm -v $installpath/etc/ejabberd/ejabberd.yml.ORIG*
    PGPASSWORD=$password $installpath/psql -U $user -d $base -h $host -f pg.sql
else
echo "Can't connect to database. Maybe you enter wrong data"
createuserfunc
fi
}

function menu()
{
echo "Start database configuration. Choose next step"
echo "0) Exit installation"
echo "1) Script installation"
echo "2) Manual installation"
choice=''
echo -n "Make your choice : "
read choice
case $choice in
0) echo "Breaking installation"
exit 1;;
1) auto;;
2) echo "Use pg.sql in installation directory"
echo "psql -U user -d database -f /your/path/pg.sql"
;;
*) echo "Wrong selection"
menu
;;
esac
}

function console_install()
{
hostname=$( hostname )
echo -n "Enter your hostname (e.g. $hostname): "
read hostname
if [ "$hostname" = "" ]; then
hostname=$( hostname )
fi
echo "Hostname $hostname will be used as default host."

EXP="s/DEFAULT_HOSTNAME/\"$hostname\"/g"
$SUDO sh -c "sed -e $EXP <$installpath/etc/ejabberd/ejabberd.yml.ORIG0 >$installpath/etc/ejabberd/ejabberd.yml.ORIG1"

menu
echo "Installation finished"
}

function print_instructions()
{
 IP=$( hostname -I )
 HOSTS=$( hostname -f )
 CERT_FILE=$installdir/certs/server.pem
 echo "Welcome to Xabber server."
 for item in ${IP[*]}
 do
  if [ -f $CERT_FILE ]
  then
  printf "To continue installation process, open https://%s:8000\n" $item
  else
  printf "To continue installation process, open http://%s:8000\n" $item
  fi
 done
 for hst in ${HOSTS[*]}
 do
  if [ -f $CERT_FILE ]
  then
  printf "To continue installation process, open https://%s:8000\n" $hst
  else
  printf "To continue installation process, open http://%s:8000\n" $hst
  fi
 done
}


function web_install()
{

if [ -x $installdir/xmppserverui/xabber-server ]
then
 systemctl enable xabberserver.service
 systemctl start xabberserver.service
 print_instructions
else
 echo "You don't have execute permission. Please check your permissions."
 echo "namei -l $installdir"
fi
}

function installation_menu()
{
echo "Choose next step"
echo "0) Exit installation"
echo "1) Web installation"
echo "2) Console installation"
choice='0'
echo -n "Make your choice : "
read choice
case $choice in
0) echo "Breaking installation"
exit 1;;
1) web_install;;
2) console_install;;
*) echo "Wrong selection"
installation_menu
;;
esac
}

function expert_create_user()
{
answer0=''
answer=''
installpath="/opt"
echo -n "Enter your path for installation Please, enter absolute path. [ "$installpath/xabberserver" ] : "
read installpath
  lastsymbol=${installpath: -1}
if [ "$lastsymbol" = "/" ]; then
  installpath=${installpath%?}
fi
if [ "$installpath" = "" ]; then
  installpath="/opt/xabberserver"
fi

if [ ! -d "$installpath" ]; then
  echo -n "There is no such directory. Create a directory please. Do you want to create it? y/n "
  read answer
if [ "$answer" = "yes" -o "$answer" = "y" -o "$answer" = "" -o "$answer" = "Y" -o "$answer" = "YES" ]; then
  mkdir -p $installpath
fi
fi

echo -n "Create special user for xabberserver? y/n "
read answer0
if [ "$answer0" = "yes" -o "$answer0" = "y" -o "$answer0" = "" -o "$answer0" = "Y" -o "$answer0" = "YES" ]; then
  systemuser=$XABBERUSER
  echo -n "Please, enter user for xabberserver. [ $systemuser ] : "
  read systemuser

if [ "$systemuser" = "" ]; then
  systemuser=$XABBERUSER
fi

GROUP=$XABBERGROUP
  echo -n "Please, enter group for xabberserver. [ $GROUP ] : "
  read GROUP
if [ "$GROUP" = "" ]; then
  GROUP=$XABBERGROUP
fi

else
  systemuser=$USER
  GROUP=$DEFGROUP
fi
copy_to_directory
web_install
}

function install_regime()
{
echo "Select the appropriate installation type:"
echo "1) Quick ( ${BOLD}Use only on fresh installed Debian-based GNU/Linux system!${NORMAL} )"
echo "2) Advanced"
echo "3) Update Server"
echo "0) Exit"
choice=''
echo -n "Make your choice : "
read choice
case $choice in
0) echo "Breaking installation"
exit 1;;
1) get_info_and_decide;;
2) expert_create_user;;
3) update_ask;;
*) echo "Wrong selection"
install_regime
;;
esac
}

function copy_to_directory()
{
if ! id -u $systemuser > /dev/null 2>&1; then
  useradd -rU $systemuser -d $installpath -s /bin/bash
fi

if ! getent group "$GROUP" > /dev/null 2>&1; then
  groupadd $GROUP
fi
    installdir="$installpath/xabberserver"
    mkdir -m 755 -p $installdir
    f=$installdir
    while [[ $f != / ]]; do chmod 755 "$f"; f=$(dirname "$f"); done;
    start_spinner "Installing into $installdir."
    cp -rp * $installdir
    mkdir -m 755 $installdir/user_images
    mkdir -m 755 $installdir/certs
    mkdir -m 755 /etc/xabber/
    mv $installdir/server.pem $installdir/certs
    EXP00="s#INSTALL_PATH#$installdir#g"
    EXP01="s#USER#$systemuser#g"
    EXP02="s#GROUP#'$GROUP'#g"
    sh -c "sed -e $EXP00 <$installdir/xabberserver.service0 >$installdir/xabberserver.service1"
    sh -c "sed -e $EXP01 <$installdir/xabberserver.service1 >$installdir/xabberserver.service"
    sh -c "sed -e $EXP02 <$installdir/xabberserver.service >/etc/systemd/system/xabberserver.service"
    sh -c "sed -e $EXP00 <$installdir/xabber_server.ini0 >/etc/xabber/xabber_server.ini"
    rm $installdir/xabberserver.service
    rm $installdir/xabberserver.service1
    rm $installdir/xabberserver.service0
    rm $installdir/xabber_server.ini0
    rm $installdir/setup.sh
    chmod 755 $installdir/xmppserverui/xabber-server
    chmod 755 /etc/xabber/xabber_server.ini
    chown -R $systemuser:"$GROUP" $installpath
    stop_spinner $?
}

function install_in_home()
{
echo "Installation started"
    installpath=$HOME
    systemuser=$USER
    GROUP=$DEFGROUP
    installdir="$installpath/xabberserver"
    mkdir -m 755 -p $installdir
    echo "Installing into $installdir"
    cp -rp * $installdir
    mkdir $installdir/user_images
    mkdir $installdir/certs
    mv $installdir/server.pem $installdir/certs
    rm $installdir/xabberserver.service0
    rm $installdir/setup.sh
    chmod 755 $installdir/xmppserverui/service.sh
    chown -R $systemuser:"$GROUP" $installdir
    echo "To start xabberserver use:"
    echo "$installdir/xmppserverui/service.sh start"
}

if [[ !$system -eq "x86_64" ]]; then
  echo "Your system arch $system is not supported"
  exit 2
fi
cat xabber.text
set -e
if (( $EUID == 0 )); then
install_regime
else
answer3="emp"
while [ "$answer3" != "" -o "$answer3" != "yes" -o "$answer3" != "no" -o "$answer3" != "n" -o "$answer3" != "y" -o "$answer3" != "Y" -o "$answer3" != "YES" -o "$answer3" != "N" -o "$answer3" != "NO" ]; do
if [ "$answer3" = "yes" -o "$answer3" = "y" -o "$answer3" = "" -o "$answer3" = "Y" -o "$answer3" = "YES" ]; then
	install_in_home
	break
elif [ "$answer3" = "no" -o "$answer3" = "n" -o "$answer3" == "N" -o "$answer3" == "NO" ]; then
	exit 1
	break
else
	echo "Installation started without root privileges. Server will be installed in $HOME/xabberserver. Do you want to continue? [Y/n]"
	read answer3
fi
done

fi
