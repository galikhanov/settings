#!/bin/zsh
emulate -LR zsh
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

ln -Fsf $PWD/kitty/kitty.conf ~/.config/kitty/kitty.conf

ln -Fsf $PWD/zsh/.zshrc ~/.zshrc

