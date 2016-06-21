Secure Custom Shell Profiles
============================

This repository stores a .bash_profile or similar for everyone in your
organization. It uses Git commit signatures to ensure that nobody inserts
malicious code by gaining unauthorized access to the Git repository. 

A web-of-trust model is employed; most users' public keys reside in this
repository, but every key must be signed be one of a number of "trust roots"
before commits signed by that key are considered trustworthy.

**Note:** all users are trusted equally and may attack one another by
overwriting files. If your users do not fully trust one another, then do not
store any signing keys in this repository and employ only trust roots instead.
Trust roots will need to approve and sign any commits made by end users.

Getting Started
===============

Setting up the profile is a bit involved, requiring three steps. The last step
is fairly involved, but it is critical to the security of this scheme.

Clone Script Repository
-----------------------

Clone this repository into /var/lib/dotfiles.

The first time a given user logs in, her profile will be customized from
the scripts under `profiles/$USER`. If the user does not have a specific
profile, `profiles/_` is used as a callback -- but it must be
cryptographically signed.

Install Bootstrap Hook
----------------------
First audit the source code of the bash bootstrap script in this repo to
satisfy yourself that you trust it. Then copy the script to
`/etc/skel/.bash_profile`. Finally, edit the script in its new location and
remove the `exit 1` from the top of the script as an indication that you
trust it.

(Other shells would follow a similar pattern; pull requests gladly accepted!)

Install Signing Keys
--------------------

The public keys used to sign commits in this repository are stored in this
repository under `keys/`; however, we cannot blindly trust these keys because
an attacker with write access to the repository could insert malicious keys.

We employ a web-of-trust model: certain people within your organization are
entrusted with the ability to sign other peoples' public keys and vouch for
their identity. The public keys of your "trust roots" must be stored elsewhere
than in this repository. The trust roots also need a special GPG command to
bless them with trustworthiness after they are imported.

If you have located your trust roots under `/root/hooray`, you can import and
grant trust in them like so:

```
export GNUPGHOME=/etc/skel/.gnupg
mkdir -p $GNUPGHOME
for pubkey in `ls /root/hooray/*.asc`; do
  gpg --import $pubkey
done
gpg --list-keys --fingerprint --with-colons |
  sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' |
  gpg --import-ownertrust
```

Next, import all of the individual signing keys, which _are_ stored in this
repository but won't be trusted unless they have been signed by one of the
trust roots:

```
for pubkey in `ls /var/lib/dotfiles/keys/*.asc`; do
  gpg --import $pubkey
done
```

Contributing
============

Fork this repository and start hacking!

To reset a machine to its initial state in order to test reinstall, run
the following two commands:

    sudo rm -Rf /var/lib/dotfiles
    exec sudo userdel -rf $USER

Roadmap
-------

1) Keep users from attacking trust roots.

2) Keep users from attacking each other.

