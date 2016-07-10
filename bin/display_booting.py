#!/usr/bin/python

# Import
import time
import os
import Adafruit_CharLCD as LCD

# Initialize the LCD using the pins 
lcd = LCD.Adafruit_CharLCDPlate()

# Determine ETH0 IP Address.
ifconfig_eth = os.popen("/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{ print $1}'").read().split('\n')
ifconfig_wlan = os.popen("/sbin/ifconfig wlan0 | grep 'inet addr' | cut -d: -f2 | awk '{ print $1}'").read().split('\n')

# Print Welcome message
lcd.clear()
lcd.message('   Welcome to\nLOXBERRY Toolbox')
time.sleep(5.0)

# Print IP Address
lcd.clear()
lcd.message('LAN IP:\n' + ifconfig_eth[0])
time.sleep(10.0)
lcd.clear()
lcd.message('WLAN IP:\n' + ifconfig_wlan[0])
time.sleep(10.0)

# Clear and Exit
lcd.clear()
lcd.message('LOXBERRY Toolbox\n     Ready.')
