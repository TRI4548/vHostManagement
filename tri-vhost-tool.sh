#!/bin/bash

VHOST_DIR="/var/www/vhost"

clear

mkdir -p "$VHOST_DIR"
echo "--------------------------------------"
echo -e "\e[32m/var/www/vhost created.\e[0m"
echo "--------------------------------------"
echo ""

is_installed(){
	if dpkg -l | grep $1 &>/dev/null; then
        echo -e "\e[32m$1 is installed.\e[0m"
    else
        echo "$1 is NOT installed. Installing..."
        apt update -y
        apt install -y $1

        # Check again
        if dpkg -l | grep $1 &>/dev/null; then
            echo -e "\e[32m$1 is installed.\e[0m"
        else
            echo -e "\e[31mFailed to install $1.\e[0m"
            exit 1
        fi
    fi
}

reload_serv() {
	systemctl reload $1
	echo -e "\e[32mRestarted $1.\e[0m"
}

restart_serv() {
	systemctl restart $1
	echo -e "\e[32mRestarted $1.\e[0m"
}

LAMP_check() {
	echo ""
	echo "--------------------------------------"
	is_installed apache2
	echo ""
	is_installed mysql-server
	echo ""
	
    if php -v; then
	echo ""
        echo -e "\e[32mPHP is installed.\e[0m"
	echo ""
    else
	echo ""
        echo "PHP is NOT installed. Installing..."
        apt update -y
        apt install php libapache2-mod-php php-mysql -y

        # Check again
        if php -v; then
	    echo ""
            echo -e "\e[32mPHP is installed.\e[0m"
	    echo ""
        else
	    echo ""
            echo -e "\e[31mFailed to install PHP.\e[0m"
            exit 1
        fi
    fi
	echo ""
    if wp --info; then
	echo ""
	echo -e "\e[32mwp-cli is installed.\e[0m"
	echo ""
    else
	echo ""
	echo -e "\e[33mwp-cli is not installed. Installing...\e[0m"
	apt install curl -y
	curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x wp-cli.phar
	sudo mv wp-cli.phar /usr/local/bin/wp

	#Check again
	if wp --info; then
	    echo ""
	    echo -e "\e[32mwp-cli installed.\e[0m"
	    echo ""
	else
	    echo ""
	    echo -e "\e[31mFailed to install wp-cli.\e[0m"
	    exit 1
	fi
	echo ""
    fi
	echo "--------------------------------------"
	echo ""
}

check_all_vhosts(){
	clear
	echo ""
    echo "Existing vHosts:"
	echo ""
    if [ "$(ls -A $VHOST_DIR)" ]; then
        ls "$VHOST_DIR"
    else
        echo -e "\e[33mNo vHost found!\e[0m"
    fi
    echo ""
}

check_vhost() {
	if [ -d "$VHOST_DIR/$domain" ]; then
		echo ""
		echo -e "\e[32mDomain $1 found!\e[0m"
	else
		echo ""
		echo -e "\e[33mDomain $1 not found!\e[0m"
	fi
	echo ""
}

create_vhost() {
  check_all_vhosts
  APACHE_LOG_DIR="/var/log/apache2"
  read -p "Enter one/multiple domain name: " -a domains
  for domain in "${domains[@]}"; do
    echo ""
    echo "Creating vhost for domain: $domain"
	
    # Cac thao tac cau hinh thuc hien o day
	
    DOC_ROOT="$VHOST_DIR/$domain/public_html"
    CONF_FILE="/etc/apache2/sites-available/$domain.conf"

	if [ -d "$VHOST_DIR/$domain/" ]; then
		echo ""
		echo "Domain exist. Skipping..."
		continue
	else
		echo ""
		echo "Creating $domain with docroot $DOC_ROOT"
		mkdir -p $DOC_ROOT
		echo "Configuration vhost location: $CONF_FILE"
		mkdir -p CONF_FILE
		sudo bash -c "cat > \"$CONF_FILE\" <<EOF
<VirtualHost *:80>
    ServerAdmin admin@$domain
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $DOC_ROOT

    <Directory $DOC_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF"

		echo "Activing site..."
		sudo a2ensite "$domain.conf"
		echo ""
		echo -e "\e[32m$domain successfully created ! \e[0m"
		echo ""
	fi
  done

  reload_serv apache2
}

