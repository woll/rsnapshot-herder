# rsnapshot-herder
A script to handle the high-level sync and rotation steps needed when using the `sync_first` mode of `rsnapshot`, that is especially useful when backing up laptops that may not be online all the time.  

Most descriptions of installing and configuring rsnapshot use the simpler, default mechanism (basically, running `rsnapshot daily` etc, at the correct times in cron), that is not so convenient/suitable if you are backing up machines with unreliable connections (like laptops that may be turned off when the backup is attempted).

Using the `sync_first` option of rsnapshot fits much better with laptops, or other computers, that may be turned off/not connected when the backup is attempted. Apparently, in future, using `sync_first` will be the recommended way of using rsnapshot, but there does not seem to be a lot of documentation on the steps required to use that mode.

To use the `sync_first` mode, rsnapshot needs to be run multiple times (to sync and rotate the backups in the correct order and at the correct times) to create a backup that matches the frequency you require. `rsnapshot-herder` is a script that does this.

I first saw a mention of this technique from the user 'Tapani Tarvainen' in a thread on the rsnapshot mailing list (https://sourceforge.net/p/rsnapshot/mailman/message/34179129/), but I couldn't find a detailed tutorial/script that implements this strategy, so I wrote `rsnapshot-herder`.

rsnapshot-herder configures itself from standard rsnapshot.conf files.