![Cheflex logo](cheflex.png?raw=true)

<h3>A simple yet flexible package manager.

<h3>Objective(s).

    Be close to the source when building.
    Reduce any kind of abstractions.
    Provide mimimal tools for maintenance.
    Keep the system clean, simple and personal.

<h3>Rationale

The Cheflex package manager stems from the principle that GNU/Linux user experience can be both fun and easy, while educational, once the user is able to utilize the development tools that creates a unique and personal OS. That is, building free and open-source software of choices. Cheflex makes it easy to understand the complexity and it reduces unnecessary abstractions. As your humble servant, Cheflex gives you the freedom to customize and improve its functionality whenever it is required and desired by you.

The GNU/Linux community is driven by a strong and cohesive force that brings forth a fully functional operating system containing lots of packages. Packages, like the cells in every organism, are the building blocks of GNU/Linux. Without them, GNU/Linux will remain decentralized. Once the desired packages are built, one can distribute an OS targeting various platforms and user bases. Cheflex, not only gives you the opportunity to build packages, but also helps you distribute them and build the GNU/Linux OS from scratch.

<h3>Building package(s)

In order to build a package, Cheflex needs to be invoked from the command line, while adding "cook" or "-b" as the second argument. This is why Cheflex needs a script file to start building the package(s). It is like a recipe for cooking a meal. It doesn't matter which folder it is in, as long as it can be addressed. For instance:

    cheflex cook ~/myrecipes/grep/recipe

The standard recipe for building a package looks like this:

    n=grep
    v=2.14
    s=infra
    u=ftp://ftp.gnu.org/gnu/$n/$n-$v.tar.xz

    Src() {
            ./configure --prefix=$usr
            make
    }

    Pkg() {
            make DESTDIR=$pkg install
    }

Three variables that Cheflex needs are the name(n), version(v), and url(u) of the source file, which are for instance, required to download and extract it to the source directory($src). If the source file has a varying name, the path(p) variable can be added to resolve it. The Src() section is a function that mainly deals with the configuration and compilation of the software. The Pkg() section takes care of the installation of the files into the package directory($pkg). If the recipe is invoked without any failures, Cheflex will compress package(s) into the /var/lib/cheflex/pkg directory.

Cheflex doesn't explicitly have a group variable defined within the recipe file. However, if you address a directory instead of a recipe file with the "--keep-pkg" option, Cheflex will subsequenly loop through all the recipes in their respective folders, compile them and compress a single group package into the >/var/lib/cheflex/grp directory. For instance, if your collection of recipes are inside the "mygroup" directory, the compressed file will be named "mygroup.pkg" and be found at "/var/lib/cheflex/grp/mygroup.pkg". Just run command:

    cheflex cook mygroup/ --keep-pkg

It is recommended that you build all the packages individually inside a directory. This will save your time and reduce energy during the package updating process. Cheflex can build a given directory containing a collection of packages and resume where it has failed, once the error is fixed. However, it is required that you organize the recipes with the corresponding directory names inside the parent directory, and rerun the same command until the building process is completed. Here is an example:

    cheflex test base/

<h3>Managing package(s)

Before you install the package which you've successfully built, you may want to test it by installing it in a custom directory:

    cheflex feed grep --root=TestDir

There are two ways of knowing if the package contains the files. One way is to walk through the "TestDir" and list the files manually. The other way is to list the package filelist, which is in /var/lib/cheflex/lst/grep.lst. If the package is not installed into the system, you need to list the custom directory:

    cheflex list grep --root=TestDir

Removing a package requires the filelist. In this case, Cheflex looks for TestDir/var/lib/cheflex/lst/grep.lst in order to access the filelist and then removes all the files in that list:

    cheflex free grep --root=TestDir

if the package "grep" is the only one installed into the "TestDir", and is completely removed, then the package is successfully removed when "TestDir" is deleted. If you are not sure of the owner of a file, using the "ownr" command is a good way to find out if the file belongs to the system and works as it should be working:

    cheflex ownr /usr/bin/grep

Cheflex offers you to install group packages within a single package or just individual package(s) for updating or maintaining the system. Once you have the skill to package software and organize the OS, you have the possiblity to create your own OS the way you want with fun and much learning experience. Let the Cheflex build your system!

To learn more about the Cheflex package manager, please study the source file(cheflex.sh), which is written in Bash scripting language, and the configuration file(cheflex.rc), which gives you a good idea of how it works.

<h3>Command summary:

    cheflex --help

    cheflex cook grep/recipe grub/recipe

    cheflex cook glibc/ --keep-dbg

    cheflex cook base devel --keep-pkg

    cheflex feed --file=~/Downloads/grep.pkg

    cheflex feed grep grub

    cheflex feed grep grub --root=myworkdir

    cheflex free grep --root=myworkdir

    cheflex free devel

    cheflex list grep --root=myworkdir

    cheflex list grub

    cheflex ownr /usr/bin/grep --root=myworkdir

    cheflex ownr /usr/bin/grub-mount

    cheflex test /home/user/build/extra
