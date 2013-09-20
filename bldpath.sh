#!/bin/bash

. /etc/cheflex

ShowUsage() {
	echo "usage: `basename $0` <path>"
}

if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	ShowUsage; exit 0
fi

pth=$PthDir/$(basename $1)

if [ ! -d "$pth" ]; then mkdir -p $pth; fi

for i in $(ls $1); do
	if [ ! -f "$pth/$i" ]; then echo "cheflex -b $1/$i" > $pth/$i; fi
done

for i in $(ls $1); do
	if [ ! -f $pth/$i.done ]; then sh $pth/$i; fi
	if [ $? -eq 0 ]; then touch $pth/$i.done; else exit 0; fi
done

for i in $(ls $1); do
	if [ ! -f $pth/$i.done ]; then exit 1; fi
done

if [ $? -eq 0 ]; then rm -r $pth; fi