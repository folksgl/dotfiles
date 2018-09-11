# bootstrap.sh installs things and does some general setup to get us ready to go.

cd "$(dirname "$0")/.."
DOTFILES_ROOT=$(pwd -P)

set -e

echo ''

info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

user () {
  printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}

success () {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

fail () {
  printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit
}

setup_gitconfig () {
  if ! [ -f ~/.dotfiles/gitconfig.local.symlink ]
  then
    info 'setup gitconfig'

    git_credential='cache'
    if [ "$(uname -s)" == "Darwin" ]
    then
      git_credential='osxkeychain'
    fi

    user ' - What is your github author name?'
    read -e git_authorname
    user ' - What is your github author email?'
    read -e git_authoremail

    sed -e "s/AUTHORNAME/$git_authorname/g" -e "s/AUTHOREMAIL/$git_authoremail/g" -e "s/GIT_CREDENTIAL_HELPER/$git_credential/g" ~/.dotfiles/gitconfig.local.symlink.example > ~/.dotfiles/gitconfig.local.symlink

    success 'gitconfig'
  fi
}


link_file () {
  local src=$1 dst=$2

  local overwrite= backup= skip=
  local action=

  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]
  then

    if [ "$overwrite_all" == "false" ] && [ "$backup_all" == "false" ] && [ "$skip_all" == "false" ]
    then

      local currentSrc="$(readlink $dst)"

      if [ "$currentSrc" == "$src" ]
      then

        skip=true;

      else

        user "File already exists: $dst ($(basename "$src")), what do you want to do?\n\
        [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all?"
        read -n 1 action

        case "$action" in
          o )
            overwrite=true;;
          O )
            overwrite_all=true;;
          b )
            backup=true;;
          B )
            backup_all=true;;
          s )
            skip=true;;
          S )
            skip_all=true;;
          * )
            ;;
        esac

      fi

    fi

    overwrite=${overwrite:-$overwrite_all}
    backup=${backup:-$backup_all}
    skip=${skip:-$skip_all}

    if [ "$overwrite" == "true" ]
    then
      rm -rf "$dst"
      success "removed $dst"
    fi

    if [ "$backup" == "true" ]
    then
      mv "$dst" "${dst}.backup"
      success "moved $dst to ${dst}.backup"
    fi

    if [ "$skip" == "true" ]
    then
      success "skipped $src"
    fi
  fi

  if [ "$skip" != "true" ]  # "false" or empty
  then
    ln -s "$1" "$2"
    success "linked $1 to $2"
  fi
}

install_dotfiles () {
  info 'installing dotfiles'

  local overwrite_all=false backup_all=false skip_all=false

  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.symlink' -not -path '*.git*')
  do
    dst="$HOME/.$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
  sudo apt install x11-xkb-utils -y &> /dev/null
}

setup_vim () {
  info 'Customizing Vim'

  CUR_DIR=$PWD
  echo "cur dir is $CUR_DIR"

  COLORS_DIR=~/.vim/colors/
  echo "colors dir is $COLORS_DIR"
  THEME=~/.dotfiles/vim_themes/spring-night.vim

  if [ ! -d "$COLORS_DIR" ]
  then
      echo "making colors dir"
      mkdir -p $COLORS_DIR
  fi
  echo "copying theme into colors directory"
  cp $THEME $COLORS_DIR
  cd $CUR_DIR

  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim &> /dev/null
  echo "installed plug"
  
  vim +PlugInstall +PlugUpdate +qall

  echo "should have installed plugins"

  success 'Vim Customization'
}

check_permission() {
  USER=$(whoami)
  if [ ! $USER = "root" ]; then
    echo "Please execute bootstrap script as root." 
    echo "There may be some tools to install, and files to edit"
    echo "that will need higher privilage access."
    echo ""
    fail 'Insufficient Permission'
    exit
  fi
  success 'Permissions Check'
}

setup_tools() {
  # Curl
  if [ -z $(command -v curl) ]; then
    apt-get install curl -y &> /dev/null
    success 'Curl Installed'
  fi

  # Vim
  if [ -z $(command -v vim) ]; then
    apt-get install vim -y &> /dev/null
    success 'Vim Installed'
  fi
}

setup_zsh() {

    sudo apt-get install zsh -y &> /dev/null 
    sudo apt-get install fontconfig -y &> /dev/null

    #git clone https://github.com/powerline/fonts.git --depth=1
    #cd fonts
    #./install.sh
    #cd ..
    #rm -rf fonts
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    sed -i 's/blue/red/g' ~/.oh-my-zsh/themes/agnoster.zsh-theme
    #source ~/.zshrc
    sudo chsh -s /bin/zsh $(whoami)

}

check_permission
setup_tools
setup_vim
setup_gitconfig
install_dotfiles
setup_zsh

echo ''
echo '  All installed!'
