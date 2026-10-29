# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# ZSH_THEME="robbyrussell"
#ZSH_CUSTOM="$ZSH/custom"
ZSH_THEME="spaceship"
#ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git)
plugins=(
  git
  kubectl
  kube-ps1
  history-substring-search
  colored-man-pages
  zsh-syntax-highlighting
  terraform
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# SPACESHIP CONFIG

export SPACESHIP_PROMPT_ORDER=(
    # time          # Time stampts section
    user          # Username section
    dir           # Current directory section
    host          # Hostname section
    git           # Git section (git_branch + git_status)
    # hg            # Mercurial section (hg_branch  + hg_status)
    # package       # Package version
    # node          # Node.js section
    # ruby          # Ruby section
    # elm           # Elm section
    # elixir        # Elixir section
    # xcode         # Xcode section
    # swift         # Swift section
    golang        # Go section
    # php           # PHP section
    # rust          # Rust section
    # haskell       # Haskell Stack section
    # julia         # Julia section
    # docker        # Docker section
    # aws           # Amazon Web Services section
	# gcloud          # gcloud section
    venv          # virtualenv section
    # conda         # conda virtualenv section
    #pyenv         # Pyenv section
    # dotnet        # .NET section
    # ember         # Ember.js section
    kubectl        # Kubectl context section
    terraform     # Terraform workspace section
    # exec_time     # Execution time
    line_sep      # Line break
    # battery       # Battery level and status
    #vi_mode       # Vi-mode indicator
    # jobs          # Background jobs indicator
    exit_code     # Exit code section
    char          # Prompt character
)
export SPACESHIP_HOST_SHOW=true
export SPACESHIP_DIR_TRUNC=0
export SPACESHIP_DIR_COLOR=199ff00af
export SPACESHIP_DIR_TRUNC_REPO=false
export SPACESHIP_KUBECONTEXT_COLOR=166d75f00
SPACESHIP_KUBECTL_SHOW=true
SPACESHIP_KUBECONTEXT_SHOW=true
SPACESHIP_KUBECTL_VERSION_SHOW=false
# Disable the % of EOL in a partial line
export PROMPT_EOL_MARK=''

# Got to use vim as editor
export EDITOR=vim

# My aliases
alias cdp="cd ~/projects"
alias cdg="cd ~/go/src/github.com/NissesSenap"
alias intel=/opt/idea-IC-231.9011.34/bin/idea.sh
alias code=code-insiders

#Yarn
PATH="$PATH:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin"

# golang
export GOPATH=$HOME/go

export PATH=$PATH:$HOME/bin:$GOPATH/bin

# Go needed to auto download bin I think...
export GO111MODULE=auto go get

# CRC (openshift)
export PATH="/home/edvin/.crc/bin:$PATH"

# PYTHON bin path
export PATH="/home/edvin/.local/bin:$PATH"

# buildkit enabled by default
export DOCKER_BUILDKIT=1

# kubernetes krew

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# kubebuilder

export PATH=$PATH:"/usr/local/kubebuilder/bin"

cheat () {
	curl cht.sh/$1
}

# Stores all providers in 1 location, makes tf quicker
export TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache

# source tkn zsh completion
#source ~/.local/completion/tekton.sh

# Add direnv function
# https://direnv.net/ create a .envrc file in your folder and get env
eval "$(direnv hook zsh)"

autoload -U +X bashcompinit && bashcompinit
autoload -U compinit; compinit
#complete -o nospace -C /usr/local/bin/odo odo

source ~/.local/completion/*
