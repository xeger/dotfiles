# Instructions for using this file:
#  0) Never, EVER source this file directly from a Git repository
#  1) Audit source code to verify that it does things securely
#  2) Remove the `exit 1` line below to indicate that you trust this script
#  3) When booting a machine:
#       a) copy altered version of this file into /etc/skel/.bash_profile
#       b) clone your user profiles repo into /var/lib/dotfiles
#       c) Copy a GPG keyring containing trusted public keys into /var/lib/dotfiles/gpg

exit 1 # TODO: remove this line after auditing source, befor copying into /etc/skel

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Check for user-specific profile, or use default (_).
pushd /var/lib/dotfiles
if [ -d profiles/$USER ]; then
  subdir=profiles/$USER
else
  subdir=profiles/_
fi

if [ -d $subdir ]; then
  echo "First login: customizing profile"
  cd $subdir

  # Find all of the commits that touched any file in, or under, this dir.
  # Determine their signature status and filter by those that are anything other
  # than "Good."
  untrusted=(`git ls-files | xargs -L 1 git log -n1 --pretty='format:%G?:%h%n' | sort | uniq | grep -E '^[^G]'`)

  # Do that funky copying thing, or kvell at the user about untrusted commits.
  if [  ${#untrusted[@]} == 0 ]; then
    shopt -s dotglob
    cp -R * $HOME/
    if [ -f $HOME/.bash_profile ]; then
      . $HOME/.bash_profile
    fi
  else
    echo "ERROR: files in $PWD were touched by ${#untrusted[@]} untrusted commits"
    echo "Customized profile is disabled; please "
    echo
    echo "Untrusted commits (B=bad signature, U=untrusted, N=unsigned):"
    for c in ${untrusted[@]}; do
      echo $c
    done
    . /etc/profile
  fi
else
  echo "ERROR: missing custom profile; $subdir not found under $PWD"
  . /etc/profile
fi

popd
