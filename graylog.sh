#!/bin/bash

YELLOW="\033[0;33m"
noClr="\033[0m"
BLUE="\033[0;34m"

xms="-Xms"
xmx="-Xmx"
chr_g="g"

# Adding all repositories
function addRepo {
	# Adding MongoDB repo
	wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
	echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
	# Adding elasticsearch repo
	wget -q https://artifacts.elastic.co/GPG-KEY-elasticsearch -O myKey
	apt-key add myKey
	echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
	# Adding graylog repo
	wget https://packages.graylog2.org/repo/packages/graylog-4.0-repository_latest.deb
	chmod +x graylog-4.0-repository_latest.deb
	dpkg -i graylog-4.0-repository_latest.deb

	apt-get update

	rm graylog-4.0-repository_latest.deb
	rm myKey
}


function refreshRepo {
	apt-get update
	apt-get upgrade
}

function modInstaller {
	# Installing all modules
	# Install JDK
	sudo apt-get install apt-transport-https openjdk-8-jre-headless uuid-runtime pwgen
	# Install MongoDB
	apt-get install -y mongodb-org
	# Install elasticsearch
	apt-get install elasticsearch-oss

	# Deleting tmp files
}

function esCfg {
	# Configuring elasticsearch
	echo -e "\n${YELLOW}To configure ElasticSearch, we need to define cluster name."
	read -p "Enter cluster name for ElasticSearch (eg. graylog) : " cluster_name
	sed -i "18 i cluster.name: $cluster_name" /etc/elasticsearch/elasticsearch.yml
	echo -e "action.auto_create_index: false" >> /etc/elasticsearch/elasticsearch.yml
}

# Configuring ElasticSearch Java heap size
function heapCfgES {
	echo -e "\n${YELLOW}[NOTE] It is advisable to dedicate half of total RAM to define heap size for Java for elasticsearch. (Maximum 32GB). Default is currently set to 1GB."
	read -p "Please define Java heap size (enter value) : " heap_size
	echo -e "${noClr}"

	local heap_size_cfg_s="$xms$heap_size$chr_g"
	sed -i "s/-Xms1g/$heap_size_cfg_s/" /etc/elasticsearch/jvm.options

	local heap_size_cfg_x="$xmx$heap_size$chr_g"
	sed -i "s/-Xmx1g/$heap_size_cfg_x/" /etc/elasticsearch/jvm.options

}

function glInstaller {
	# Install Graylog
	apt-get install graylog-server
}

function glCfg {
	# Configuring Graylog
	sed '/password_secret/d' /etc/graylog/server/server.conf > tmpfile && mv tmpfile /etc/graylog/server/server.conf
	local pwd=$(pwgen -N 1 -s 96)
	sed -i "58 i password_secret = $pwd" /etc/graylog/server/server.conf
	echo -e "\n${YELLOW}Set Administrator password for Graylog web interface. This password cannot be changed through the web interface or API. This password will be stored as SHA256."
	read -p "Enter password: " adPass
	sed '/root_password_sha2/d' /etc/graylog/server/server.conf > tmpfile && mv tmpfile /etc/graylog/server/server.conf
	local sha256=$(echo -n $adPass | tr -d '\n' | sha256sum | cut -d" " -f1)
	sed -i "68 i root_password_sha2 = $sha256" /etc/graylog/server/server.conf
	sed '/root_timezone/d' /etc/graylog/server/server.conf > tmpfile && mv tmpfile /etc/graylog/server/server.conf
	echo -e "\n${YELLOW}[NOTE] Default timezone of the Admin user is set to UTC. If you wish to change it, see http://www.joda.org/joda-time/timezones.html for a list of valid timezones"
	read -p "Enter your timezone (d for default): " admTime
	if [[ $admTime == 'd' ]]
	then
		sed -i "76 i root_timezone = UTC" /etc/graylog/server/server.conf
	else
		sed -i "76 i root_timezone = $admTime" /etc/graylog/server/server.conf
	fi

	sed '/http_bind_address/d' /etc/graylog/server/server.conf > tmpfile && mv tmpfile /etc/graylog/server/server.conf
	local defIP=$(hostname -I)
	echo -e "\n${YELLOW}[NOTE] Current IP: $defIP\nWould you like to keep the default IP?"
	read -p "(y/n): " IPchoice
	if [[ $IPchoice == 'n' ]]
	then
		read -p "Enter new IP address: " newIP
		echo "IP: $newIP"
		srvIP=$(echo $newIP | tr -d ' ')
	elif [[ $IPchoice == 'y' ]]
	then
		echo "IP: $defIP"
		srvIP=$(echo $defIP | tr -d ' ')
	else
		echo -e "${noClr} Invalid choice. Exiting!"
	fi

	echo -e "\n${YELLOW}[NOTE] Default port: 9000.\nWould you like to keep the default port?"
	read -p "(y/n): " portChoice
	if [[ $portChoice == 'n' ]]
	then
		read -p "Enter new port number: " newPort
		echo "Your Graylog interface can be accessed on http://$srvIP:$newPort"
		sed -i "106 i http_bind_address = $srvIP:$newPort" /etc/graylog/server/server.conf
	elif [[ $portChoice == 'y' ]]
	then
		echo "Your Graylog interface can be accessed on http://$srvIP:9000"
		sed -i "106 i http_bind_address = $srvIP:9000" /etc/graylog/server/server.conf
	else
		echo -e "${noClr} Invalid choice. Exiting!"
	fi
}

# Configuring Graylog Java heap size
function heapCfgGL {
	echo -e "\n${YELLOW}[NOTE] Set Java heap size for Graylog Server (Recommended: 2GB)"
	read -p "Please define Java heap size (enter value) : " heap_size
	echo -e "${noClr}"
	sed -i '5d' /etc/default/graylog-server
	local heap_size_cfg_s="$xms$heap_size$chr_g"
	local heap_size_cfg_x="$xmx$heap_size$chr_g"
	sed -i "5 i GRAYLOG_SERVER_JAVA_OPTS='$heap_size_cfg_s $heap_size_cfg_x -XX:NewRatio=1 -server -XX:+ResizeTLAB -XX:-OmitStackTraceInFastThrow'" /etc/default/graylog-server
}

function runSrv {
	# Start services
	systemctl daemon-reload
	systemctl enable mongod.service
	systemctl restart mongod.service
	systemctl daemon-reload
	systemctl enable elasticsearch.service
	systemctl restart elasticsearch.service
	systemctl daemon-reload
	systemctl enable graylog-server.service
	systemctl restart graylog-server.service

	echo -e "\n\n${BLUE}Happy Loggin!"
}

addRepo
refreshRepo
modInstaller
esCfg
heapCfgES
glInstaller
glCfg
heapCfgGL
