#!/bin/bash
printf "\033[34;1mCreate Package\n\033[0m"
_pkgname=ipfs-gatewayacl
pkgdir=`realpath build`
sourceDir=`realpath "$(dirname "$0")/.."`
luaDir="/lib/lua/5.1"
configDir="/etc/$_pkgname"
destDir="/usr/share/$_pkgname"
printf "Source: %s\n" $sourceDir
printf "LuaLib: %s\n" $luaDir
printf "Config: %s\n" $configDir
printf "Dest:   %s\n" $destDir

printf "\033[34;1mPrepare folders\n\033[0m"
printf "LuaLib: %s\n" "$pkgdir$luaDir"
mkdir -p "$pkgdir$luaDir"
printf "Config: %s\n" "$pkgdir$configDir"
mkdir -p "$pkgdir$configDir"
printf "Dest:   %s\n" "$pkgdir$destDir"
mkdir -p "$pkgdir$destDir"

printf "\033[34;1mPopulating folders\n\033[0m"
cp "$sourceDir/lib/*" "$luaDir/"
cp "$sourceDir/config/*" "$configDir/"
cp "$sourceDir/src/*" "$destDir/"