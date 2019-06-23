#!/bin/sh

# Wake/Sleep Backup - 'wake up' drive, rsync, poweroff

# NOTES:
#  hdparm: standby timeout: -S 120 (10min), check: -C
#  smart: smartctl -i -n standby
#  time: "time rsync <...>" for summary (bashism)
#  rsync: -i itemize changes, -v erbose, -q uiet, -n dryrun
#  info: udiskctl info -b /dev/sdX, udevadm info -p /sys/block/sdX
#  rm, add: - udiskctl poweroff, bind/unbind ?hci-pci
#           - echo 1 > /sys/block/sdX/device/delete, echo 1 > sdX/device/rescan
#  rescan:  - rescan-scsi-bus.sh

# EXAMPLE:
#   BKP_DIRS="/etc/ /root/ /home/ /opt/ /usr/local/bin/"

BKP_DIRS="/"
RSYNC="rsync -aA --info=flist0,name0,progress2,stats2 --progress --stats"
DST_UUID="134cee9e-1620-497e-95f3-56c625f1d22d"   # dst dev uuid (backup drive)
DST_MNT="/mnt/bkp"
EXCL="--exclude=/proc/ --exclude=/sys/ --exclude=/jail/ --exclude=/lost+found/ --exclude=/mnt/ --exclude=/run/ --exclude=/tmp/"
LOG="/var/log/wsbkp.log"
OUT="/dev/null"   # stdout
FORCE=0           # force even if dev not found

#func_dev() { DST_DEV="$( blkid | grep "$DST_UUID" | cut -d: -f1 )"; if [ "$DST_DEV" = "" ] && [ "$FORCE" -eq 0 ]; then echo "ERROR: Device \"$DST_UUID\" not found, exiting..."; exit 1; fi; }
func_dev() { DST_DEV="$( blkid -U "$DST_UUID" )" || { if [ "$FORCE" -eq 0 ]; then echo "ERROR: Device \"$DST_UUID\" not found, exiting..."; exit 1; fi; }; }
func_wake() { { hdparm -C "/dev/disk/by-uuid/$DST_UUID"; } || { echo "ERROR: Drive with UUID $DST_UUID did not wake up, exiting..."; exit 1; }; }
func_sleep() { func_dev && if findmnt -n "$DST_DEV" | grep -q " $DST_DEV"; then echo "WARNING: \"$DST_DEV\" is mounted, umount it first"; else hdparm -Y "$DST_DEV"; fi; }
func_mnt() {
  if [ -z "$DST_MNT" ]; then func_dev && { TMP="$( basename "$DST_DEV" )"; if echo "$TMP" | grep -q "^sd[a-z]"; then DST_MNT="/mnt/${TMP}"; fi; }; fi
  [ ! -d "$DST_MNT" ] && mkdir "$DST_MNT"; func_dev && mount "$DST_DEV" "$DST_MNT" && echo "* INFO: mounted \"$DST_DEV\" \"$DST_MNT\""
}
func_umnt() { umount "$DST_MNT"; }
func_poff() { func_dev && { command -v udisksctl >/dev/null 2>&1 && udisksctl power-off --no-user-interaction -b "$DST_DEV" || echo "WARNING udiskctl not found"; exit 1; }; }
func_pon() { 
  # http://billauer.co.il/blog/2013/02/usb-reset-ehci-uhci-linux/ #shopt -s nullglob
  for i in /sys/bus/pci/drivers/?hci-pci ; do
    if ! cd "$i" ; then echo "ERROR: Failed to change directory to $i"; exit 1; fi
    echo "* INFO: Resetting devices from $i..."
    for j in ????:??:??.? ; do printf "%s" "$j" > unbind; printf "%s" "$j" > bind; sleep 1; done
  done
}
func_list () {
  FORCE=1; func_dev; echo; echo "DST_UUID: \"$DST_UUID\" DST_DEV: \"$DST_DEV\""; echo
  echo "fdisk :";  fdisk -l 2>/dev/null|grep "Disk /dev/sd[b-z]"; echo
  echo "blkid :"; blkid | grep -Ev "$(blkid /dev/sda -s PTUUID | cut -d\" -f2)|/dev/(loop|mapper)|swap|LUKS"; echo
  echo "findmnt :"; findmnt -nr | grep -Ev '/(sda|pts)|^/(proc|run|sys|boot|jail)|tmpfs|overlay|fuseblk' | grep -E "$DST_DEV|$DST_MNT"; echo
  echo "/sys/devices :"
  find /sys/devices -name block -regex '.*usb.*' -exec sh -c ' 
    echo "$1: $(ls "$1")"; 
    echo "$(echo "$1"/../model|sed s@"$1"/../@\ @): $(cat "$1"/../model 2>/dev/null )"' sh "{}" \; | \
  sed -e 's|/sys/devices/pci|/pci|g' -e 's/0000:00[/:]\?//g'; echo
  echo "/sys/block :"
  for i in /sys/block/sd[b-z]; do
    echo "$i device/state: $(cat "$i"/device/state 2>/dev/null) power/control: $(cat "$i"/power/control 2>/dev/null)"
  done; echo
  echo "/sys/bus/pci/drivers :"
  find /sys/bus/pci/drivers/?hci-pci/????:??:??.? -printf "%f\n" | sed -e 's|0000:00:|  |g'; echo
}
func_help () {
  printf "USAGE: %s -[f|h|w|s|m|o|p|u]|<dirs to backup>\n\t" "$( basename "$0" )"
  printf "[-p]|[-o] power on/off drive\n\t" 
  printf "[-w]|[-s] wakeup/sleep drive\n\t" 
  printf "[-m]|[-u] mount/umount drive\n\t"
  printf "[-l] list drive, [-f] force\n\t"
  printf "<dirs to backup> overwrites var in script\n"
}

