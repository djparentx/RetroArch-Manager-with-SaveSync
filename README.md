[<img width="200" height="67" alt="ChatGPT Image Aug 12, 2026, 02_04_12 PM" img align="right"  src="https://github.com/user-attachments/assets/7eb7b583-5d57-4884-ae90-ad7127d733c4" alt="Right aligned" />](https://ko-fi.com/O8Z424G15Y)
# RetroArch Manager with SaveSync
A script to manage gamesave locations and automatically synchronize them over local SMB network sharing. SaveSync does not require an account or subscription, everything is managed locally on the host device.

# SaveSync

SaveSync is a built-in feature of **RetroArch Manager** that automatically synchronizes RetroArch game saves between your dArkOS device and a shared folder on a Windows PC over your local network.

It is designed to keep your saves synchronized without requiring you to manually copy them. Once configured, SaveSync can synchronize saves:

* Automatically when the console starts
* Automatically when you exit a game
* Manually whenever you choose
* Between multiple R36S devices using the same PC share

SaveSync uses SMB/CIFS to connect to the Windows share and `rsync` to synchronize the files in both directions.

> **Important:** SaveSync is a synchronization system, not simply a one-way backup. Changes are synchronized between the R36S and the PC share.

---

## How SaveSync Works

The basic setup is:

```text
                 Local Network
                       │
                       ▼
┌──────────────────────────────────────┐
│              Windows PC              │
│                                      │
│  Shared SaveSync folder              │
│  ├── gb/                             │
│  ├── gba/                            │
│  ├── snes/                           │
│  ├── psx/                            │
│  └── savesync.cfg                    │
│                                      │
└──────────────────┬───────────────────┘
                   │ SMB
                   │
                   ▼
┌──────────────────────────────────────┐
│             dArkOS / R36S            │
│                                      │
│  RetroArch saves/states              │
│             ↕                        │
│          SaveSync                    │
│                                      │
└──────────────────────────────────────┘
```

Windows provides the shared folder through SMB. SaveSync mounts that share temporarily at:

```text
/mnt/savesync
```

It then synchronizes the appropriate save directories and unmounts the share when finished.

The SaveSync script checks for a network connection before attempting synchronization and records its activity in:

```text
/home/ark/.config/savesync.log
```

---

# 1. Prepare the Windows PC

## Create the SaveSync Folder

Create a folder somewhere on your Windows PC to store the synchronized saves.

For example:

```text
C:\SaveSync
```

You can use any location you prefer.

Do **not** create a separate folder for each R36S. A single shared SaveSync folder can be used by multiple R36S devices.

---

## Share the Folder

Right-click the folder and share it over your local network.

In Windows 11:

1. Right-click the `SaveSync` folder.
2. Select **Show more options** if necessary.
3. Select **Give access to** → **Specific people**.
4. Select the Windows user account that SaveSync will use.
5. Give that account permission to read and modify the files.
6. Complete the sharing process.

Windows supports sharing folders over a local network using SMB.

### Share Name

Pay attention to the **share name**.

For example, if Windows creates:

```text
\\MY-PC\SaveSync
```

then:

```text
MY-PC
```

is the computer name, and:

```text
SaveSync
```

is the **network path/share name** that SaveSync needs.

SaveSync does not need the full Windows filesystem path such as:

```text
C:\SaveSync
```

It needs the SMB share name:

```text
SaveSync
```

---

## Make Sure the Share Is Accessible

Before configuring the R36S, verify that the shared folder can be accessed from another device on your network.

Windows recommends enabling network discovery and file and printer sharing when sharing folders over a local network.

The Windows firewall must also allow file and printer sharing/SMB traffic. SMB normally uses TCP port 445 for direct SMB connections.

---

# 2. Choose Your Save Organization

SaveSync supports two different ways of organizing saves.

This setting is controlled by a file named:

```text
savesync.cfg
```

The file must be placed in the **root of the Windows SaveSync share**.

For example:

```text
C:\SaveSync\
├── savesync.cfg
├── gb\
├── gba\
├── snes\
└── psx\
```

There are two possible configurations.

---

## Option A — Normal Save Folders

Use:

```ini
USECONTENTFOLDER=false
```

With this configuration, the PC share is organized like this:

```text
SaveSync/
├── savesync.cfg
├── gb/
│   ├── Game1.srm
│   └── Game2.srm
├── gba/
│   └── Game1.srm
├── snes/
│   └── Game1.srm
└── psx/
    └── Game1.srm
```

This corresponds to RetroArch's normal centralized save directory structure:

```text
retroarch/saves/<system>/
```

For example:

```text
/home/ark/.config/retroarch/saves/gba/
```

The same system folder is used on the PC share:

```text
SaveSync/gba/
```

SaveSync also handles RetroArch save states.

---

## Option B — Content-Folder Organization

Use:

```ini
USECONTENTFOLDER=true
```

With this configuration, SaveSync uses a nested system directory on the PC:

```text
SaveSync/
├── savesync.cfg
├── gb/
│   └── gb/
│       ├── Game1.srm
│       └── Game2.srm
├── gba/
│   └── gba/
│       └── Game1.srm
└── snes/
    └── snes/
        └── Game1.srm
```

The extra directory level corresponds to the content-folder organization used by RetroArch Manager.

This option is useful when your RetroArch configuration stores save files alongside the game content rather than in RetroArch's centralized save directory.

The current SaveSync implementation reads `USECONTENTFOLDER` from the PC configuration and selects the corresponding destination structure.

---

# 3. Create `savesync.cfg`

Create a plain text file named:

```text
savesync.cfg
```

Place it directly inside the Windows shared folder.

### For normal save folders:

```ini
USECONTENTFOLDER=false
```

### For content-folder organization:

```ini
USECONTENTFOLDER=true
```

The value must be exactly:

```text
true
```

or:

```text
false
```

SaveSync will reject the configuration if the value is missing or contains anything other than `true` or `false`.

---

# 4. Configure SaveSync on the Console

Open:

**RetroArch Manager → SaveSync**

The SaveSync menu contains:

1. **Install SaveSync**
2. **Enter Credentials**
3. **Synchronize Now**
4. **View Log**

After installation, the first menu item changes to:

**Uninstall SaveSync**

---

# 5. Install SaveSync

Select:

**Install SaveSync**

The installer automatically checks for the required CIFS support.

If `mount.cifs` is not installed, RetroArch Manager attempts to install the required `cifs-utils` package automatically.

SaveSync then installs:

```text
/usr/local/bin/savesync.sh
```

and configures the automatic synchronization components.

---

# 6. Enter Network Credentials

Select:

**SaveSync → Enter Credentials**

You will be able to configure:

* **NetBIOS or IP**
* **Username**
* **Password**
* **Network Path**

---

## NetBIOS or IP

You can enter either the Windows computer's network name:

```text
MY-PC
```

or its IP address:

```text
192.168.1.100
```

If an IP address is entered, SaveSync uses it directly.

If a computer name is entered, SaveSync uses NetBIOS name resolution to find the PC's IP address.

### Recommended

For the most reliable setup, using the PC's IP address can avoid problems caused by name resolution.

If using an IP address, it is recommended to give the PC a DHCP reservation in your router so the address does not change.

---

## Username

Enter the Windows account username that has permission to access the shared SaveSync folder.

For example:

```text
John
```

---

## Password

Enter the password for that Windows account.

SaveSync stores the credentials in:

```text
/home/ark/.config/savesync.crd
```

The credentials file is created with restrictive permissions (`600`) so it is not publicly readable.

---

## Network Path

Enter the **SMB share name**, not the Windows filesystem path.

If the Windows share is:

```text
\\MY-PC\SaveSync
```

enter:

```text
SaveSync
```

Do **not** enter:

```text
C:\SaveSync
```

and do not enter:

```text
\\MY-PC\SaveSync
```

The SaveSync script constructs the SMB path automatically:

```text
//<PC>/<NETWORKPATH>
```

and mounts it using SMB 3.0.

---

# 7. Perform the First Synchronization

Once the Windows share and credentials are configured, select:

**SaveSync → Synchronize Now**

The first synchronization is important because it establishes the initial synchronized state between the R36S and the PC.

SaveSync checks both sides and synchronizes files in both directions.

The actual synchronization uses:

```text
rsync -au
```

from the R36S to the PC and then again from the PC to the R36S.

When successful, RetroArch Manager displays:

```text
Success!
```

If the synchronization fails, the most recent SaveSync error is displayed when available.

---

# 8. Automatic Synchronization

Once SaveSync is installed, synchronization happens automatically.

## At Boot

SaveSync installs:

```text
savesync.service
```

The service waits for NetworkManager's network-online service before starting the synchronization.

This allows the R36S to automatically synchronize its saves after connecting to the network during startup.

---

## After Exiting a Game

SaveSync also installs an EmulationStation game-end hook:

```text
/home/ark/.emulationstation/scripts/game-end/savesync.sh
```

When a game exits, the hook launches:

```text
/usr/local/bin/savesync.sh
```

The synchronization script then runs in the background.

This means that after playing a game and exiting back to EmulationStation, the current save can automatically be synchronized to the PC.

---

## Manual Synchronization

Automatic synchronization is supplemented by the manual option:

**RetroArch Manager → SaveSync → Synchronize Now**

Use this whenever you want to force an immediate synchronization without rebooting or exiting a game.

---

# 9. Using Multiple R36S Devices

One of the major advantages of SaveSync is that multiple R36S devices can use the same Windows share.

For example:

```text
                    Windows PC
                  SaveSync Share
                        │
             ┌──────────┴──────────┐
             │                     │
             ▼                     ▼
          R36S #1               R36S #2
          dArkOS                dArkOS
             │                     │
             └──────────┬──────────┘
                        │
                   synchronized
                      saves
```

Configure each device to use the same:

* PC
* Share
* Username
* Password
* `savesync.cfg`

This allows you to move between devices while keeping your game progress synchronized.

---

# 10. Important: How Synchronization Handles Files

SaveSync is **bidirectional**.

It performs:

```text
R36S → PC
```

followed by:

```text
PC → R36S
```

using:

```text
rsync -au
```

This means the PC share is not treated as a permanent read-only backup.

Instead, it acts as the central synchronization location between devices.

### Example

If you play a game on R36S #1:

```text
R36S #1
Game.srm
    ↓
Windows SaveSync
```

Then later synchronize R36S #2:

```text
Windows SaveSync
    ↓
R36S #2
Game.srm
```

R36S #2 receives the synchronized save.

This makes it possible to continue playing the same games on multiple R36S devices.

---

# 11. RetroArch Save Locations

SaveSync supports both  RetroArch Manager save arrangements.

### Centralized saves

```text
/home/ark/.config/retroarch/saves/
```

and:

```text
/home/ark/.config/retroarch/states/
```

It also accounts for the 32-bit RetroArch configuration:

```text
/home/ark/.config/retroarch32/saves/
```

and:

```text
/home/ark/.config/retroarch32/states/
```

The active RetroArch systems are determined from:

```text
/etc/emulationstation/es_systems.cfg
```

so SaveSync can determine which systems use RetroArch 64-bit or RetroArch 32-bit.

### Content-folder saves

If RetroArch is configured to store saves in the content directory, SaveSync determines whether the system is located under:

```text
/roms/
```

or:

```text
/roms2/
```

and uses the corresponding system directory.

---

# 12. Checking the SaveSync Log

SaveSync maintains a log at:

```text
/home/ark/.config/savesync.log
```

To view it:

**RetroArch Manager → SaveSync → View Log**

The log records synchronization activity and errors.

For example, it records when a share is mounted:

```text
Mounted //MY-PC/SaveSync at /mnt/savesync
```

and when synchronization finishes:

```text
Sync complete, unmounted /mnt/savesync
```

---

# 13. Troubleshooting

## "No network connection detected"

SaveSync requires an active network connection.

If the R36S is offline, synchronization is skipped and the event is recorded in the log.

Connect to Wi-Fi and try:

**SaveSync → Synchronize Now**

---

## Authentication Failed

If the log reports:

```text
authentication failed
```

check:

* Windows username
* Windows password
* Share permissions
* File/folder permissions

The SaveSync credentials are stored in:

```text
/home/ark/.config/savesync.crd
```

Use:

**SaveSync → Enter Credentials**

to update them.

---

## Share or Path Not Found

If the log reports that the share or path cannot be found, verify the **Network Path**.

For:

```text
\\MY-PC\SaveSync
```

the Network Path must be:

```text
SaveSync
```

not:

```text
C:\SaveSync
```

and not:

```text
\\MY-PC\SaveSync
```

---

## Network Unreachable

If the log reports:

```text
network unreachable
```

check that:

* Wi-Fi is connected on the R36S.
* The PC is connected to the same local network.
* The PC is powered on.
* The PC's IP address is correct.

---

## Connection Timed Out

If the log reports:

```text
connection timed out
```

the PC may be powered off or unreachable.

Check that the Windows PC is awake and connected to the network.

---

## Connection Refused

If the log reports:

```text
connection refused
```

check that Windows file sharing is enabled and that the firewall is allowing SMB/file sharing traffic.

---

## `savesync.cfg` Error

If SaveSync reports:

```text
invalid or missing UseContentFolder
```

make sure the file exists at the root of the shared folder:

```text
SaveSync/
└── savesync.cfg
```

and contains exactly one of:

```ini
USECONTENTFOLDER=true
```

or:

```ini
USECONTENTFOLDER=false
```

---

# 14. Uninstalling SaveSync

To remove SaveSync:

**RetroArch Manager → SaveSync → Uninstall SaveSync**

The uninstaller removes:

```text
savesync.service
```

the SaveSync synchronization script:

```text
/usr/local/bin/savesync.sh
```

and the EmulationStation game-end hook.

It also removes the SaveSync installation flag.

Your Windows SaveSync folder and its contents are **not** removed.

---

# 15. Recommended Setup

For most users, the following configuration is recommended:

### Windows

```text
C:\SaveSync\
├── savesync.cfg
├── gb\
├── gba\
├── gbc\
├── genesis\
├── nes\
├── psx\
├── snes\
└── ...
```

### `savesync.cfg`

```ini
USECONTENTFOLDER=false
```

### R36S

Configure:

```text
NetBIOS/IP:    <Windows PC IP or name>
Username:      <Windows username>
Password:      <Windows password>
Network Path:  SaveSync
```

Then:

1. Install SaveSync.
2. Enter the network credentials.
3. Run **Synchronize Now**.
4. Confirm that the save files appear on the PC.
5. Leave SaveSync installed.

After that, SaveSync handles synchronization automatically at boot and after games are exited.

---

# 16. Summary

SaveSync provides a simple way to keep R36S game saves synchronized across devices without manually copying files.

Once configured:

```text
Play game
    ↓
Exit game
    ↓
SaveSync automatically runs
    ↓
Windows share is mounted
    ↓
Saves synchronize in both directions
    ↓
Share is unmounted
```

The same process also occurs during boot once the network is available.

The result is a persistent network-based save repository that can be shared by multiple R36S devices, making it much easier to protect game progress and continue playing on another device.
