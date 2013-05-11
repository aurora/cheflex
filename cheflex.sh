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
PwdDir=`pwd`
Root=$RootDir
args=""

PrepareSrc() {
	for i in $grp $pkg $src $tmp; do
		if [ ! -d $i ]; then mkdir -p $i; fi
	done

	srcfile=$(basename $u)
	if [ -z $p ]; then p=$n-$v; fi

	echo "info: preparing source: $n-$v"
	if [ $SkipCmp = false ]; then
		if [ ! -f $TmpDir/$srcfile ]; then
			echo "      downloading $srcfile"
			cd $TmpDir; aria2c $u -o $srcfile
		fi

		echo "      extracting $srcfile"
		tar -C $src -xf $TmpDir/$srcfile
	fi

	echo "      done"; cd $BldDir
}

CompileSrc() {
	cd $src/$p
	echo "      step 1: compile"
	if type Src >/dev/null 2>&1; then Src; fi
	cd $BldDir
}

CompilePkg() {
	cd $src/$p
	echo "      step 2: install"
	if type Pkg >/dev/null 2>&1; then export -f Pkg; fakeroot Pkg; fi
	cd $BldDir
}

CompressPkg() {
	cd $pkg; rm -f $pkg/$shr/info/dir

	if [ $KeepPkg = false ]; then
		echo "info: creating package: $n"
	fi

	if [ $KeepDbg = false ]; then
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

	if [ $KeepPkg = false ]; then
		echo "      creating filelist"
		LstPth=$pkg/$LstDir
		FileLst="$LstPth/$n.lst"

		if [ ! -d $LstPth ]; then mkdir -p $LstPth; fi
		if [ -f $FileLst ]; then rm -rf $FileLst; touch $FileLst; else touch $FileLst; fi
		lst=$(find -L . -type f | sed 's/.\//\//' | sort| cat)
		for i in "$lst"; do echo "$i" >> $FileLst; done

		if [ -d $LstPth ]; then
			echo "      checking conflict"
			for lst in $(ls $LstPth); do
				_lst=$(basename -s .lst $lst)
				if [ $_lst = $n ]; then break; fi
				for lst_x in $(cat $LstPth/$lst); do
					for lst_y in $(cat $FileLst); do
						if [ $lst_x = $lst_y ]; then
							echo "      $n: conflicts $_lst: $lst_y"
						fi
					done
				done
			done
		fi

		echo "      compressing file"
		rm -f $ChfDir/pkg/$n$PkgExt; pkgfile=$n$PkgExt
		fakeroot tar -cJf $ChfDir/pkg/$pkgfile ./
		rm -rf $pkg
	fi
	rm -rf $src

	echo "      done"; cd $BldDir
}

CompressGrp() {
	cd $GrpDir; grp=$(basename $pth)
	echo "info: creating group: $grp"

	echo "      creating filelist"
	LstPth=$GrpDir/$LstDir
	FileLst="$LstPth/$grp.lst"

	if [ ! -d $LstPth ]; then mkdir -p $LstPth; fi
	if [ -f $FileLst ]; then rm -rf $FileLst; touch $FileLst; else touch $FileLst; fi
	lst=$(find -L . -type f | sed 's/.\//\//' | sort | cat)
	for i in "$lst"; do echo "$i" >> $FileLst; done

	echo "      compressing file"
	rm -f $ChfDir/grp/$grp$PkgExt; pkgfile=$grp$PkgExt
	fakeroot tar -cJf $ChfDir/grp/$pkgfile ./
	rm -rf ./*

	echo "      done"; cd $BldDir
}

CookPackage() {
	. $pth; export n v u p

	grp=$GrpDir
	pkg=$PkgDir/$n
	src=$SrcDir/$n
	tmp=$TmpDir

	pth=$(dirname $pth); cd $pth; rcs=`pwd`
	if [ $KeepPkg = true ]; then pkg=$grp; fi

	export bin etc lib run shr usr var pkg src rcs
	export CHOST CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS

	PrepareSrc

	echo "info: compiling source: $n-$v"
	if [ $SkipCmp = true ]; then
		CompilePkg
	else
		CompileSrc; CompilePkg	
	fi

	echo "      done"

	CompressPkg; p=""
}

CookPkg() {
	for pth in $args; do
		if [ -d $pth ]; then cd $pth
			find `pwd` -type f -name recipe | sort | while read pth; do
				CookPackage; unset -f {Src,Pkg}
			done
			if [ $KeepPkg = true ]; then CompressGrp; fi
		else
			CookPackage; unset -f {Src,Pkg}
		fi
	done
}

FeedPkg() {
	if [ ! -d $Root ]; then mkdir -p $Root; fi

	if [ "$src" = true ]; then
		pkg=$(basename -s ".pkg" $file)
		echo "info: installing $pkg"
		tar -C $Root -xf $file
	fi

	for pkg in $args; do
		if [ -d $pkg ]; then Root=`pwd`/$Root; cd $pkg
			find `pwd` -type f -iname "*.pkg" | sort | while read _pkg; do
				echo "info: installing $(basename -s ".pkg" $_pkg)"
				tar -C $Root -xf $_pkg
			done
		else
			echo "info: installing $pkg"
			if [ -f $ChfDir/grp/$pkg$PkgExt ]; then
				tar -C $Root -xf $ChfDir/grp/$pkg$PkgExt
			else tar -C $Root -xf $ChfDir/pkg/$pkg$PkgExt; fi
		fi
	done
}

FreePkg() {
	opt="--ignore-fail-on-non-empty"
	for pkg in $args; do
		echo "info: removing $pkg"
		lst=$(cat $LstPth/$pkg.lst)

		for i in $lst; do
			if [ -L $Root$i ]; then unlink $Root$i; fi
			if [ -f $Root$i ]; then rm $Root$i; fi
		done

		for i in $lst; do
			i=$(dirname $i)
			if [ -d $Root$i ]; then rmdir -p $opt $Root$i; fi
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
	if [ ${i:0:7} = "--root=" ]; then Root="${i:7:1000}"; LstPth="$Root$LstPth"
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