if printf -- "%s" "$*" | grep -q -- '\-h'; then func_help; exit
elif printf -- "%s" "$*" | grep -q -- '\-f'; then FORCE=1; shift
elif printf -- "%s" "$*" | grep -q -- '\-s'; then func_sleep; exit
elif printf -- "%s" "$*" | grep -q -- '\-w'; then func_wake; exit
elif printf -- "%s" "$*" | grep -q -- '\-m'; then func_mnt; exit
elif printf -- "%s" "$*" | grep -q -- '\-u'; then func_umnt; exit
elif printf -- "%s" "$*" | grep -q -- '\-o'; then func_poff; exit
elif printf -- "%s" "$*" | grep -q -- '\-p'; then func_pon; exit
elif printf -- "%s" "$*" | grep -q -- '\-l'; then func_list; exit
elif  printf -- "%s" "$*" | grep -q -- '\-'; then func_help; exit
elif [ "$*" != "" ]; then BKP_DIRS="$&"; fi

echo
blkid -U "$DST_UUID" || { echo "* [$(date +%F_%T )] Powering on backup drive (UUID=$DST_UUID)..."; func_pon; }
func_dev && { echo "* [$(date +%F\ %T )] Using backup drive \"$DST_DEV\" (UUID=$DST_UUID)"; }
if [ ! -d "$DST_MNT" ]; then mkdir "$DST_MNT" || { echo "ERROR: Could not create ${DST_MNT}"; exit 1; }; fi
func_mnt || { echo "ERROR: Could not mount \"$DST_DEV\" \"$DST_MNT\", exiting..."; exit 1; }; echo
if [ -d "$DST_MNT" ]; then
  if findmnt -n "$DST_MNT" | grep -q " $DST_DEV"; then

    echo "* Backing up using \"$RSYNC\"..."
    echo "* Dir(s): \"$BKP_DIRS\""
    echo "* Target drive: \"$DST_DEV\" mounted on \"$DST_MNT\" ($DST_UUID)"
    echo "* Exclude: $( echo -- "$EXCL" | sed 's/--exclude=//g' )"; echo

    for i in $BKP_DIRS; do
      if [ -d "$i" ]; then
        MSG="sleeping 10s... CTRL-C TO ABORT"
        if ! echo "$i" | grep -q '^/'; then echo "* WARNING: \"$i\" has no leading slash, $MSG"; echo; sleep 10; fi
        if ! echo "$i" | grep -q '/$'; then echo "* WARNING: \"$i\" has no trailing slash, $MSG"; echo; sleep 10; fi
        echo "[$(date +%F\ %T )] SOURCE DIR: \"$i\" DEST: \"${DST_MNT}${i}\"" | tee -a "$LOG"
        if [ ! -d "${DST_MNT}${i}" ]; then
          echo "Creating ${DST_MNT}${i}"; mkdir -p "${DST_MNT}${i}" || echo "ERROR: Could not create ${DST_MNT}${i}"
        fi
        $RSYNC $EXCL "$i" "${DST_MNT}${i}" >"$OUT" 2>&1
      else
        echo "ERROR: \"$i\" does not exist"
      fi
      echo
     done && { echo "* Listing \"$DST_MNT\""; ls -la "$DST_MNT"; echo;
               echo "[$(date +%F\ %T )] Done. Powering off" | tee -a "$LOG"; \
               sleep 30 && func_umnt && func_poff; } || \
             { echo "WARNING: Check if drive is unmounted and powered down"; }
  else
    echo "ERROR: mount \"$DST_MNT\" not found, exiting"; exit 1
  fi
else
  echo "ERROR: \"$DST_MNT\" does not exists, exiting..."; exit 1
fi
echo
if [ -d "$DST_MNT" ]; then rmdir "$DST_MNT" || echo "NOTICE: could not remove dir \"$DST_DIR\""; fi
exit 0
