# ~/.zshrc

# Prompt backend. Keep both installed, but initialize only one.
: "${ZSH_PROMPT_ENGINE:=p10k}"  # p10k | starship

# Enable Powerlevel10k instant prompt. Keep close to the top.
if [[ "$ZSH_PROMPT_ENGINE" == p10k && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]} m:{[:lower:][:upper:]}={[:upper:][:lower:]} r:|[._-]=** r:|=** l:|=*' 'm:{[:lower:]}={[:upper:]} m:{[:lower:][:upper:]}={[:upper:][:lower:]} r:|[._-]=** r:|=** l:|=*' 'm:{[:lower:]}={[:upper:]} m:{[:lower:][:upper:]}={[:upper:][:lower:]} r:|[._-]=** r:|=** l:|=*' 'm:{[:lower:]}={[:upper:]} m:{[:lower:][:upper:]}={[:upper:][:lower:]} r:|[._-]=** r:|=** l:|=*'
zstyle ':completion:*' max-errors 3 numeric
zstyle :compinstall filename '/home/cppshizoid/.zshrc'

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # prompt is initialized explicitly below
zstyle ':omz:update' mode auto
ENABLE_CORRECTION="true"

# Keep OMZ for its built-in plugins. External plugins are loaded once via Zinit.
# fzf shell integration is initialized explicitly near the end so Atuin can own Ctrl-R.
plugins=(git rust tmux ansible dotnet kubectl mvn gradle npm history systemd jsontools sudo dnf copyfile copybuffer thefuck vscode)
source "$ZSH/oh-my-zsh.sh"

# CachyOS defaults first; our final integrations/keybindings below intentionally win.
[[ -r /usr/share/cachyos-zsh-config/cachyos-config.zsh ]] && source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# User configuration
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

export PATH="$HOME/.local/bin:$PATH"

# vulkan
export PATH=/usr/local/vulkan${PATH:+:$PATH}

# Compilation flags
export ARCHFLAGS="-arch x86_64 -fuse-ld=mold"
export CC=clang
export CXX=clang++

# Aliases
alias s="source ~/.zshrc"
alias zshconfig="nvim ~/.zshrc"
alias ohmyzsh="nvim ~/.oh-my-zsh"
alias cat='bat --theme="Catppuccin Mocha"'
alias du='dust'
alias cl='clear'
alias count='find . -type f | wc -l'
alias e='echo'
alias k='kubectl'
#alias gh='history|grep'
alias nf='fastfetch'
alias nv='nvim'
alias v='vim'
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias to=". gotodir"

alias weather="~/Scripts/weather.sh"
alias rfv='~/Scripts/rfv.zsh'
alias rfc='~/Scripts/rfc.zsh'
alias rfg='~/Scripts/fzf-git.zsh'
alias dnff='~/Scripts/dnf.sh'
alias flf='~/Scripts/flatpak_fzf.sh'
#mounted devices
alias mnt="mount | awk -F' ' '{ printf \"%s\t%s\n\",\$1,\$3; }' | column -t | egrep ^/dev/ | sort"

#jb ide
alias clion='~/.local/share/JetBrains/Toolbox/scripts/clion'
alias rider='~/.local/share/JetBrains/Toolbox/scripts/rider'
alias pycharm='~/.local/share/JetBrains/Toolbox/scripts/pycharm'
alias idea='~/.local/share/JetBrains/Toolbox/scripts/idea'
alias datagrip='~/.local/share/JetBrains/Toolbox/scripts/datagrip'
alias androidstudio='~/.local/share/JetBrains/Toolbox/scripts/studio'

#nvitop
alias nvitop='pipx run nvitop'

#docker
alias docstats='docker stats $(docker ps -q)'                                  # stats on images
alias dcu='docker-compose up -d'
alias dcd='docker-compose down'
alias dim='docker images'
alias dps='docker ps'
alias dpsa='docker ps -a'

#exa
alias ls='eza'
alias l='eza -l --all --group-directories-first --git'
alias ll='eza -l --all --group-directories-first --git'
alias lt='eza -T --git-ignore --level=2 --group-directories-first'
alias llt='eza -lT --git-ignore --level=2 --group-directories-first'
alias lT='eza -T --git-ignore --level=4 --group-directories-first'
alias t='eza --tree --level=2 --long'
#rust
alias crg_run='cargo build && cargo run'