del_vhost() {
	check_all_vhosts
	read -p "Enter domains you want to delete: " -a domains
	for domain in "${domains[@]}"; do
		echo "Deleting $domain ..."

		if [ ! -d "$VHOST_DIR/$domain/" ]; then
			echo -e "\e[33mDomain doesn't exist. Skipping...\e[0m"
		else
			sudo a2dissite "$domain.conf"
			rm -rf "$VHOST_DIR/$domain"
			rm -rf "/etc/apache2/sites-available/$domain.conf"
			echo ""
			echo -e "\e[32m$domain deleted!\e[0m"
		fi
	done

	reload_serv apache2
}

APACHE_CONF_DIR="/etc/apache2/sites-available"

rename_vhost() {
	check_all_vhosts
	read -p "Enter domain you want to change: " old_domain
	if ! check_vhost "$old_domain"; then
		echo -e "\e[33m$old_domain not exist, skipping...\e[0m"
		return
	else
		read -p "Enter new domain name: " new_domain
		if check_vhost $new_domain; then
			echo -e "\e[33m$new_domain exist, skipping...\e[0m"
		else
			a2dissite $old_domain.conf
			mv "$VHOST_DIR/$old_domain" "$VHOST_DIR/$new_domain"
			echo "Changed $old_domain to $new_domain"
			echo ""
			mv $APACHE_CONF_DIR/$old_domain.conf $APACHE_CONF_DIR/$new_domain.conf
			echo "Changed $old_domain config file to $new_domain config file"
			echo ""
			sed -i "s/$old_domain/$new_domain/g" $APACHE_CONF_DIR/$new_domain.conf
			echo "Already 'sed' !"
			echo ""
			a2ensite $new_domain.conf
			echo "Enabled $new_domain"
			echo ""
			echo -e "\e[32mSuccessfully change $old_domain to $new_domain \e[0m"
			echo ""
		fi
		reload_serv apache2
	fi
}

is_disabled() {
	suffix=".suspend"
	if [[ "$domain" == *"$suffix" ]]; then
		echo "$domain is suspend"
		return 0
	else
		echo "$domain is active"
		return 1
	fi
}

enable_site() {
	check_all_vhosts
	read -p "Enter one/multiple domain name want to active: " -a domains
	for domain in "${domains[@]}"; do
		if [ -d "${VHOST_DIR}/${domain}.suspend" ] &>/dev/null; then
			mv "${VHOST_DIR}/${domain}.suspend" "${VHOST_DIR}/${domain}"
			a2ensite "$domain.conf"
			echo -e "\e[32mEnabled site $domain\e[0m"
			echo ""
		elif check_vhost "$domain"; then
			echo -e "\e[32m$domain already active.\e[0m"
		else
			echo -e "\e[33mSite not found!\e[0m"
			echo ""
		fi
	done

	reload_serv apache2
}

disable_site() {
	check_all_vhosts
	read -p "Enter one/multiple domain name want to disable: " -a domains
	for domain in "${domains[@]}"; do
		if [ -d "${VHOST_DIR}/${domain}.suspend" ] &>/dev/null; then
			echo -e "\e[32m$domain already disabled.\e[0m"
		elif check_vhost "$domain"; then
			a2dissite "$domain.conf"
                        mv "${VHOST_DIR}/${domain}" "${VHOST_DIR}/${domain}.suspend"
                        echo -e "\e[32mDisabled site $domain\e[0m"
		else
			echo -e "\e[33mSite not found!\e[0m"
		fi
	done
	reload_serv apache2
}

# This function Tri is still developing T.T
check_mysql_installation() {
	echo ""
	read -s -r -p "Enter mysql root password: " input_root_pw
	if [[ -z "$input_root_pw" ]]; then
		echo "Blank password, checking mysql_secure_installion"
		if mysql -u root -e "SELECT 1;" &>/dev/null; then
			echo "You have not setup mysql_secure_installion, now do it"
			mysql_secure_installation
			read -s -r -p "Re-enter password you have set up: " setup_mysql_pw
			echo "$setup_mysql_pw"
		else
			echo "Wrong password, exiting..."
		fi
	elif mysql -u root -p "$input_root_pw" -e "SELECT 1;" &>/dev/null; then
		echo "Correct password, go to setting WordPress"
	else
		echo "Wrong password, try again. Exiting..."
		return
	fi
}

