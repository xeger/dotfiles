Secure Custom Shell Profiles
============================

This repository stores a .bash_profile or similar for everyone in your
organization. It uses Git commit signatures to ensure that nobody inserts
malicious code by gaining unauthorized access to the Git repository.

A hierarchical model is employed; most users' public keys reside in this
repository, but every key must be signed be one of a number of "trust roots"
before commits signed by that key are considered trustworthy. The public keys
of trust roots are stored out-of-band from this repository and must be added
to the relevant GPG keyring by hand.

Keys are correlated to profile directories by filename: the file `keys/foo.asc`
must be used to sign _every_ commit that touches _any_ file under `profiles/foo`
and if any unsigned or other-signed file is discovered, the user will see an
error message warning of a possible security breach and the system default
profile will be loaded instead.

Getting Started
===============

Setting up the profile is a bit involved, requiring three steps. The last step
is fairly complex, but it is critical to the security of this scheme. Please
proceed with caution!


Clone Script Repository
-----------------------

Clone this repository into /var/lib/dotfiles.

The first time a given user logs in, her profile will be customized from
the scripts under `profiles/$USER`. If the user does not have a specific
profile, `profiles/_` is used as a callback -- but it must be
cryptographically signed.


Install Trust Roots
-------------------

We employ a hierarchical trust model: certain people within your organization
are entrusted with the ability to sign other peoples' public keys and vouch
for their identity, which allows us to trust that person to commit to her own
profile directory (but not to others').

The trust roots also vouch for the login identity of each public key; in order
to customize her profile, a trust root must place Alice's public key in a file
named `keys/alice.asc` and sign the commit that intorduces that file; this is
an attestation that the key belongs to Alice and is trusted to sign all of the
files under `profiles/alice`.gd

The public keys of your "trust roots" must be stored elsewhere than in this
repository. The trust roots also need a special GPG command to bless them with
trustworthiness after they are imported.

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

This ensures that all users will bestow "ultimate" trust in the trust roots
because their GnuPG keyring will be initialized from the master keyring under
/etc/skel.

Setup Default Profile
---------------------

If a user logs in and no custom profile is found under `profiles/`, an
anonymous profile named `_` is used; however, this profile must still be
cryptographically signed; the file `keys/_.asc` is used as the "default signer"
who will vouch for the default profile.

Any of the trust roots may emplace his own public key in `_.asc` and setup the
default profile as if he were a normal user.

Install Bootstrap Hook
----------------------
First audit the source code of the bash bootstrap script in this repo to
satisfy yourself that you understand and trust it. Then copy the script to
`/etc/skel/.bash_profile`. Finally, edit the script in its new location and
remove the `exit 1` from the top of the script as an indication that you
trust it.

(Other shells would follow a similar pattern; pull requests gladly accepted!)

Contributing
============

Fork this repository and start hacking!

To reset a machine to its initial state in order to test reinstall, run
the following two commands:

    sudo rm -Rf /var/lib/dotfiles
    exec sudo userdel -rf $USER

Security
========

Threat Model
------------

#### Malicious commit/tampemring

Scenario: Mallory has his own profile in this repository and his pubkey is
legitimately signed by trust roots. He makes signed commits to Alice's profile
or tampers with repository files.

Mitigation: Verify that only Alice's key has ever signed any commit made to
her subdir and that all signatures are valid. (DONE)

#### Identity theft

Scenario: Mallory replaces Alice's public key with his own, then uses his
key to make signed commits to Alice's profile.

Mitigation: Require trust roots to sign the commit that adds/modifies Alice's
public key. ()

#### Defaults hijacking

Scenario: Mallory tampers with the contents of `profiles/_/*` in order to
attack users whose profile has not been customized.

Mitigation: Verify that _.asc was committed by one of the trust roots and
_not_ by itself. (DONE)
