#!/bin/sh

################################################################################
# Wake/Sleep Backup - 'wakes up' usb drive, rsyncs and powers off              #
################################################################################

# Example:
#   DST_UUID="abc12345-1234-1234-1234-aaaabbbbcccc" (see 'blkid' command)
#   BKP_DIRS="/etc/ /root/ /home/ /opt/ /usr/local/bin/"

DST_UUID="d99a6fe1-3216-4b01-adba-a44fa360b50b" # uuid of backup device
DST_MNT="/mnt/bkp"                              # dst/target path
BKP_DIRS="/"                                    # dirs to backup
EXCL_DIRS="
  --exclude=/proc/
  --exclude=/sys/
  --exclude=/lost+found/
  --exclude=/mnt/
  --exclude=/run/
  --exclude=/tmp/
"
RSYNC="rsync -aA --info=flist0,name0,progress2,stats2 --progress --stats"
LOG="/var/log/wsbkp.log"
OUT="/dev/null" # stdout
FORCE=0         # force even if dev not found

# END OF CONFIG ################################################################

# Helper function to check if device exists before sleep/mount/list
func_dev() {
  #  DST_DEV="$( blkid | grep "$DST_UUID" | cut -d: -f1 )"
  #  if [ "$DST_DEV" = "" ] && [ "$FORCE" -eq 0 ]; then
  #    echo "! ERROR: Device \"$DST_UUID\" not found, exiting..."
  #    exit 1
  #  fi
  DST_DEV="$( blkid -U "$DST_UUID" )" || { \
    if [ "$FORCE" -eq 0 ]; then
      printf "! ERROR: Device \"%s\" not found, exiting...\n" "$DST_UUID"
      exit 1
    fi
  }
}

func_wake() {
  hdparm -C "/dev/disk/by-uuid/$DST_UUID" || { \
    printf "! ERROR: Drive with UUID %s did not wake up, exiting...\n" "$DST_UUID"
    exit 1
  }
}

func_sleep() {
  func_dev && if findmnt -n "$DST_DEV" | grep -q " $DST_DEV"; then
    printf "> WARNING: \"%s\" is mounted, umount it first\n" "$DST_DEV"
  else
    hdparm -Y "$DST_DEV"
  fi
}

# Verify drive and mount
func_mnt() {
  # in case var DST_MNT is empty generate it using device name (/mnt/sdx)
  if [ -z "$DST_MNT" ]; then
    func_dev && { \
      TMP="$( basename "$DST_DEV" )"
      if echo "$TMP" | grep -q "^sd[a-z]"; then
        DST_MNT="/mnt/${TMP}"
      fi
    }
  fi
  if [ ! -d "$DST_MNT" ]; then
    mkdir "$DST_MNT"
  fi
  func_dev && \
  mount "$DST_DEV" "$DST_MNT" && \
  printf -- "- INFO: mounted \"%s\" \"%s\"\n" "$DST_DEV" "$DST_MNT"
}

func_umnt() { umount "$DST_MNT"; }


# Power on using usb host controller interface (xchi, ehci, ohci)
func_power_on() {
  #shopt -s nullglob
  for i in /sys/bus/pci/drivers/?hci-pci ; do
    cd "$i" || { \
      printf "! ERROR: Failed to change directory to %s\n" "$i"
      exit 1
    }
    printf -- "- INFO: Resetting devices from %s...\n" "$i"
    for j in ????:??:??.? ; do
      printf "%s" "$j" > unbind; printf "%s" "$j" > bind
      sleep 1
    done
  done
}

func_power_off() {
  func_dev && {
    command -v udisksctl >/dev/null 2>&1 && { \
      udisksctl power-off --no-user-interaction -b "$DST_DEV" || { \
        echo "> WARNING: udiskctl did not run successfully"
        exit 1
      }
    }
  }
}

