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
  fi

  # Determine key ID of the person who owns the profile (and must vouch for
  # all commits and files in the profile's subdir).
  owner=`gpg $pubkey | grep '^pub' | cut -d ' ' -f 3 | cut -d / -f 2`

  # Ensure owner's self-attestation of their own pubkey by virtue of having
  # signed the commit that added the file to the repository.
  attestation=`git log -n1 --pretty='format:%h' $pubkey`
  signer=`git verify-commit $commit 2>&1 | grep 'key ID' | grep -oE '[^ ]+$'`
  if [ $? != 0 ]; then
        echo "ERROR: unverified commit signature for $pubkey"
        return 10
  elif [ -z "$owner" -o \( "$signer" != "$owner" \) ]; then
        echo "ERROR: untrusted signer (${signer}) of $pubkey - expected '${owner}'"
        return 11
  fi

  if [ -d $subdir ]; then
    echo "First login: customizing profile"
    cd $subdir

    # Find every commit that has ever touched any file in, or under, this dir.
    # Verify them all and ensure they're signed by the right key.
    all=(`git ls-files | xargs -L 1 git log --pretty='format:%h%n' | sort | uniq`)
    for commit in $all; do
      signer=`git verify-commit $commit 2>&1 | grep 'key ID' | grep -oE '[^ ]+$'`

      if [ $? != 0 ]; then
        echo "ERROR: unverified signature for ${commit} in ${subdir}"
        return 20
      elif [ "$signer" != "$owner" ]; then
        echo "ERROR: untrusted signer (${signer}) of ${commit} in ${subdir} - expected '${owner}'"
        return 21
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
  . /etc/profile
fi

popd
