# Notes

## power

- `hdparm -S 120` sets standby timeout (10min), to check: `-C`
- `smartctl -i -n standby` (SMART)
- `udiskctl info -b /dev/sdX`
- `udevadm info -p /sys/block/sdX`

## rm, add, rescan device

- bind/unbind ?hci-pci
- `udiskctl poweroff`
- `echo 1 > /sys/block/sdX/device/delete`
- `echo 1 > sdX/device/rescan`
- `rescan-scsi-bus.sh`

http://billauer.co.il/blog/2013/02/usb-reset-ehci-uhci-linux

## rsync

- `rsync [-i] itemize changes [-v] erbose [-q] uiet [-n] dryrun`
- `time rsync <...>` for summary (bashism)
- cleanup/rm dest: `--delete` `--delete-before` `--delete-during` (default) --delete-after`

## host controller interfaces

- ohci-pci: usb 1.1 (uhci)
- ehci-pci: usb 1.1 2.0
- xhci_hcd: usb 1.0 2.0 3.0

https://www.kernel.org/doc/html/latest/driver-api/usb/usb.html

https://www.kernel.org/doc/html/latest/usb/ehci.html

