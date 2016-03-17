#alias addandload='aliasadd.py && source ~/.bashrc'
alias e='emacs -nw'
alias g='grep'
alias catalias='cat ~/.bash_aliases'
alias gi='grep -i'
alias psgrep='ps ax | grep -i'
alias untarprogram='tar -C ~/programs/ -axvf'
alias unzipprogram='unzip -d ~/programs/'
alias thon='python'
alias br='source ~/.bashrc'
alias j='jobs'
alias blkid='sudo blkid'
alias umount='sudo umount'
alias rsnapshotdiff='rsnapshot -V -c .rsnapshot.conf diff'
alias ffdefault='firefox -P default'
#alias strace_emacs="pg emacs|g -o '[0-9]*' |head -1|sudo xargs strace -p"
alias adb='sudo ~/adb'
alias wac='sudo wifi -y -t ac'
alias echoxs="fc -ln -1 | xsel --clipboard"
alias gitstatus='git status'
alias gitcommit='git commit'
alias gitadd='git add'
alias gitpulloriginmaster='git pull origin master'
alias was='sudo wifi scan'
alias wad='sudo wifi add'
alias gitdiff='git diff'
alias gt='git status'
alias gf='git diff'
alias ga='git add'
alias gm='git commit'
alias gmm='git commit -a -m'
alias grso='git remote show origin'
alias grv='git remote -vv'
alias gpom='git push origin master'
alias sagi='sudo apt-get install'
alias aff='apt-file find'
alias gra='git remote add'
alias grr='git remote remove'
alias grr='git remote rm'
alias wacc='sudo wifi -y connect'
alias acs='apt-cache show'
alias cdsem='cd ~/Documents/cmu/spring15/'
alias .a='source ~/.bash_aliases'
alias chmodx='chmod +x'
alias sstatus='bash -xc '\''sudo service $0 status'\'''
alias sstart='bash -xc '\''sudo service $0 start'\'''
alias sstop='bash -xc '\''sudo service $0 stop'\'''
alias aa='aliasadd.py'
alias ec='emacsclient -n'
alias gl='git log'
alias gpam='git pull andrew master'
alias xs='xsel -ib'
alias tail1='tail -1'
alias head1='head -1'
alias gmmm='git commit -a -m "autocommit on $(date)"'
alias spsi='sudo python setup.py install'
alias mmln='move_last_n.py'
alias affexact='bash -xc '\''apt-file find $0 | grep "/$0$"'\'''
alias duh='du -h'
alias gdmapf='gdmap -f'
alias gamm='git add -A; git commit -a -m'
alias gmmma='git add -A; git commit -a -m "autocommit on $(date)"'
alias l='less -R'
alias sagiy='sudo apt-get install -y'
alias gb='git branch'
alias lp-one-sided='lp -o sides=one-sided'
alias gpgm='git push github-origin master'
alias gsin='git-commit-select-files.sh'
alias gituncommit='git reset --soft HEAD~1'
alias untar='tar axvf'
alias ura='zathura'
alias gitcheckout='git checkout'
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Local Variables:
# mode: sh
# End:
