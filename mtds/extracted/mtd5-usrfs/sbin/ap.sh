#!/bin/sh

#cfgfile="/etc/jffs2/anyka_cfg.ini"
cfgfile="/tmp/ap_cfg.ini"

wifi_ap_start()
{
	killall smartlink 2>/dev/null
	killall wpa_supplicant 2>/dev/null

	## check driver
	wifi_driver.sh uninstall
	wifi_driver.sh station

	echo "start wlan0 on ap mode"
	ifconfig wlan0 up

    ssid=`cat $cfgfile | grep 's_ssid' | awk '{print $3}'`
    password=`cat $cfgfile | grep 's_password' | awk '{print $3}'`

	#ssid=`awk 'BEGIN {FS="="}/\[softap\]/{a=1} a==1 && 
	#$1~/s_ssid/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
	#gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	#password=`awk 'BEGIN {FS="="}/\[softap\]/{a=1} a==1 && 
	#$1~/s_password/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
	#gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`

	echo "ap :: ssid=$ssid password=$password"
	if [ -z "$ssid" ];then
		ssid="XiaoYi_IPC"
	fi
	
	ID=`lsusb | awk '{print $6}'|grep 8065`
	if [ -n "$ID" ];then #南方硅谷wifi
		/usr/sbin/device_save_ssv6x5x.sh name "$ssid"
		/usr/sbin/device_save_ssv6x5x.sh password "$password"

		if [ -z $password ];then
			/usr/sbin/device_save_ssv6x5x.sh setwpa 0
		else
			/usr/sbin/device_save_ssv6x5x.sh setwpa 2
		fi
		hostapd_ssv6x5x /etc/jffs2/hostapd_ssv6x5x.conf -B
	else #rtl8188
		ID=`lsusb | awk '{print $6}'|grep 007a`
		if [ -n "$ID" ];then #南方硅谷wifi
			/usr/sbin/device_save_atmb.sh name "$ssid"
			/usr/sbin/device_save_atmb.sh password "$password"

			if [ -z $password ];then
				/usr/sbin/device_save_atmb.sh setwpa 0
			else
				/usr/sbin/device_save_atmb.sh setwpa 2
			fi
			hostapd_atmb /etc/jffs2/hostapd_atmb.conf -B
		else
			/usr/sbin/device_save.sh name "$ssid"
			/usr/sbin/device_save.sh password "$password"

			if [ -z $password ];then
				/usr/sbin/device_save.sh setwpa 0
			else
				/usr/sbin/device_save.sh setwpa 2
			fi
			ID=`lsusb | awk '{print $6}'|grep 8888`
	    if [ -n "$ID" ];then #展锐rda5995 wifi
	    	hostapd /etc/jffs2/hostapd.conf -B
	    else
			  hostapd /etc/jffs2/hostapd.conf -B
			fi
		fi	
	fi
	ifconfig wlan0 192.168.10.1
	route del default 2>/dev/null
	route add default gw 192.168.10.1 wlan0
	udhcpd /etc/udhcpd.conf
}

wifi_ap_stop()
{
	killall hostapd 2>/dev/null
	killall hostapd_ssv6x5x 2>/dev/null
	killall hostapd_atmb 2>/dev/null
	killall hostapd_rda5995 2>/dev/null
	killall udhcpd 2>/dev/null
	ifconfig wlan0 down
	wifi_driver.sh uninstall
	route del default 2>/dev/null
}

usage()
{
	echo "$0 start | stop"
}


case $1 in
	start)
		wifi_ap_start
		;;
	stop)
		wifi_ap_stop
		;;
	*)
		usage
		;;
esac
	


