Encryption - Supercharged!
==========================

Encryption as a concept is great - it allows us to store information securely and
know that our privacy is being protected. However, supposing that some NSA organisation
did have some magic programs that can break it, what can we do to protect our data further.

The answer: Plausable Deniability

Did you know that, although the LUKS encryption system is secure, it marks up
the target with a big "this is really secure" header? It tells the system some key
information, and also stores the encryption algorithm - a key part needed to decrypt
the data inside.

This script takes encryption one step further. It puts all the plain text
data on a removable pen drive, as well as the bootloader, and leaves on disk nothing
more than seemingly random data!

Yes, with this script, your disk will look like nothing more than random data.
Statistically there is no way to prove there IS anything on the disk! And you take
your boot scripts with you - nothing left behind with your laptop!

How do I use this?
------------------

This script works by installing through a live CD. Boot Kali Linux 2.0 on a spare disk,
download this repo and run the "pd.sh" script. Everything else is automatic.

The script

- Patches the cryptroot initramfs-tools script/hook to enable detached headers
- Adds a new file (cryptstarter) which locates the luks header and makes it available
- The vivid debootstrap script (and keyring) so you can install Ubuntu Vivid from Kali
 
Steps

1. Download and boot to Kali

2. Download this repo

3. Edit values in pd.sh to point to your pen drive, hard disk and set your crypt password

4. Run ./pd.sh
