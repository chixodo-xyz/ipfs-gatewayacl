# IPFS-GatewayACL-Git



## Building

- Arch Linux: PKGBUILD provides all required informationo for `makepkg` 
- Other Linux: Take a look at `misc/build.sh`

## Commit to AUR

Commiting to AUR can be done as following:

```bash
git -c init.defaultbranch=master clone ssh://aur@aur.archlinux.org/ipfs-gatewayalc-git.git 
cd ipfs-gatewayacl-git/
git config user.name [Public Name]
git config user.email [Public E-Mail]
#make required modifications
namcap PKGBUILD
makepkg
namcap ipfs-gatewayacl-git-*.pkg.tar.xz
sudo pacman -U ipfs-gatewayacl-git-*.pkg.tar.xz
#run tests
makepkg --printsrcinfo > .SRCINFO
#verify changes, f.E. using: git status ; git diff
git add PKGBUILD .SRCINFO .gitignore prod.install
git commit -m "useful commit message"
git push
cd ..
rm -rf ipfs-gatewayalc-git
```

Changes will be reflected in: https://aur.archlinux.org/packages/ipfs-gatewayalc-git

Further Information:

- https://wiki.archlinux.org/title/AUR_submission_guidelines
- https://wiki.archlinux.org/title/creating_packages


## Credits
