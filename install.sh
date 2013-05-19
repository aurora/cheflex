root=

HelpMeUseIt() {
	echo "options:"
	echo "       --root= (change root directory)"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	HelpMeUseIt; exit 0
fi

for i in $@; do
	if [ ${i:0:7} = "--root=" ]; then
		root="${i:7:1000}"
	fi
done

install -m755 cheflex.sh $root/usr/bin/cheflex
install -m644 cheflex.rc $root/etc/cheflex