# Function to list devices using multiple methods, shows state of backup drive if it exists
func_list () {
  FORCE=1
  func_dev
  printf "\nDST_UUID=\"%s\" DST_DEV=\"%s\"\n\n" "$DST_UUID" "$DST_DEV"
  echo "fdisk :"
  fdisk -l 2>/dev/null|grep "Disk /dev/sd[b-z]"
  echo
  echo "blkid :"
  blkid | grep -Ev "/dev/(sda[0-9]|loop|mapper)|swap|LUKS"
  echo
  echo "findmnt :"
  findmnt -nr | \
    grep -Ev '/(sda|pts)|^/(proc|run|sys|boot|jail)|tmpfs|overlay|fuseblk|mqueue|hugepages' | \
    grep -E "$DST_DEV|$DST_MNT"
  echo
  echo "/sys/devices :"
  find /sys/devices -name block -regex '.*usb.*' -exec sh -c '
    printf "%s: %s\n" "$1" "$(ls "$1")"
    printf "%s: %s\n" "$(echo "$1"/../model|sed s@"$1"/../@\ @)" "$(cat "$1"/../model 2>/dev/null )"' sh "{}" \; | \
      sed -e 's|/sys/devices/pci|/pci|g' -e 's/0000:00[/:]\?//g'
    echo
  echo "/sys/block :"
  for i in /sys/block/sd[b-z]; do
    printf "%s device/state: %s power/control: %s\n" \
      "$i" "$(cat "$i"/device/state 2>/dev/null)" "$(cat "$i"/power/control 2>/dev/null)"
  done
  echo
  echo "/sys/bus/pci/drivers :"
  find /sys/bus/pci/drivers/?hci-pci/????:??:??.? -printf "%f\n" | sed -e 's|0000:00:|  |g'
  echo
}

func_help ()  {
  printf "\nWake/Sleep Backup\n"
  printf -- "-----------------\n\n"
  printf "SYNOPSIS: wake up usb drive, rsync, power off\n\n"
  printf "USAGE: %s -[o|p][w|s][m|u][l][f] [dirs to backup]\n\n" "$( basename "$0" )"
  printf "OPTIONS: [-p]|[-o] power on | power off\n"
  printf "\t [-w]|[-s] wakeup | sleep\n"
  printf "\t [-m]|[-u] mount | umount\n"
  printf "\t [-l] list drive info\n"
  printf "\t [-f] force\n"
  printf "\t [dirs to backup] overwrites setting in script\n\n"
}

# handle arguments
if printf -- "%s" "$*" | grep -q -- '\-h'; then func_help; exit
  elif printf -- "%s" "$*" | grep -q -- '\-f'; then FORCE=1; shift
  elif printf -- "%s" "$*" | grep -q -- '\-s'; then func_sleep; exit
  elif printf -- "%s" "$*" | grep -q -- '\-w'; then func_wake; exit
  elif printf -- "%s" "$*" | grep -q -- '\-m'; then func_mnt; exit
  elif printf -- "%s" "$*" | grep -q -- '\-u'; then func_umnt; exit
  elif printf -- "%s" "$*" | grep -q -- '\-o'; then func_power_off; exit
  elif printf -- "%s" "$*" | grep -q -- '\-p'; then func_power_on; exit
  elif printf -- "%s" "$*" | grep -q -- '\-l'; then func_list; exit
  elif printf -- "%s" "$*" | grep -q -- '\-'; then func_help; exit
  elif [ "$*" != "" ]; then BKP_DIRS="$*"
fi

#
# NOTES:
#
#   hdparm:  -S 120 sets standby timeout (10min), to check: -C
#   smart:   'smartctl -i -n standby'
#   time:    'time rsync <...>' for summary (bashism)
#   rsync:   [-i] itemize changes [-v] erbose [-q] uiet [-n] dryrun
#   info:    udiskctl info -b /dev/sdX, udevadm info -p /sys/block/sdX
#   rm, add: udiskctl poweroff, bind/unbind ?hci-pci
#            echo 1 > /sys/block/sdX/device/delete, echo 1 > sdX/device/rescan
#            see http://billauer.co.il/blog/2013/02/usb-reset-ehci-uhci-linux
#   rescan:  rescan-scsi-bus.sh
#

