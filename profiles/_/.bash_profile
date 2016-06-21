# Source bashrc first to get the basics
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

# No-op unless we are running interactively
[ -z "$PS1" ] && return

# Beautiful prompt that changes colors by environment.
# Relies on the RAILS_ENV that we insert into system profile on boot.
case $RAILS_ENV in
  production)
    pcol="01;31m"
    ;;
  staging)
    pcol="01;33m"
    ;;
  *)
    pcol="01;32m"
    ;;
esac
PS1='\[\033[${pcol}\]\u@\h\[\033[00m\]:\[\033[00;34m\]\w\[\033[00m\]\$ '

# Handy Docker aliases
alias dit="docker it"
alias dps="docker ps"
alias di="docker images"
alias drm="docker rm"
alias dsh="docker shell"

# Docker wrapper that automatically jumps thry `sudo` and contains some useful commands.
function docker() {
  effective_docker="sudo /usr/bin/docker"

  if [ "$1" == "shell" -o "$1" == "dude-youre-getting-a-shell" ] # open a bash session in a running container
  then
    entrypoint=$(docker inspect --format={{.Config.Entrypoint}} $2 | sed 's/[][{}]//g')
    $effective_docker exec -t -i $2 $entrypoint /bin/bash -l
  elif [ "$1" == "it" ] # return the ID of the most recently created container
  then
    echo `$effective_docker ps -a | head -n 2 | tail -n 1 | awk '{print $NF}'`
  elif [ "$1" == "debug" ]
  then
    echo "When you are done, PLEASE REMEMBER to detach with Ctrl+P Ctrl+Q"
    echo "If you use Ctrl+C or Ctrl+Z, you will kill your container"
    echo
    echo "The fate of $2 is in your hands; choose wisely..."
    $effective_docker attach $2
  else
    $effective_docker $@
  fi
}