#clang
alias cclg_run='f(){ clang -Wall -o testc "$@" -std=c11 -lm -fuse-ld=mold && ./testc; unset -f f;}; f'
alias clg_dbg='f(){ clang++ -g -Wall -Wextra -Werror -o test "$@" -std=c++23 -fuse-ld=mold && ./test; unset -f f;}; f'
alias clg_run='f(){ clang++ -Wall -o test "$@" -std=c++23 -fuse-ld=mold && ./test; unset -f f;}; f'
alias clg_tst='f(){ clang++ -Wall -Wextra -Werror -o test "$@" -std=c++2c -fuse-ld=mold && ./test; unset -f f;}; f'
#clang-format
alias clgf='clang-format --style=Google --dump-config > .clang-format'

#gcc
alias glg_run='f() {g++ -Wall -o test "$@" -std=c++2a && ./test; unset -f f;}; f'


#clickhouse
alias clickhouse='~/clickhouse'

#dotnet
alias di='dotnet --info'
alias dv='dotnet --version'
alias dlr='dotnet --list-runtimes'
alias dls='dotnet --list-sdks'
alias db='dotnet build'
alias dbd='dotnet build --diagnostics'
alias dc='dotnet clean'
alias dm='dotnet migrate'
alias dms='dotnet msbuild'
alias dn='dotnet new'
alias dr='dotnet run'
alias dsc='dotnet script'
alias ds='dotnet sln'
alias dch='dotnet sdk check'
alias dap='dotnet add package'
alias drp='dotnet remove package'
alias dwi='dotnet workload install'
alias dwl='dotnet workload list'
alias dws='dotnet workload search'
alias dwu='dotnet workload uninstall'
alias dwup='dotnet workload update'
alias dti='dotnet tool install'
alias dtl='dotnet tool list'
alias dts='dotnet tool search'
alias dtu='dotnet tool uninstall'
alias dtup='dotnet tool update'
alias nuget='dotnet nuget'

#python
alias pipi='pip install'
alias p='python'
alias up='python -m pip install --upgrade pip'

#django
alias pym='python manager.py'
alias dj-sp='django-admin startproject'
alias dj-sa='pym startapp'
alias dj-rs='pym runserver'
alias dj-mm='pym makemigrations'
alias dj-mg='pym migrate'
alias dj-sm='pym sqlmigrate'
alias dj-ch='pym check'
alias dj-sh='pym shell'
alias dj-ds='pym dbshell'
alias dj-cs='pym createsuperuser'
alias dj-ts='pym test'



#colima
alias colima='/usr/local/bin/colima-Linux-x86_64'
#system
alias dnfi="sudo dnf5 install"
alias fli="flatpak install"
alias flu="flatpak update"
alias update="sudo dnf5 update -y; flatpak update; zinit update"

#extract archives
extract () {
 if [ -f $1 ] ; then
 case $1 in
 *.tar.bz2)   tar xjf $1        ;;
 *.tar.gz)    tar xzf $1     ;;
 *.bz2)       bunzip2 $1       ;;
 *.rar)       unrar x $1     ;;
 *.gz)        gunzip $1     ;;
 *.tar)       tar xf $1        ;;
 *.tbz2)      tar xjf $1      ;;
 *.tbz)       tar -xjvf $1    ;;
 *.tgz)       tar xzf $1       ;;
 *.zip)       unzip $1     ;;
 *.Z)         uncompress $1  ;;
 *.7z)        7z x $1    ;;
 *)           echo "I don't know how to extract '$1'..." ;;
 esac
 else
 echo "'$1' is not a valid file"
 fi
}
#create archives
pk () {
 if [ $1 ] ; then
 case $1 in
 tbz)       tar cjvf $2.tar.bz2 $2      ;;
 tgz)       tar czvf $2.tar.gz  $2       ;;
 tar)      tar cpvf $2.tar  $2       ;;
 bz2)    bzip $2 ;;
 gz)        gzip -c -9 -n $2 > $2.gz ;;
 zip)       zip -r $2.zip $2   ;;
 7z)        7z a $2.7z $2    ;;
 *)         echo "'$1' cannot be packed via pk()" ;;
 esac
 else
 echo "'$1' is not a valid file"
 fi
}

# Zinit (single initialization)
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
[[ -r "$ZINIT_HOME/zinit.zsh" ]] && source "$ZINIT_HOME/zinit.zsh"

# zplug extras (kept, but do not fail startup when zplug is absent).
# Load these before fzf-tab so fzf-tab can remain the final Tab-completion wrapper.
if [[ -r "$HOME/.zplug/init.zsh" ]]; then
  source "$HOME/.zplug/init.zsh"
  zplug "changyuheng/fz", defer:1
  zplug "rupa/z", use:z.sh
  zplug "chitoku-k/fzf-zsh-completions"
  zplug load
fi

