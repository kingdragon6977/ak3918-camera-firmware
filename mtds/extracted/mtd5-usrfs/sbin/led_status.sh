#!/bin/sh


fn_get_param()
{
	while getopts ":k:m:t:" opt
	do
		case $opt in
		k)
			key=$2
			echo "key=$key"
			;;
		m)
			mode=$2
			echo "mode=$mode"
			;;
		t)
			time=$2
			echo "time=$time"
			;;
		?)
			exit 1
			;;
		esac
		shift 2
	done
}

fn_blink()
{
	if [ $time -ge 1000 ] ; then
		blinktime=`expr $time / 1000`
		yu=`expr $time % 1000`
		blinktime=$blinktime.$yu
	else
		blinktime=0.$time
	fi
	while :; do
		echo 0 > /sys/user-gpio/$key 
		sleep $blinktime
		echo 1 > /sys/user-gpio/$key 
		sleep $blinktime
	done
}

fn_main()
{
	fn_get_param $@

	if [ "$mode" == "1" ] ; then
		echo $mode > /sys/user-gpio/$key
	elif [ "$mode" == "0" ] ; then
		echo $mode > /sys/user-gpio/$key
	elif [ "$mode" == "blink" ] ; then
		fn_blink
	fi
	
}

fn_main $@
