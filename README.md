# wsbkp

***W***ake/***S***leep ***B***ac***k***u***p*** -- 'wakes up' usb drive, rsyncs and powers off

A wrapper script to create cheap and easy (partially) 'offline' backups, at file level. Having the disk online only while backing up could offer benefits like data isolation and (some) protection against crypto lockers. This shell script is meant to run on Linux and uses rsync, hdparm and udisksctl.

Output looks like this:

``` shell

root@host:~# wsbkp.sh

* [2020-01-01 17:58:28] Using backup drive "/dev/sdb5" (UUID=abc12345-1234-1234-1234-aaaabbbbcccc)

* Backing up using "rsync -aA --info=flist0,name0,progress2,stats2 --progress --stats"...
* Dir(s): "/"
* Target drive: "/dev/sdb5" mounted on "/mnt/bkp" (UUID=abc12345-1234-1234-1234-aaaabbbbcccc)
* Exclude:
  /proc/
  /sys/
  /lost+found/
  /mnt/
  /run/
  /tmp/

[2022-03-26 17:58:28] Backup -- SOURCE DIR: "/" DESTINATION: "/mnt/bkp/"

* Listing "/mnt/bkp" after sync...
total 100
drwxr-xr-x  26 root root  4096 Mar 11 06:11 .
drwxr-xr-x  14 root root  4096 Apr 26  2021 ..
drwxrwxr-x   2 root root  4096 Jan 28 06:54 bin
drwxr-xr-x   4 root root  4096 Mar 11 06:15 boot
drwxr-xr-x  17 root root  4096 Mar 26 17:29 dev
drwxr-xr-x 194 root root 12288 Mar 26 14:30 etc
<-- CUT -->

* [2021-0-01 18:24:57] Done. Powering off

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

Make sure rsync, hdparm and udisksctl (udisks2) are available.

The script can be placed in any location, e.g. /usr/local/sbin (recommended).

## Running

### Backup

Run as root. No command line arguments should be needed, all options are set inside script.

The options listed under 'Usage' are meant in case if e.g. the drive fails to power off automatically after the backup is finished. If that happens, retry manually with `wsbpk -o`.

Another option is to do a one time backup of a different source directory than configured:

`wsbkp /home/user/important /root/more_stuff`

### Restore

To restore one of more files first run `wsbkp -p` to power on the drive and `wsbkp -m` to mount it.

## Configuration

1\) Get UUID of backup drive:

```
root@host:~# blkid
/dev/sdb1: UUID="bc12345-1234-1234-1234-aaaabbbbcccc" BLOCK_SIZE="1024" TYPE="ext4" PARTUUID="ab1c2345-01"
```

Now running `wsbkp.sh -l` should display drive details.

2\) Change settings inside script:

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

3\) Test and schedule:

Run the script manually to verify correct settings. In case of issues set `LOG=/dev/stdout` for more verbose output from rsync.

If all is well, schedule the script to run for example every night at 3 o'clock

- Cron: `0 3 * * 0 /usr/local/sbin/wsbkp.sh >/dev/null 2>&1`
- Systemd: see https://www.freedesktop.org/software/systemd/man/systemd.timer.html