if (( $+functions[zinit] )); then
  autoload -Uz _zinit
  (( ${+_comps} )) && _comps[zinit]=_zinit

  # Annexes used by Zinit installers.
  zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

  # External plugins. fzf-tab must be before wrappers such as autosuggestions/highlighting.
  zinit light marlonrichert/zsh-autocomplete
  zinit light Aloxaf/fzf-tab
  zinit light zsh-users/zsh-autosuggestions
  zinit light zdharma-continuum/fast-syntax-highlighting
  zinit light darvid/zsh-poetry

  if [[ "$ZSH_PROMPT_ENGINE" == p10k ]]; then
    zinit ice depth=1
    zinit light romkatv/powerlevel10k
  fi
fi


#fzf-tab
zstyle ':completion:*' fzf-search-display true
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
# NOTE: don't use escape sequences here, fzf-tab will ignore them
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
export PATH=/opt/cuda/bin:$PATH
#cargo
export PATH=$PATH:/home/cppshizoid/.cargo/bin
#go
export PATH=$PATH:/home/cppshizoid/go/bin
#dotnet
export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools
#vcpkg
export VCPKG_ROOT=/home/cppshizoid/vcpkg
export PATH=$VCPKG_ROOT:$PATH
#ninja
export CMAKE_GENERATOR=Ninja


#fzf
# Print tree structure in the preview window
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"
# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='**'

# Options to fzf command
export FZF_COMPLETION_OPTS='--border --info=inline'

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'tree -C {} | head -200'   "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview 'bat -n --color=always {}' "$@" ;;
  esac
}


_fzf_and_run_widget() {
  _fzf_comprun
  zle accept-line
}
zle -N fzf-and-run-widget _fzf_and_run_widget
bindkey '^[^I' fzf-and-run-widget

#gradle
#export PATH=$PATH:/opt/gradle/gradle-8.2.1/bin

#sdkman
#export SDKMAN_DIR="$HOME/.sdkman"
#[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
#docker-composev2
#export PATH=
#docker-rootless
export PATH=/home/cppshizoid/bin:$PATH
#export DOCKER_HOST=unix:///run/user/1000/docker.sock
#deno
export DENO_INSTALL="/home/cppshizoid/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

function cd() {
    if [[ "$#" != 0 ]]; then
        builtin cd "$@";
        return
    fi
    while true; do
        local lsd=$(echo ".." && ls -p | grep '/$' | sed 's;/$;;')
        local dir="$(printf '%s\n' "${lsd[@]}" |
            fzf --reverse --preview '
                __cd_nxt="$(echo {})";
                __cd_path="$(echo $(pwd)/${__cd_nxt} | sed "s;//;/;")";
                echo $__cd_path;
                echo;
                ls -p --color=always "${__cd_path}";
        ')"
        [[ ${#dir} != 0 ]] || return 0
        builtin cd "$dir" &> /dev/null
    done
}

fzf-conda-activate () {
    choice=(
        $(
            conda env list |
            sed 's/\*/ /;1,2d' |
            xargs -I {} bash -c '
                name_path=( {} );
                py_version=( $(${name_path[1]}/bin/python --version) );
                echo ${name_path[0]} ${py_version[1]} ${name_path[1]}
            ' |
            column -t |
            fzf --layout=reverse \
                --info=inline \
                --border=rounded \
                --height=40 \
                --preview-window="right:30%" \
                --preview-label=" conda tree leaves " \
                --preview=$'
                    conda tree -p {3} leaves |
                    perl -F\'[^\\w-_]\' -lae \'print for grep /./, @F;\' |
                    sort
                '
        )
    )
    [[ -n "$choice" ]] && conda activate "$choice"
}

# Completion helpers
# Oh My Zsh already initialized compsys; do not call compinit again.
compdef _gnu_generic fzf 2>/dev/null || true
autoload -Uz bashcompinit
bashcompinit
[[ -r /usr/bin/scripts/vcpkg_completion.zsh ]] && source /usr/bin/scripts/vcpkg_completion.zsh

# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Remaining PATH / environment
export PATH="$PATH:/home/cppshizoid/.dotnet/tools"
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
export PATH="$PATH:/usr/local/bin"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# zsh keeps PATH and $path synchronized; -U removes duplicate entries while preserving order.
typeset -U path PATH

# Interactive tool integrations. Order matters:
#   1) fzf installs Ctrl-T / Alt-C / Ctrl-R
#   2) Atuin runs after fzf and intentionally takes Ctrl-R.
if (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

if (( $+commands[atuin] )); then
  eval "$(atuin init zsh)"
fi

# Exactly one prompt implementation at a time.
if [[ "$ZSH_PROMPT_ENGINE" == p10k ]]; then
  [[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
elif [[ "$ZSH_PROMPT_ENGINE" == starship ]] && (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
