#! /bin/sh

echo "############update play aac dididi.....#############"

cp /usr/share/audio_file/common/didi.aac /tmp/

while true
do
	ccli -t --f "/tmp/didi.aac"
	
	#light on
	echo 0 > /sys/user-gpio/AP_LED
	echo 0 > /sys/user-gpio/PWR_LED
	
	usleep 700000
	
	#light off
	echo 1 > /sys/user-gpio/AP_LED
	echo 1 > /sys/user-gpio/PWR_LED

	usleep 800000
done



