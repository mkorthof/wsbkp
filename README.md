# wsbkp
## Wake/Sleep Backup - 'wake up' drive, rsync, poweroff

### Usage
```
USAGE: wsbkp.sh -[f|h|w|s|m|o|p|u]|<dirs to backup>
        [-p]|[-o] power on/off drive
        [-w]|[-s] wakeup/sleep drive
        [-m]|[-u] mount/umount drive
        [-l] list drive, [-f] force
        <dirs to backup> overwrites var in script
```

### Example

BKP_DIRS="/etc/ /root/ /home/ /opt/ /usr/local/bin/"

### Notes

- hdparm: standby timeout: -S 120 (10min), check: -C
- smart: `smartctl -i -n standby`
- time: "time rsync <...>" for summary (bashism)
- rsync: -i itemize changes, -v erbose, -q uiet, -n dryrun
- info: `udiskctl info -b /dev/sdX`, `udevadm info -p /sys/block/sdX`
- rm, add:
   - `udiskctl poweroff`, bind/unbind ?hci-pci
   - `echo 1 > /sys/block/sdX/device/delete`, `echo 1 > sdX/device/rescan`
- rescan: `rescan-scsi-bus.sh`

