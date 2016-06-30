Keep users from attacking each other
------------------------------------

Scenario 1: Mallory has his own profile in this repository and his pubkey is
legitimately signed by trust roots. He makes signed commits to Alice's profile.

Mitigation 1: Verify that only Alice's key has ever signed any commit made to
her subdir.

Scenario 2: Mallory replaces Alice's public key with his own, then uses his
key to make signed commits to Alice's profile that introduce.

Mitigation 2: Verify that the commit that introduces Alice's key to the
repository is signed by the corresponding private key!
