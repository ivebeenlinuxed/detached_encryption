#!/bin/bash


#Setup the devices
MAIN_PD=/dev/sda
REMOVABLE_PD=/dev/sdb

#Setup a temp folder
TMP_DIR=/tmp/

#Setup the mount point for debootstrap
MAIN_MP=/media/main_mp

#Setup the luks header tmp file location
LUKS_HDR=lukshdr.img

CRYPTKEY="password"

#Setup the init script
INIT_SCRIPT=$TMP_DIR/init.sh


#If you want to boot into a dev environment
if [ 1 -eq 0 ]; then
	REMOVABLE_PART="/dev/sdb1"
	mkdir /media/test
	mount $REMOVABLE_PART /media/test
	cp /media/test/luks* /tmp/
	umount /media/test
	echo $CRYPTKEY | cryptsetup luksOpen $MAIN_PD --header $TMP_DIR/$LUKS_HDR main_crypt
	pvscan
	lvchange -ay /dev/vg_crypt/lvroot
	mkdir $MAIN_MP
	mount /dev/vg_crypt/lvroot $MAIN_MP
	mount /dev/sdb1 $MAIN_MP/boot
	mount proc -t proc $MAIN_MP/proc
	mount /dev -o bind $MAIN_MP/dev
	mount /sys -o bind $MAIN_MP/sys
	chroot $MAIN_MP
	exit
fi;

#echo "deb http://http.kali.org/kali sana main non-free contrib" > /etc/apt/sources.list
#echo "deb http://security.kali.org/kali-security sana/updates main contrib non-free" >> /etc/apt/sources.list

#Create the LUKS header
dd if=/dev/zero bs=512 count=20480 > $TMP_DIR/$LUKS_HDR

#Install extra host requirements
apt-get update
apt-get install -y kpartx debootstrap

#Setup crypt
echo $CRYPTKEY | cryptsetup luksFormat $MAIN_PD \
	--header $TMP_DIR/$LUKS_HDR \
	--align-payload=0

#Open the crypt
echo $CRYPTKEY | cryptsetup luksOpen $MAIN_PD --header $TMP_DIR/$LUKS_HDR main_crypt

#Format the removable part of the disk
dd if=/dev/zero of=$REMOVABLE_PD bs=1024 count=5000
fdisk $REMOVABLE_PD <<EOF
o
n
p
1


t
b
a
p
w
EOF

REMOVABLE_PART=$(dirname $REMOVABLE_PD)/$(kpartx -l $REMOVABLE_PD | grep $REMOVABLE_PD | awk '{print $1}')

mkfs.vfat $REMOVABLE_PART

#Setup an LVM in the encrypted section
pvcreate /dev/mapper/main_crypt
pvscan
pvdisplay
vgcreate vg_crypt /dev/mapper/main_crypt
lvcreate -l 80%VG -n lvroot vg_crypt
lvdisplay

#Format the root partition
mkfs.ext4 /dev/vg_crypt/lvroot

#Create the mount point if it does not exist
if [ ! -d $MAIN_MP ]; then
	mkdir $MAIN_MP;
fi;

#Mount the root partition
mount /dev/vg_crypt/lvroot $MAIN_MP

#Create a folder for the (removable) boot partition
mkdir $MAIN_MP/boot

#Mount the boot partition
mount $REMOVABLE_PART $MAIN_MP/boot

#Install the basics
cp vivid /usr/share/debootstrap/scripts/vivid
cp ubuntu-archive-keyring.gpg /usr/share/keyrings/
debootstrap vivid $MAIN_MP

#Get chroot setup
mount proc -t proc $MAIN_MP/proc
mount /dev -o bind $MAIN_MP/dev
mount /sys -o bind $MAIN_MP/sys

#Install the extras (LVM and cryptsetup support)
chroot $MAIN_MP apt-get update
chroot $MAIN_MP apt-get install -y lvm2 cryptsetup cryptsetup-bin

cp $TMP_DIR/$LUKS_HDR $MAIN_MP/boot/lukshdr.img

#Edit the cryptab file
echo "main_crypt $MAIN_PD none luks,header=/boot/lukshdr.img" >> $MAIN_MP/etc/crypttab

#Edit fstab
echo "/dev/vg_crypt/lvroot / ext4 defaults 0 0" >> $MAIN_MP/etc/fstab
echo "$REMOVABLE_PART /boot vfat defaults 0 0" >> $MAIN_MP/etc/fstab

#Install a bootloader and kernel
chroot $MAIN_MP apt-get update
chroot $MAIN_MP apt-get install -y grub-pc linux-signed-image-generic
#chroot $MAIN_MP grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub --recheck
chroot $MAIN_MP grub-install $REMOVABLE_PD --recheck

#Stop pesky services that automatically started
chroot $MAIN_MP /etc/init.d/thermald stop
chroot $MAIN_MP /etc/init.d/dbus stop
chroot $MAIN_MP /etc/init.d/lvm2 stop


#Patch up cryptroot
patch $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptroot < cryptroot.patch
patch $MAIN_MP/usr/share/initramfs-tools/hooks/cryptroot < crypthook.patch

#Create a new initramfs script to load the header
cp cryptstarter $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
echo "mkdir /bootpart" >> $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
echo "mkdir /boot" >> $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
echo "mount $REMOVABLE_PART /bootpart" >> $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
echo "cp /bootpart/lukshdr.img /boot/" >> $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
echo "cd /" >> $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
echo "umount $REMOVABLE_PART" >> $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter
chmod 0777 $MAIN_MP/usr/share/initramfs-tools/scripts/local-top/cryptstarter

#Rebuild the initrd
chroot $MAIN_MP update-initramfs -c -k all