install_wordpress() {
	RANDOM_STRING=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
	RANDOM_FIVE_CHAR=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 5)
	check_all_vhosts
	read -p "Which vHost you want to install WordPress?: " domain
	if check_vhost "$domain" && ! is_disabled "$domain"; then
		if [ -z "$(ls -A $VHOST_DIR/$domain/public_html)" ]; then
			echo -e "\e[32m$domain exist and directory is empty, ready to install WordPress\e[0m"

			MYSQL_CMD="mysql -u root -e"
			DB_NAME="db_$domain_$RANDOM_FIVE_CHAR"
			DB_USER="user_$domain_$RANDOM_FIVE_CHAR"
			DB_PASS="$RANDOM_STRING"
			TABLE_PREFIX="$DB_NAME"
			$MYSQL_CMD "CREATE DATABASE $DB_NAME;"
			$MYSQL_CMD "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
			$MYSQL_CMD "GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost';"
			$MYSQL_CMD "FLUSH PRIVILEGES;"
			cat <<EOF >> "$VHOST_DIR/$domain/creds.txt"
Database:
Name: $DB_NAME
User: $DB_USER
Pass: $DB_PASS
EOF
			echo ""
			read -p "Enter username for WordPress's site: " admin_user
			read -s -r -p "Enter password for WordPress's site: " admin_password
			cd "$VHOST_DIR/$domain/public_html/"
			wp core download --allow-root
			cp "$VHOST_DIR/$domain/public_html/wp-config-sample.php" "$VHOST_DIR/$domain/public_html/wp-config.php"
			sed -i "s/database_name_here/$DB_NAME/g" "$VHOST_DIR/$domain/public_html/wp-config.php"
			sed -i "s/username_here/$DB_USER/g" "$VHOST_DIR/$domain/public_html/wp-config.php"
			sed -i "s/password_here/$DB_PASS/g" "$VHOST_DIR/$domain/public_html/wp-config.php"
			sed -i "s/table_prefix = 'wp_';/table_prefix = '$TABLE_PREFIX';/g" "$VHOST_DIR/$domain/public_html/wp-config.php"
			echo ""
			echo "wp-config.php modified!!!"
			echo "Installing WordPress..."
			wp core install --url=$domain --title=Example --admin_user=$admin_user --admin_password=$admin_password --admin_email=admin@$domain --allow-root

			echo ""
			echo -e "\e[32mWebsite: http://$domain\e[0m"
			echo -e "\e[32mYou can access http://$domain/wp-admin for management\e[0m"
			echo "Username: $admin_user"
			echo "Password: Your chosen password!"
			echo -e "\e[32mDatabase creds save at $VHOST_DIR/$domain/creds.txt\e[0m"

		else
			echo ""
			echo -e "\e[33m$domain exist but directory is not empty, check again and make it empty before install\e[0m"
		fi
	else
		echo ""
		echo -e "\e[33m$domain is not exist or suspended, skipping...\e[0m"
	fi

}

main(){
    while true; do
    echo ""
    echo "==================== vHOST MANAGER ===================="
    echo "1. View existing vHosts"
    echo "2. Create new vHosts"
    echo "3. Delete vHosts"
    echo "4. Rename a vHost"
    echo "5. Enable vHosts"
    echo "6. Disable vHosts"
    echo "7. Install WordPress for vHost"
    echo "0. Exit"
    echo "======================================================="
    echo ""
    read -p "Choose an option: " OPTION

		case $OPTION in
			1)
				check_all_vhosts
				;;
			2)
				create_vhost
				;;
			3)
				del_vhost
				;;
			4)
				rename_vhost
				;;
			5)
				enable_site
				;;
			6)
				disable_site
				;;
			7)
#				check_mysql_installation
				install_wordpress
				;;
			0)
				echo ""
				echo -e "\e[32mBye!\e[0m"
				echo ""
				break
				;;
			*)
				echo -e "\e[33mInvalid option!\e[0m"
				;;
		esac
	done
}

LAMP_check
main
