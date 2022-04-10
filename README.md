# wsbkp

**W**ake/**S**leep **b**ac**k**u**p** -- 'wakes up' usb drive, rsyncs and powers off

Wsbkp is a wrapper shell script to create cheap and easy (partially) 'offline' backups. File level backups are created by coping data to an external (usb) disk using [rsync](https://rsync.samba.org). Having the disk online only while backing up could offer benefits like data isolation and (some) protection against crypto lockers.

It's is meant to run on Linux and besides rsync uses [hdparm](https://sourceforge.net/projects/hdparm) and [udisksctl](http://storaged.org/doc/udisks2-api/latest/udisksctl.1.html). Note that not all usb controllers and drives are guaranteed to work.

When executed, output looks like this:

``` shell

root@host:~# wsbkp.sh

[2020-01-01 17:58:20] Powering on drive (UUID=abc12345-1234-1234-1234-aaaabbbbcccc)...
- INFO: Resetting devices from /sys/bus/pci/drivers/ehci-pci...
- INFO: Resetting devices from /sys/bus/pci/drivers/ohci-pci...

[2020-01-01 17:58:28] Using backup device "/dev/sdb5" (UUID=abc12345-1234-1234-1234-aaaabbbbcccc)
- INFO: Mounted "/dev/sdb5" "/mnt/bkp"

* Command: "rsync -aA --info=flist0,name0,progress2,stats2 --progress --stats"
* Dir(s): "/"
* Target drive: "/dev/sdb5" mounted on "/mnt/bkp" (UUID=abc12345-1234-1234-1234-aaaabbbbcccc)
* Exclude:
  /proc/
  /sys/
  /lost+found/
  /mnt/
  /run/
  /tmp/

[2022-03-26 17:58:28] Backup SOURCE DIR: "/" to DESTINATION: "/mnt/bkp/"

* Syncing complete, listing "/mnt/bkp"...
total 100
drwxr-xr-x  26 root root  4096 Mar 11 06:11 .
drwxr-xr-x  14 root root  4096 Apr 26  2021 ..
drwxrwxr-x   2 root root  4096 Jan 28 06:54 bin
drwxr-xr-x   4 root root  4096 Mar 11 06:15 boot
drwxr-xr-x  17 root root  4096 Mar 26 17:29 dev
drwxr-xr-x 194 root root 12288 Mar 26 14:30 etc
<-- CUT -->

[2021-0-01 18:24:57] Done. Powering off

```

## Usage

```

Wake/Sleep Backup
-----------------

SYNOPSIS: wake up usb drive, rsync, power off

USAGE: wsbkp.sh -[o|p][w|s][m|u][l][f] [dirs to backup]

OPTIONS: [-p]|[-o] power on | power off
         [-w]|[-s] wakeup | sleep
         [-m]|[-u] mount | umount
         [-l] list drive info
         [-f] force
         [dirs to backup] overwrites setting in script

```

## Installation

The script can be placed in any location, e.g. '/usr/local/sbin' (recommended).

Make sure rsync, hdparm and udisksctl (udisks2) are installed.

The target backup device should be available with a uuid, writable filesystem and enough free disk space.

## Running

### Backup

Run as root. No command line arguments should be needed, all options are set inside script. A log file will be created here: '/var/log/wsbkp.log'.

The options listed under 'Usage' are meant in case if e.g. the drive fails to power off automatically after the backup is finished. If that happens, retry manually with `wsbkp.sh -o`

Another option is to do a one time backup of a different source directory than configured:

`wsbkp.sh /home/user/important /root/more_stuff`

### Restore

To restore one of more files first run `wsbkp.sh -p` to power on the drive and `wsbkp.sh -m` to mount it.

When done, "disconnect" the drive with `wsbkp.sh -u` to umount then `wsbkp.sh -o` to power it off.

## Configuration

**1)** Get UUID of backup drive:

```
root@host:~# blkid
/dev/sdb1: UUID="bc12345-1234-1234-1234-aaaabbbbcccc" BLOCK_SIZE="1024" TYPE="ext4" PARTUUID="ab1c2345-01"
```

Now running `wsbkp.sh -l` should display drive details.

**2)** Change settings inside script:

``` shell
DST_UUID="abc12345-1234-1234-1234-aaaabbbbcccc" # uuid of backup device
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
```

Make sure DST_UUID is set to the correct UUID.

The default is to backup the whole fileystem ('/') and exclude some dirs. It's also possible to specify one or more dirs to backup. Example: `BKP_DIRS="/etc/ /root/ /home/ /opt/ /usr/local/bin/"`

**3)** Test and schedule:

Run the script manually to verify correct settings. In case of issues set `OUT=/dev/stdout` to show output from rsync (progress/speed etc).

Supported rsync options: `wsbkp.sh -n` for dry-run and/or `-v` for increased verbosity.

## Scheduling

If all is well, schedule the script to run every week for example. See cron and systemd configs below (copy/paste to shell).

### Cron

Run script as root:

``` shell
echo '0 3 * * 1 root /usr/local/sbin/wsbkp.sh >/dev/null 2>&1' >/etc/cron.d/wsbkp`
```

### Systemd

To run as systemd timer, first create unit files:

``` shell
cat <<EOF >/lib/systemd/system/wsbkp.service
[Unit]
Description=WakeSleep backup

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wsbkp.sh
EOF


cat <<EOF >/lib/systemd/system/wsbkp.timer
[Unit]
Description=WakeSleep backup scheduled to run every week

[Timer]
OnCalendar=weekly

[Install]
WantedBy=timers.target
EOF
```

Then enable timer: `systemctl enable --now wsbkp.timer`

And finally reload systemd: `systemctl daemon-reload`

For details see https://www.freedesktop.org/software/systemd/man/systemd.timer.html
