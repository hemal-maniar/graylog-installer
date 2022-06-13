# Graylog v4.0.16 Installer for Ubuntu 20.04

A single bash script to easily automate installation of a standalone Graylog server. This script builds a server from scratch by fetching repo, installing dependencies and configuring them for the Graylog server. The current version of the configuration supports HTTP access. HTTPS support can be added later.

The script is fairly easy to set up and the installation process will require quite minimal input from the user to get the server up & running in less than 5 minutes.

## Steps

chmod +x graylog.sh
sudo ./graylog.sh

It is important to run the script with elevated privileges as it writes to config files that can only be configured by an administrator. 

## Instructions

The current version runs on multiple bash functions that have been declared within the script. It is recommended to comment out any function that you don't want to run after the initial setup. All function calls are located at the bottom.
