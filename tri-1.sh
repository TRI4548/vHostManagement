#!/bin/bash

VHOST_DIR="/var/www/vhost"

clear

mkdir -p "$VHOST_DIR"
echo "--------------------------------------"
echo "/var/www/vhost created"
echo "--------------------------------------"
echo ""

is_installed(){
	if dpkg -l | grep $1 &>/dev/null; then
        echo "$1 is installed."
    else
	    echo "$1 is NOT installed. Installing..."
        apt update
        apt install -y $1

        # Check again
        if dpkg -l | grep $1 &>/dev/null; then
            echo "$1 is installed."
        else
            echo "Failed to install $1."
            exit 1
        fi
    fi
}

restart_serv() {
	systemctl restart $1
	echo ""
	echo "Restarted $1"
}

LAMP_check() {
	echo ""
	echo "--------------------------------------"
	is_installed apache2
	is_installed mysql-server
	
    if php -v; then
        echo "PHP is installed."
    else
        echo "PHP is NOT installed. Installing..."
        apt update
        apt install php libapache2-mod-php php-mysql -y

        # Check again
        if php -v; then
            echo "PHP is installed."
        else
            echo "Failed to install PHP."
            exit 1
        fi
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
        echo "No vHost found!"
    fi
    echo ""
}

check_vhost() {
	if [ -d "$VHOST_DIR/$1" ]; then
		echo "Domain $1 found!"
		return 0
	else
		echo "Domain $1 not found!"
		return 1
	fi
	echo ""
}

create_vhost() {
  check_all_vhosts
  read -p "Enter one/multiple domain name: " -a domains
  for domain in "${domains[@]}"; do
    echo ""
    echo "Creating vhost for domain: $domain"
	
    # Cac thao tac cau hinh thuc hien o day
	
    DOC_ROOT="$VHOST_DIR/$domain/public_html"
    CONF_FILE="/etc/apache2/sites-available/$domain.conf"

	if [ -d "$VHOST_DIR/$domain/" ]; then
		echo "Domain exist. Skipping..."
		continue
	else
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

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF"

		echo "Activing site..."
		sudo a2ensite "$domain.conf"
	fi
  done
  
  restart_serv apache2
}

del_vhost() {
	clear
	echo "These are exist vHost you're having"
	echo ""
	check_all_vhosts
	read -p "Enter domains you want to delete: " -a domains
	for domain in "${domains[@]}"; do
		echo "Deleting $domain ..."
		
		if [ ! -d "$VHOST_DIR/$domain/" ]; then
			echo "Domain doesn't exist. Skipping..."
			return 1
		else
			sudo a2dissite "$domain.conf"
			rm -rf "$VHOST_DIR/$domain"
			rm -rf "/etc/apache2/sites-available/$domain.conf"
		fi
	done
	
	restart_serv apache2
}

APACHE_CONF_DIR="/etc/apache2/sites-available"

rename_vhost() {
	clear
	echo "These are exist vHost you're having"
	echo ""
	check_all_vhosts
	read -p "Enter domain you want to change: " old_domain
	if ! check_vhost "$old_domain"; then
		echo "$old_domain not exist, skipping..."
		return
	else
		read -p "Enter new domain name: " new_domain
		if check_vhost $new_domain; then
			# Cho nay co the upgrade thanh hoi lai thay vi skip
			echo "$new domain exist, skipping..."
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
		fi
		restart_serv apache2
	fi
}

enable_site() {
	read -p "Enter one/multiple domain name want to active: " -a domains
	for domain in "${domains[@]}"; do
		if check_vhost "$domain".suspend; then
			mv $VHOST_DIR/$domain.suspend $VHOST_DIR/$domain
			a2ensite $domain
			echo "Enabled site $1"
		else
			echo "Site not found!"
		fi
	done
	
	restart_serv apache2
}

disable_site() {
	read -p "Enter one/multiple domain name want to disable: " -a domains
	for domain in "${domains[@]}"; do
		if check_vhost $domain; then
			a2dissite $domain
			mv "$VHOST_DIR/$domain" "$VHOST_DIR/$domain".suspend
		echo "Disable site $domain"
		else
			echo "Site not found!"
		fi
	done
	
	restart_serv apache2
}

main(){
    while true; do
    echo ""
    echo "==================== VHOST MANAGER ===================="
    echo "1. View existing vHosts"
    echo "2. Create new vHosts"
    echo "3. Delete vHosts"
    echo "4. Rename a vHost"
    echo "5. Enable vHosts"
    echo "6. Disable vHosts"
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
			0)
				echo ""
				echo "Bye!"
				echo ""
				break
				;;
			*)
				echo "Invalid option!"
				;;
		esac
	done
}

LAMP_check
main
