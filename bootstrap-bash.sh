# Instructions for using this file:
#  0) Never source this file directly from the Git repository!
#  1) Audit source code to verify that it does things securely and to your
#     liking
#  2) When booting a machine:
#       a) clone your user profiles repo into /var/lib/dotfiles
#       b) copy this file into /etc/skel/.bash_profile
#       c) Copy a GPG keyring containing trusted public keys into /var/lib/dotfiles/gpg

# Print a nice message to the screen
say() {
  echo "dotfiles: $*"
}

# Dotfile customization logic, includes cryptographic integrity checking and
# validation of key trustworthiness. All happens inside a function for easier
# control flow.
dotfiles() {
  # Check for user-specific profile, or use default (_).
  if [ -d profiles/$USER ]; then
    user=$USER
  else
    user=_
  fi

  subdir="profiles/$user"
  pubkey="keys/${user}.asc"

  # Determine ID of the key stored in the pubkey file.
  owner=`gpg $pubkey | grep '^pub' | cut -d ' ' -f 3 | cut -d / -f 2`

  # Determine the last commit that touched the pubkey file, and who signed it.
  attestation=`git log -n1 --pretty='format:%h' $pubkey`
  attester=`git log -n1 --pretty='format:%GG' $attestation | grep 'key ID' | grep -oE '[^ ]+$'`
  if [ $? != 0 ]; then
    say "ERROR: unverified commit signature for $pubkey"
    return 10
  fi

  # Ensure pubkey file was signed by a trust root as an attestation that the
  # key belongs to the user after whom the file is named.
  gpg --list-keys --list-options show-uid-validity $attester | grep -q '\[ultimate\]'
  if [ $? == 0 ]; then
    say "Trusting $pubkey signed by $owner as attested by $attester"
    gpg --import $pubkey > /dev/null 2>&1
    gpg --list-keys --fingerprint --with-colons $owner | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust
  else
    say "ERROR: untrusted attestation of $pubkey validity - $attester is not a trust root"
    return 11
  fi

  if [ -d $subdir ]; then
    # Find every commit that has ever touched any file in, or under, this dir.
    # Verify them all and ensure they're signed by the right key.
    all=`git ls-files | xargs -L 1 git log --pretty='format:%h%n' | sort | uniq`

    say "Integrity-checking files in $subdir"
    cd $subdir

    for commit in $all; do
      signer=`git log -n1 --pretty='format:%GG' $commit | grep 'key ID' | grep -oE '[^ ]+$'`

      if [ $? != 0 ]; then
        say "ERROR: unverified commit signature for $commit in $subdir"
        git log -n1 --pretty='format:%GG' $commit
        return 20
      fi

      pat='\[ultimate\]'
      gpg --list-keys --list-options show-uid-validity $signer | grep -Eq $pat
      if [ $? != 0 ]; then
        say "ERROR: untrusted signer (${signer}) of commit ${commit} in ${subdir}"
        say "Expected ultimate trust but got the following:"
        gpg --list-keys --list-options show-uid-validity $signer
        return 22
      fi
    done

    shopt -s dotglob
    say "Installing ${USER}'s profile to $HOME"
    cp -Rf * $HOME
  else
    say "ERROR: missing custom profile; $subdir not found under $PWD"
    return 30
  fi
}

if [ -z "$DOTFILES_SECURE" ]; then
  export GNUPGHOME=$HOME/.gnupg-dotfiles
  cd /var/lib/dotfiles
  dotfiles
  result=$?
  unset GNUPGHOME
  cd ~

  if [ $result == 0 ]; then
    # Exec to get rid of local vars, functions, and other gunk we've defined.
    # Guard against infinite recursion by leaving _one_ sign we've been here/
    export DOTFILES_SECURE=1
    exec bash -l
  else
    say "Customized profile is disabled for your security; using system default"
  fi
else
  say "ERROR: recursive invocation of dotfiles; does your profile dir contain .bash_profile?"
fi
