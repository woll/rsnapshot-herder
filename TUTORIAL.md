Terminology:
* "Server": The machine where the backups are stored, and where rnsapshot is run
* "Client": A machine to be backed up

Note: This tutorial is based on the server and clients all running MacOS with MacPorts, so some of the example file paths to executables/system files may be different on other OSes. 

1) Install `rsnapshot` on the server

2) Install `rsync` on the client

3) Create a 'backup' user on the client (For security. Instead of using the root user)

4) Turn on ssh access for the 'backup' user on the client

5) To allow the server to run rsync on the client via ssh, without needing a login password, first create a host key on the server.
   Note: I've used `ed25519` because keys using older encryption methods may be rejected by newer OSes (eg more recent MacOS versions)
```
  sudo ssh-keygen -t ed25519 -a 100
```

6) From the server, copy this host key to the client
```
  sudo ssh-copy-id -i /var/root/.ssh/id_ed25519 backup@<client>
```
  or
```
  sudo cat /var/root/.ssh/id_ed25519.pub | ssh backup@<client> 'cat >> /Users/backup/.ssh/authorized_keys
```

7) Check that the server can logon to the client as the 'backup' user, without asking for a password
```
  sudo ssh backup@<client> date
```

8) On the client, create a 'sudoers' file (using `sudo visudo -f /etc/sudoers.d/backup` or the command below) for the 'backup' user, to restrict the 'backup' user to run 'rsync' as sudo:
```
  sudo tee /etc/sudoers.d/backup <<<'backup ALL = (root) NOPASSWD: /opt/local/bin/rsync'
```
  Test this on the client with:
```
  sudo /opt/local/bin/rsync --version
```
  If that fails, then the main sudoers file on the client might be missing the line: `#includedir /etc/sudoers.d`

9) From the server, test that the sudoers file allows the server to run 'sudo rsync' on the client, but not anything else.
   This should work:
    ```
    sudo ssh backup@<client> sudo /opt/local/bin/rsync --version
    ```
    This should fail:
    ```
    sudo ssh backup@<client> sudo date
    ```

10) On the server, create an rsnapshot config file for each client. e.g. named `rsnapshot.<client>.conf`
```
sudo cp /opt/local/etc/rsnapshot.conf <your path>/rsnapshot.<client>.conf
```

11) In this client rsnapshot config file, set the snapshot_root (using rsnapshot.conf `<tab>` syntax) to a unique directory for each client. e.g.
```
snapshot_root<tab>/Volumes/BigBackupDisk/rsnapshot-<client>
```

12) Turn on the 'sync_first' mode
```
sync_first<tab>1
```

13) Set the lockfile to be unique for each client
```
lockfile<tab>/var/run/rsnapshot-<client>.pid
```
14) Enable the cmd_ssh setting
```
cmd_ssh<tab>/usr/bin/ssh
```

15) Add the following to the rsync_long_args setting:
```
rsync_long_args<tab>--partial --partial-dir=.rsync-partial --rsync-path="sudo /opt/local/bin/rsync" -f'P .rsync-partial' 
```
The 'partial' args make rsync store partial transfers of the file being transferred, so that if the connection is broken (e.g. the user turns off the laptop client) then that part of the file wont need to be transferred again. Without this, rsync may continually try to re-transfer (large) files on each backup run and never succeed in completing a sync.
	The 'rsync-path' makes the rsync on the client run as the root user, so that it can access all the user files to be backed up.

To reduce/limit/prevent-saturation-of the bandwidth for clients with 'slow/expensive' connections, you can also add (choosing an appropriate value for `bwlimit`):
```
--compress --bwlimit=1MiB
```

16) Add a backup line for each user on the client you want to be backed up
```
backup<tab>backup@<client>:<path-to-user1-home-on-client>/      .
backup<tab>backup@<client>:<path-to-user2-home-on-client>/      .
```

17) Install the `rsnapshot-herder` script on the server, and edit the `configuration` section to match your requiresments/system.

18) On the server, create a root cron entry  (`sudo crontab -e`) for each client to run rsnapshot-herder and try to backup each client every hour:
```
17 * * * * <path-to>/rsnapshot-herder <path-to-client1-rsnapshot-conf>/
47 * * * * <path-to>/rsnapshot-herder <path-to-client2-rsnapshot-conf>/
```
Each run of `rsnapshot-herder` is independent from the others, so it doesn't actually matter if they run at the same time (apart from overwhelming the server it there's too many clients!).

Notes:
1) On MacOS, if backing-up to an external disk on the server then disable "Ignore ownership on this volume" in Finder for that disk. This preserves file ownership/privacy when synced to that disk, so that only the correct user (and root) on the server is able to view their files.
2) I do not set `--numeric-ids` in the rsync args in rsnapshot.conf, so that the user IDs will be translated from the client to the server (because there's an account for every user on the server). This is so that permissions are preserved on the server, so that a user's files are only accessible by the same user on the server.
If the numeric IDs are preserved, then you need to set permissions on the backups to only allow root access to the backups, because the numeric ID on the client will be a completely different user on the server.