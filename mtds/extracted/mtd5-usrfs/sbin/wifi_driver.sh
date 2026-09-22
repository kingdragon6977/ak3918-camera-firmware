#! /bin/sh
### BEGIN INIT INFO
# File:				rtl8188ftv.sh(wifi_driver.sh)	
# Provides:         8188 driver install and uninstall
# Required-Start:   $
# Required-Stop:
# Default-Start:     
# Default-Stop:
# Short-Description:install driver
# Author:			
# Email: 			
# Date:				2017-08-07
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1

usage()
{
	echo "Usage: $0 station | smartlink | ap | uninstall"
}

station_uninstall()
{
	ID=`lsusb | awk '{print $6}'|grep 8065`
	if [ -n "$ID" ];then #南方硅谷wifi
		rmmod ssv6x5x
		WIFI_EN=`cat /tmp/wifi_mode`
		if [ $WIFI_EN -eq 1 ];then
			echo "#######uninstall 0 wifi_en####"
			echo 0 >/sys/user-gpio/wifi_en #南方硅谷wifi设置1供电，0断电
		else
			echo "#######uninstall 1 wifi_en####"
			echo 1 >/sys/user-gpio/wifi_en #南方硅谷wifi设置1供电，0断电
		fi
		
	else
	  ID=`lsusb | awk '{print $6}'|grep 8888`
	  if [ -n "$ID" ];then #展锐rda5995 wifi
	  	ID=`lsusb | awk '{print $6}'|grep 1e04`
	    if [ -n "$ID" ];then #展锐rda5995 wifi
	  	  echo "rmmod rdawfmac"
	  	  rmmod rdawfmac
	    else
	  	  echo "rmmod atbm603x_wifi_usb"
		    rmmod atbm603x_wifi_usb		
		  fi
	    echo 1 >/sys/user-gpio/wifi_en #展锐rda5995 设置0供电，1断电	
	  else
	    echo "rmmod rtl8188fu"
		  rmmod rtl8188fu
		  #rmmod atbm603x_wifi_usb		
		  echo 1 >/sys/user-gpio/wifi_en #rtl8188ftv设置0供电，1断电	
	  fi
	fi
	rmmod otg-hs
}

station_install()
{
	
    #install usb wifi driver(default)
	echo 1 >/sys/user-gpio/wifi_en #南方硅谷wifi设置1供电，0断电
    sleep 3 #### 等待电源稳定后再加载其他驱动	
	insmod /usr/modules/otg-hs.ko
	sleep 2 #### 等待otg 向usb host 核心层完成一些注册工作后再加在驱动
	
	ID=`lsusb | awk '{print $6}'|grep 8065`
	if [ -n "$ID" ];then #南方硅谷wifi
		insmod /usr/modules/ssv6x5x.ko stacfgpath=/etc/jffs2/ak3916-wifi.cfg
		echo 1 >/tmp/wifi_mode
		echo "#######install 1 wifi_en####"
	else
		echo 0 >/sys/user-gpio/wifi_en #rtl8188ftv设置0供电，1断电
		sleep 3 #### 等待电源稳定后再加载其他驱动
		ID=`lsusb | awk '{print $6}'|grep 8065`
		if [ -n "$ID" ];then #6155	
			#echo 0 >/sys/user-gpio/wifi_en #rtl8188ftv设置0供电，1断电
			#sleep 1 #### 等待电源稳定后再加载其他驱动	
			insmod /usr/modules/ssv6x5x.ko stacfgpath=/etc/jffs2/ak3916-wifi.cfg
			echo 0 >/tmp/wifi_mode
			echo "#######install 0 wifi_en####"
		else
			ID=`lsusb | awk '{print $6}'|grep 007a`
			if [ -n "$ID" ];then #高拓
		
				#echo 0 >/sys/user-gpio/wifi_en #rtl8188ftv设置0供电，1断电
				#sleep 1 #### 等待电源稳定后再加载其他驱动	
				insmod /usr/modules/atbm603x_wifi_usb.ko
			else
			  ID=`lsusb | awk '{print $6}'|grep 8888`
	      if [ -n "$ID" ];then #展锐rda5995 wifi
	      	insmod /usr/modules/rdawfmac.ko
	      else
				  #echo 0 >/sys/user-gpio/wifi_en #0bda,rtl8188ftv设置0供电，1断电
				  #sleep 1 #### 等待电源稳定后再加载其他驱动	
				  insmod /usr/modules/rtl8188fu.ko
				fi
			fi
		fi
	fi
}

smartlink_uninstall()
{
	ID=`lsusb | awk '{print $6}'|grep 8065`
	if [ -n "$ID" ];then #南方硅谷wifi
		rmmod ssv6x5x
		echo 0 >/sys/user-gpio/wifi_en #南方硅谷wifi设置1供电，0断电
	else
		ID=`lsusb | awk '{print $6}'|grep 8888`
	  if [ -n "$ID" ];then #展锐rda5995 wifi
	  	rmmod rdawfmac
	    echo 1 >/sys/user-gpio/wifi_en #展锐rda5995 设置0供电，1断电	
	  else
		  rmmod rtl8188fu
		  echo 1 >/sys/user-gpio/wifi_en #rtl8188ftv设置0供电，1断电	
		fi
	fi
	rmmod otg-hs
}

smartlink_install()
{
  insmod /usr/modules/sdio_wifi.ko
	sleep 1 #### 等待电源稳定后再加载其他驱动
	insmod /usr/modules/otg-hs.ko 
	sleep 2 #### 等待otg 向usb host 核心层完成一些注册工作后再加在驱动
	ID=`lsusb | awk '{print $6}'|grep 8888`
	if [ -n "$ID" ];then #展锐rda5995 wifi
	  insmod /usr/modules/rdawfmac.ko
	else
    insmod /usr/modules/rtl8188fu.ko
	
  fi
}

ap_install()
{
	#install ap mode driver
	echo "install rtl8188ftv ap driver"
}

ap_uninstall()
{
	#uninstall ap mode driver
	echo "uninstall rtl8188ftv ap driver"
}

####### main

case "$MODE" in
	station)
		station_install
		;;
	smartlink)
		smartlink_install
		ifconfig wlan0 up
		iwconfig wlan0 mode monitor
		;;	
	ap)
		ap_install
		;;
	uninstall)
		station_uninstall
		smartlink_uninstall
		ap_uninstall
		;;
	*)
		usage
		;;
esac
exit 0


