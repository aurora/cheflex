#!/bin/bash
set -e

# Copyright 2013 Ali H. Caliskan <ahc@selflex.org>
# Cheflex is licenced under the General Public License
# version 3, GPLv3. Read the included LICENSE file.

. /etc/cheflex
Cook=false
Feed=false
Free=false
List=false
Ownr=false
SkipCmp=false
KeepDbg=false
KeepPkg=false
CookGrp=false
PwdDir=`pwd`
Root=$RootDir
FirstTime=false
LastTime=false
State="/tmp/cook"
args=""

Source() {
	if [ $KeepPkg = false ]; then _dirs=($pkg $src $tmp)
	else _dirs=($grp $src $tmp); fi
	for i in "${_dirs[@]}"; do
		if [ ! -d $i ]; then mkdir -p $i; fi
	done

	srcfile=$(basename $u)
	if [ -z $p ]; then p=$n-$v; fi

	echo "cook: preparing $n-$v"
	if [ $SkipCmp = false ]; then
		if [ ! -f $TmpDir/$srcfile ]; then
			echo "      downloading $srcfile"
			cd $TmpDir; aria2c $u -o $srcfile
		fi

		echo "      extracting $srcfile"
		tar -C $src -xpf $TmpDir/$srcfile
	fi

	if [ $SrcFunc = true ]; then
			cd $src/$p
			echo "      compiling $n-$v"; Src
			echo "done"; cd $BldDir
	fi
}

