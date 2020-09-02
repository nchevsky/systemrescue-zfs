#
# ~/.bashrc
#

PS1="\[\e[1;94m\][\u@\h \w]\\$\[\e[0m\] "

alias ls='ls --color=auto'
alias ll='ls --color=auto -lah'
alias mydf='df -hPT | column -t'
alias mylsblk='lsblk -o name,size,fstype,label,model'

# Change color of yellow text so it is readable in the terminal
eval $(dircolors -p | sed -e 's/40;33/0;31/g' | dircolors -)
