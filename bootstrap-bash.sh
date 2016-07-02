# Instructions for using this file:
#  0) Never source this file directly from the Git repository!
#  1) Audit source code to verify that it does things securely and to your
#     liking
#  2) When booting a machine:
#       a) clone your user profiles repo into /var/lib/dotfiles
#       b) copy this file into /etc/skel/.bash_profile
#       c) Copy a GPG keyring containing trusted public keys into /var/lib/dotfiles/gpg

# Dotfile customization logic, includes cryptographic integrity checking and
# validation of key trustworthiness. All happens inside a function for easier
# control flow.
__dotfiles_secure__() {
  # Check for user-specific profile, or use default (_).
  if [ -d profiles/$USER ]; then
    subdir=profiles/$USER
    pubkey=keys/$USER
  else
    subdir=profiles/_
    pubkey=keys/_.asc
    needRootTrust=1
  fi

  # Determine ID of the key stored in the pubkey file.
  owner=`gpg $pubkey | grep '^pub' | cut -d ' ' -f 3 | cut -d / -f 2`

  # Determine the last commit that touched the pubkey file and who signed it.
  attestation=`git log -n1 --pretty='format:%h' $pubkey`
  signer=`git log -n1 --pretty='format:%GG' $attestation | grep 'key ID' | grep -oE '[^ ]+$'`

  if [ $? != 0 ]; then
    echo "ERROR: unverified commit signature for $pubkey"
    return 10
  fi

  if [ -n "$needRootTrust" ]; then
    gpg --list-keys --list-options show-uid-validity $signer | grep -q "\[ultimate\]"
  else
    gpg --list-keys --list-options show-uid-validity $signer | grep -q "\[\(full|ultimate\)\] ${user}@localhost"
  fi
  if [ $? == 0 ]; then
    echo "Applying $user profile signed by ($signer)"
    owner=$signer
  else
    echo "ERROR: untrusted attestation (${signer}) of $pubkey - expected a trust root"
    return 11
  fi

  if [ -z "$owner" -o \( "$signer" != "$owner" \) ]; then
    echo "ERROR: untrusted attestation (${signer}) of $pubkey - expected '${owner}'"
    return 12
  fi

  if [ -d $subdir ]; then
    echo "Integrity-check profile"
    cd $subdir

    # Find every commit that has ever touched any file in, or under, this dir.
    # Verify them all and ensure they're signed by the right key.
    all=(`git ls-files | xargs -L 1 git log --pretty='format:%h%n' | sort | uniq`)
    for commit in $all; do
      signer=`git log -n1 --pretty='format:%GG' $commit | grep 'key ID' | grep -oE '[^ ]+$'`

      if [ $? != 0 ]; then
        echo "ERROR: unverified commit signature for ${commit} in ${subdir}"
        return 20
      elif [ "$signer" != "$owner" ]; then
        echo "ERROR: untrusted commit signer (${signer}) of ${commit} in ${subdir} - expected '${owner}'"
        return 21
      fi

      gpg --list-keys --list-options show-uid-validity $signer | grep -Eq "\[\(full|ultimate\)\] ${user}@localhost"
      if [ $? != 0 ]; then
        echo "ERROR: no proof of identity for commit signer (${}) of ${commit}"
        return 22
      fi
    done
  else
    echo "ERROR: missing custom profile; $subdir not found under $PWD"
    return 100
  fi
}

pushd /var/lib/dotfiles

__dotfiles_secure__

if [ $? != 0 ]; then
  echo "Customized profile is disabled for your security; using system default"
fi

popd