Package() {
	if [ $KeepPkg = true ]; then pkg=$grp; fi

	if [ $PkgFunc = true ]; then
		cd $src/$p; echo "      installing files"; Pkg
	fi

	if [ $CookGrp = true ]; then
		_grp=$(basename "$_grp")
	fi

	if [ $CookGrp = true ] || [ $KeepPkg = true ];then
		cd $grp; rm -f $grp/$shr/info/dir
	elif [ $KeepPkg = false ]; then
		cd $pkg; rm -f $pkg/$shr/info/dir
	fi

	if [ "$KeepDbg" = false ]; then
		echo "      stripping files"
		find . -type f | while read _file; do
			case $(file --mime-type -b $_file) in
				*application/x-executable*)
					strip $_file;;
				*application/x-sharedlib*)
					strip $_file;;
				*application/x-archive*)
					strip $_file;;
			esac
		done
	fi

	if [ "$CookGrp" = true ]; then
		echo "      creating filelist"
		LstPth=$grp/$LstDir
		FileLst="$LstPth/$_grp.lst"
	elif [ "$KeepPkg" = false ]; then
		echo "      creating filelist"
		LstPth=$pkg/$LstDir
		FileLst="$LstPth/$n.lst"
	fi

	if [ "$CookGrp" = true ] || [ "$KeepPkg" = false ]; then
		if [ ! -d $LstPth ]; then mkdir -p $LstPth; fi
		if [ -f $FileLst ]; then rm -rf $FileLst; touch $FileLst; else touch $FileLst; fi
		lst=$(find -L ./ | sed 's/.\//\//' | sort | cat)
		for i in "$lst"; do echo "$i" >> $FileLst; done
	fi

	if [ "$KeepPkg" = false ]; then
		if [ -d $LstPth ]; then
			echo "      checking conflict"
			for lst in $(ls $LstPth); do
				_lst=$(basename -s .lst $lst)
				if [ $_lst = $n ]; then break; fi
				for lst_x in $(cat $LstPth/$lst); do
					if [ -d $lst_x ]; then continue; fi
					for lst_y in $(cat $FileLst); do
						if [ $lst_x = $lst_y ]; then
							echo "      $n: conflicts $_lst: $lst_y"
						fi
					done
				done
			done
		fi
	fi

	if [ $CookGrp = true ]; then
		echo "      compressing $_grp$PkgExt"
		if [ "$Root" = "/" ]; then Root=$ChfDir/grp
		else Root=$PwdDir/$Root/$ChfDir/grp; mkdir -p $Root; fi
		rm -f $Root/$_grp$PkgExt; pkgfile=$_grp$PkgExt
		tar -cpJf $Root/$pkgfile ./; rm -rf ./*; rm -f $State
	elif [ "$KeepPkg" = false ]; then
		echo "      compressing $n$PkgExt"
		if [ "$Root" = "/" ]; then Root=$ChfDir/pkg
		else Root=$PwdDir/$Root/$ChfDir/pkg; mkdir -p $Root; fi
		rm -f $Root/$n$PkgExt; pkgfile=$n$PkgExt
		tar -cpJf $Root/$pkgfile ./; rm -rf $pkg
	fi
	rm -rf $src

	if [ $CookGrp = true ]; then echo "done"; cd $BldDir
	elif [ $KeepPkg = true ]; then cd $BldDir
	else echo "done"; cd $BldDir; fi

}

Compose() {
	. $pth; export n v u p
	grp=$GrpDir; pkg=$PkgDir/$n; src=$SrcDir/$n; tmp=$TmpDir

	pth=$(dirname $pth); cd $pth; rcs=`pwd`

	SrcFunc=false; PkgFunc=false
	if type Src >/dev/null 2>&1; then SrcFunc=true; export -f Src; fi
	if type Pkg >/dev/null 2>&1; then PkgFunc=true; export -f Pkg; fi

	export bin etc lib run shr usr var grp pkg src rcs
	export SrcFunc PkgFunc KeepPkg KeepDbg SkipCmp State

	if [ $FirstTime = false ] && [ $KeepPkg = true ]; then
		export FirstTime=true
		Source; export -f Package; fakeroot -s $State Package
	elif [ $LastTime = false ] && [ $CookGrp = true ]; then
		export LastTime=true
		Source; export -f Package; fakeroot -i $State Package
	elif [ $KeepPkg = true ]; then
		Source; export -f Package; fakeroot -i $State -s $State Package
	else
		if [ $SkipCmp = true ]; then export -f Package; fakeroot Package
		else Source; export -f Package; fakeroot Package; fi
	fi		

	unset -f {Src,Pkg}; unset {SrcFunc,PkgFunc}; p=""
}

CookPkg() {
	export Root PwdDir GrpDir ChfDir LstDir BldDir PkgExt
	export CHOST CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS CookGrp

	for pth in $args; do
		if [ -d $pth ]; then _grp=$pth; export _grp; cd $pth
			for y in $(find `pwd` -type f -name recipe | sort -r); do
				for pth in $(find `pwd` -type f -name recipe | sort); do
					if [ "$y" = "$pth" ] && [ $KeepPkg = true ]; then
						CookGrp=true; export CookGrp
						Compose; break 2
					elif [ "$y" = "$pth" ] && [ $KeepPkg = false ]; then
						Compose; break 2
					else Compose; fi
				done
			done
		else Compose; fi
	done
}

FeedPkg() {
	if [ ! -d $Root ]; then mkdir -p $Root; fi

	if [ "$src" = true ]; then
		pkg=$(basename -s ".pkg" $file)
		echo "feed: installing $pkg"
		tar -C $Root -xpf $file
	fi

	for pkg in $args; do
		if [ -d $pkg ]; then Root=`pwd`/$Root; cd $pkg
			find `pwd` -type f -iname "*.pkg" | sort | while read _pkg; do
				echo "feed: installing $(basename -s ".pkg" $_pkg)"
				tar -C $Root -xpf $_pkg
			done
		else
			echo "feed: installing $pkg"
			if [ -f $ChfDir/grp/$pkg$PkgExt ]; then
				tar -C $Root -xpf $ChfDir/grp/$pkg$PkgExt
			else tar -C $Root -xpf $ChfDir/pkg/$pkg$PkgExt; fi
		fi
	done
}

FreePkg() {
	opt="--ignore-fail-on-non-empty"
	for pkg in $args; do
		echo "free: removing $pkg"
		lst=$(tac $LstPth/$pkg.lst)

		for i in $lst; do
			_i=$(dirname $i)
			if [ -L $Root/$i ]; then unlink $Root/$i
			elif [ -f $Root/$i ]; then rm $Root/$i; rmdir -p $opt $Root/$_i
			elif [ -d $Root/$i ]; then rmdir -p $opt $Root/$i; fi
		done
	done
}

ListPkg() {
	for pkg in $args; do
		cat $LstPth/$pkg.lst
	done
}

OwnrPkg() {
	for src in $args; do
		for f in $(ls $LstPth); do lst=$(cat $LstPth/$f)
			for i in $lst; do pkg=$(basename -s ".lst" $LstPth/$f)
				if [ $i = $src ]; then echo "$pkg: $i"; fi
			done
		done
	done
}

HelpMeUseIt() {
	echo "usage: cheflex <options> <package(s)> "
	echo "options:"
	echo "       cook (build package(s))"
	echo "       feed (install package(s))"
	echo "       free (remove package(s))"
	echo "       list (list package content)"
	echo "       ownr (check package owner"
	echo "       --file= (local file(s))"
	echo "       --root= (change root directory)"
	echo "       --skip-cmp (don't compile the source)"
	echo "       --keep-dbg (don't strip debug information)"
	echo "       --keep-pkg (create group package)"
}

if [ -z "$1" ] || [ -z "$2" ] || [ $1 = "--help" ] || [ $1 = "-h" ]; then
	HelpMeUseIt; exit 0
fi

for i in $@; do
	if [ ${i:0:7} = "--root=" ]; then Root="${i:7:1000}"; LstPth="$Root/$LstDir"
	elif [ ${i:0:7} = "--file=" ]; then file="${i:7:1000}"; src=true
	elif [ "$i" = "--skip-cmp" ]; then SkipCmp=true
	elif [ "$i" = "--keep-dbg" ]; then KeepDbg=true
	elif [ "$i" = "--keep-pkg" ]; then KeepPkg=true
	elif [ "$i" = "cook" ]; then Cook=true
	elif [ "$i" = "feed" ]; then Feed=true
	elif [ "$i" = "free" ]; then Free=true
	elif [ "$i" = "list" ]; then List=true
	elif [ "$i" = "ownr" ]; then Ownr=true
	else args="$args $i"; fi
done

if [ $Cook = true ]; then CookPkg; fi
if [ $Feed = true ]; then FeedPkg; fi
if [ $Free = true ]; then FreePkg; fi
if [ $List = true ]; then ListPkg; fi
if [ $Ownr = true ]; then OwnrPkg; fi