# Main
echo
blkid -U "$DST_UUID" >/dev/null || { \
  printf "* [%s] Powering on backup drive (UUID=%s)...\n" "$(date +%F\ %T )" "$DST_UUID"
  func_power_on
}
func_dev && { printf "* [%s] Using backup drive \"%s\" (UUID=%s)\n" "$(date +%F\ %T )" "$DST_DEV" "$DST_UUID"; }
if [ ! -d "$DST_MNT" ]; then
  mkdir "$DST_MNT" || { \
    printf "! ERROR: Could not create %s\n" "$DST_MNT"
    exit 1
  }
fi
func_mnt || { \
  printf "\n! ERROR: Could not mount \"%s\" on \"%s\", exiting...\n" "$DST_DEV" "$DST_MNT"
  exit 1
}
echo
if [ -d "$DST_MNT" ]; then
  if findmnt -n "$DST_MNT" | grep -q " $DST_DEV"; then
    status=-1
    printf "* Backing up using \"%s\"...\n" "$RSYNC"
    printf "* Dir(s): \"%s\"\n" "$BKP_DIRS"
    printf "* Target drive: \"%s\" mounted on \"%s\" (UUID=%s)\n" "$DST_DEV" "$DST_MNT" "$DST_UUID"
    printf "* Exclude dir(s): %s\n\n" "$( echo "$EXCL_DIRS" | sed -- 's/--exclude=//g' )"
    # rsync dirs and poweroff if loop returns 0 (warn if it fails)
    ( 
      for i in $BKP_DIRS; do
        if [ -d "$i" ]; then
          MSG="sleeping 10s... CTRL-C TO ABORT"
          if ! echo "$i" | grep -q '^/'; then
            printf "> WARNING: \"$i\" has no leading slash, %s\n\n" "$MSG"
            sleep 10
          fi
          if ! echo "$i" | grep -q '/$'; then
            printf "> WARNING: \"$i\" has no trailing slash, %s\n\n" "$MSG"
            sleep 10
          fi
          printf "* [%s] Backup -- SOURCE DIR: \"%s\" DESTINATION: \"%s\"\n" "$(date +%F\ %T )" "$i" "${DST_MNT}${i}" | \
            tee -a "$LOG"
          if [ ! -d "${DST_MNT}${i}" ]; then
            printf "+ Creating %s\n" "${DST_MNT}${i}"
            mkdir -p "${DST_MNT}${i}" || printf "! ERROR: Could not create %s\n" "${DST_MNT}${i}"
          fi
          $RSYNC "$EXCL_DIRS" "$i" "${DST_MNT}${i}" >"$OUT" 2>&1
        else
          printf "! ERROR: \"%s\" does not exist\n" "$i"
        fi
        echo
      done
    ) && status=0 || status=1
    if [ "$status" -eq 0 ]; then
      printf "* Syncing complete, listing \"%s\"\n%s\n\n" "$DST_MNT" "$(ls -la "$DST_MNT")"
      printf "* [%s] Done. Powering off\n" "$(date +%F\ %T )" | tee -a "$LOG"
      sleep 30 && func_umnt && func_power_off
    else
      printf"> [%s] WARNING: Check if drive is unmounted and powered down\n" "$(date +%F\ %T )" | \
        tee -a "$LOG"
    fi
  else
    printf "ERROR: mount \"%s\" not found, exiting\n" "$DST_MNT"
    exit 1
  fi
else
  printf "ERROR: \"%s\" does not exists, exiting...\n" "$DST_MNT"
  exit 1
fi
echo
if [ -d "$DST_MNT" ]; then
  rmdir "$DST_MNT" || printf "NOTICE: could not remove dir \"%s\"\n" "$DST_DIR"
fi
exit 0
