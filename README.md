# aircrack.sh
A script based on the aircrack-ng package. Used to simplify network penetration testing.

## Features
 - Scan all nearby networks.
 - See connected clients to a particular network.
 - De-auth attacks and key cracking.
 - Save targets for later use.

## Disclaimer
For educational use only. Do NOT use on networks you don't own or have permissions to test!

## Usage
Install required packages:
```console
sudo apt install aircrack-ng figlet
 ```
Open up a Linux terminal and run:
```console
sudo ./aircrack.sh <options>
 ```
Options: <br>
  -i <interface>: Wireless network interface to use. Default is wlp8s0. <br>
  -h: show help <br>
