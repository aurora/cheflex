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
	for i in $grp $pkg $src $sys $tmp; do
		if [ ! -d $i ]; then mkdir -p $i; fi
	done

	srcfile=$(basename $u)
	if [ -z $p ]; then p=$n-$v; fi

	echo "info: preparing source: $n-$v"
	if [ $SkipCmp = false ]; then
		if [ ! -f $TmpDir/$srcfile ]; then
			cd $TmpDir
			echo "      downloading $srcfile"
			aria2c $u -o $srcfile
		fi

		echo "      extracting $srcfile"
		tar -C $src -xf $TmpDir/$srcfile
	fi

	echo "      done"
	cd $BldDir
}

CompileSrc() {
	echo "      step 1: compile"
	cd $src/$p
	if type Src >/dev/null 2>&1; then Src; fi
	cd $BldDir
}

CompilePkg() {
	echo "      step 2: install"
	cd $src/$p
	if type Pkg >/dev/null 2>&1; then export -f Pkg; fakeroot Pkg; fi
	cd $BldDir
}

CompressPkg() {
	if [ $KeepPkg = false ]; then
		echo "info: creating package: $n-$v"
		rm -f $pkg/$shr/info/dir
		cd $pkg
	else
		rm -f $pkg/$shr/info/dir
		cd $pkg
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
		LstDir=$pkg/$LstPth
		FileLst="$LstDir/$n.lst"
		if [ ! -d $LstDir ]; then mkdir -p $LstDir; fi
		if [ -f $FileLst ]; then rm -rf $FileLst; touch $FileLst; else touch $FileLst; fi
		lst=$(find -L . -type f | sed 's/.\//\//' | sort| cat)
		for i in "$lst"; do echo "$i" >> $FileLst; done

		if [ -d $LstPth ]; then
			echo "      checking conflict"
			for lst in $(ls $LstPth); do
				_lst=$(basename -s .lst $lst)
				if [ $_lst = $n ]; then echo break; fi
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
		if [ ! -d $sys/pkg ]; then mkdir -p $sys/pkg; fi

		rm -f $sys/pkg/$n-*
		pkgfile=$n$PkgExt
		fakeroot tar -cJf $sys/pkg/$pkgfile ./

		rm -rf $pkg
	fi
	rm -rf $src

	echo "      done"	
	cd $BldDir
}

CompressGrp() {
	grp=$(basename $pth)
	echo "info: creating group: $grp"
	cd $GrpDir

	echo "      creating filelist"
	LstDir=$GrpDir/$LstPth
	FileLst="$LstDir/$grp.lst"
	if [ ! -d $LstDir ]; then mkdir -p $LstDir; fi
	if [ -f $FileLst ]; then rm -rf $FileLst; touch $FileLst; else touch $FileLst; fi
	lst=$(find -L . -type f | sed 's/.\//\//' | sort | cat)
	for i in "$lst"; do echo "$i" >> $FileLst; done

	echo "      compressing file"
	if [ ! -d $SysDir/grp ]; then mkdir -p $SysDir/grp; fi

	rm -f $SysDir/grp/$grp-*
	pkgfile=$grp$PkgExt
	fakeroot tar -cJf $SysDir/grp/$pkgfile ./

	rm -rf ./*

	echo "      done"	
	cd $BldDir
}

CookPackage() {
	if [ $KeepPkg = true ]; then pth=$_pth/$pkg/recipe; fi
	. $pth; export n v u p

	grp=$GrpDir
	pkg=$PkgDir/$n
	src=$SrcDir/$n
	sys=$SysDir
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
		CompileSrc
		CompilePkg	
	fi
	echo "      done"

	CompressPkg; p=""
}

CookPkg() {
	for pth in $args; do
		_pth=$pth; cd $PwdDir
		if [ $KeepPkg = true ]; then
			for pkg in $(ls $_pth); do
				CookPackage
				pth=$_pth; unset -f {Src,Pkg}
				cd $PwdDir
			done
			CompressGrp
		elif [ -d $pth ]; then cd $pth
			find `pwd` -type f -name recipe | sort | while read pth; do
				CookPackage; unset -f {Src,Pkg}
			done
		else
			CookPackage; unset -f {Src,Pkg}
		fi
	done
}

FeedPkg() {
	if [ ! -d $Root ]; then
		mkdir -p $Root
	fi

	if [ "$src" = true ]; then
		name=$(basename "${file%%$PkgExt}")
		echo "info: installing: $name"
		tar -C $Root -xf $file
	else
		for name in $args; do
			echo "info: installing: $name"
			tar -C $Root -xf $SysDir/*/$name$PkgExt
		done
	fi
}

FreePkg() {
	opt="--ignore-fail-on-non-empty"
	for pkg in $args; do
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
		for f in $(ls $LstPth); do
			lst=$(cat $LstPth/$f 2>/dev/null)
			for i in $lst; do
				pkg=$(basename -s ".lst" $LstPth/$f)
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