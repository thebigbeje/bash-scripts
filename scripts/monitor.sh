#!/bin/zsh

mon="$(ifconfig|grep wlan0mon)"
  # grep: Filter output based on pattern matching

if [[ $mon = "" ]]; then
	sudo airmon-ng check kill
	sudo airmon-ng start wlan0
else
	sudo airmon-ng stop wlan0mon
	sudo systemctl restart NetworkManager
#	nrs
fi
