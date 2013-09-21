#!/bin/bash

root=

ShowUsage() {
	echo "usage: $0 [options]"
	echo "options:"
	echo "       --root= (change root directory)"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	ShowUsage; exit 0
fi

for i in $@; do
	if [ ${i:0:7} = "--root=" ]; then
		root="${i:7:1000}"
	fi
done

install -m644 cheflex.rc $root/etc/cheflex
install -m755 cheflex.sh $root/usr/bin/cheflex

mkdir -p $root/var/lib/cheflex/{grp,pkg,lst}
chmod 775 $root/var/lib/cheflex/{grp,pkg}
getent group cheflex >/dev/null || groupadd -g 234 cheflex
chown root:cheflex $root/var/lib/cheflex/{grp,pkg}

echo "info: add user to the cheflex group:"
echo "      usermod -a -G cheflex username"
