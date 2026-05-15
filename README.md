# Lenovo ThinkPad T480 OpenCore Configuation

![repository-open-graph-template-l24](https://github.com/user-attachments/assets/93d4fbc8-b233-4182-86d0-cc45ec1d32ae)


[![macOS](https://img.shields.io/badge/macOS-Big_Sur-red.svg)](https://developer.apple.com/documentation/macos-release-notes)
[![macOS](https://img.shields.io/badge/macOS-Monterey-hotpink.svg)](https://developer.apple.com/documentation/macos-release-notes)
[![macOS](https://img.shields.io/badge/macOS-Ventura-orange.svg)](https://developer.apple.com/documentation/macos-release-notes)
[![macOS](https://img.shields.io/badge/macOS-Sonoma-brightgreen.svg)](https://developer.apple.com/documentation/macos-release-notes)
[![macOS](https://img.shields.io/badge/macOS-Sequoia-lightblue.svg)](https://www.apple.com/macos/macos-sequoia/)
[![macOS](https://img.shields.io/badge/macOS-Tahoe_26-9b59b6.svg)](https://www.apple.com/macos/)
[![OpenCore](https://img.shields.io/badge/OpenCore-1.0.7-blue)](https://github.com/acidanthera/OpenCorePkg)
[![License](https://img.shields.io/badge/license-MIT-purple)](/LICENSE)

<p align="center">
   <strong>Status: Maintained</strong>
   <br />
   <strong>Version: </strong>2.4
   <br />
   <a href="https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480/releases"><strong>Download now »</strong></a>
   <br />
   <a href="https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480-Kaby-Lake-Edition"><strong>Lenovo ThinkPad T480 Kaby Lake EFI »</strong></a>
   <br />
   <a href="https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480/issues">Report Bug</a>
   <a href="https://github.com/valnoxy/t480-oc/blob/main/CHANGELOG.md">View Changelog</a>
  </p>
</p>
</br>

## ⚠️ Disclaimer
This guide is only for the Lenovo ThinkPad T480. I am NOT responsible for any harm you cause to your device. This guide is provided "as-is" and all steps taken are done at your own risk.

> The ACPI patches and the style of this README are from [EETagent](https://github.com/EETagent/T480-OpenCore-Hackintosh).

&nbsp;

## Introduction

### EFI folders

This repo includes multiple EFI configuations for different macOS Versions.

| EFI               | Description                                                               | Type      |
| ----------------- | ------------------------------------------------------------------------- | --------- |
| `EFI - Intel`     | Supports macOS Ventura (using Airportitlwm)		                | `Stable`  |
| `EFI - HeliPort`  | Supports every macOS Version, Requires HeliPort app      			| `Stable`  |
| `EFI - Broadcom`  | Supports every macOS Version (except Sonoma)		                | `Beta`    |
| `EFI - Sonoma`    | Supports macOS Sonoma (using Itlwm and HeliPort)				| `Stable`  |
| `EFI - Sequoia`   | Supports macOS Sequoia (using Airportitlwm)				| `Stable`  |
| `EFI - Tahoe`     | macOS Tahoe 26 — OpenCore 1.0.7, all kexts latest, personalised SMBIOS    | `Active`  |

> **Note** The Broadcom configuration is not stable. Use ```EFI``` instead for a better experience (you can also disable Airportitlwm).

&nbsp;

## EFI - Tahoe (this fork's primary config)

OpenCore **1.0.7** build targeting **macOS Tahoe 26.x** on this T480 hardware (i7-8650U, UHD 620, Intel 8265, SM2263 NVMe, ALC257, 32 GiB).

**All kexts latest as of 2026-05-15:**
Lilu 1.7.2 · VirtualSMC 1.3.7 · WhateverGreen 1.7.0 · AppleALC 1.9.7 · NVMeFix 1.1.3 · AirportItlwm 2.3.0 (Sonoma14.4 variant, Tahoe-compatible via OCLP root patches) · IntelBluetoothFirmware 2.4.0 · BlueToolFixup 2.7.2 · VoodooPS2 2.3.7 · VoodooRMI 1.4.3 · IntelMausi 1.0.8 · HibernationFixup 1.5.4 · RTCMemoryFixup 1.0.7 · BrightnessKeys 1.0.3 · YogaSMC 1.5.3 · ECEnabler 1.0.6 · RestrictEvents 1.1.6

**Personalisations from upstream MultimediaLucario template:**
- SMBIOS regenerated (MacBookPro15,2 — supports Tahoe natively via T2). Upstream example serial replaced.
- ROM set to real I219-LM MAC of this T480 for cleanest iServices baseline.
- `alcid=86` in boot-args matches HDEF DeviceProperties layout-id (T480 ALC257 community-verified).
- `SSDT-OFFDGPU` and `SSDT-ARPT` disabled (no dGPU, not on Broadcom).
- `AirportItlwm-Ventura.kext` → `AirportItlwm.kext`; `IntelMausiEthernet.kext` → `IntelMausi.kext` (latest upstream naming).
- Boot-args tuned for KBL-R UHD 620 + Tahoe: `igfxonln=1 igfxpps=1 -igfxmpc shikigva=80 -liluuserbeta -lilubetaall`.
- `PanicNoKextDump=False` for diagnostic-friendly install.
- Verbose mode + debug flags ON for install — strip after first successful boot (`-v`, `debug=0x100`).
- OpenCore 1.0.7 binaries + drivers (added `OpenVariableRuntimeDxe.efi` with `LoadEarly=True`).
- Passes `ocvalidate` 1.0.7 with zero issues.

**SMBIOS verification:** Apple's checkcoverage.apple.com blocks programmatic lookup. Before first boot, paste `C02ZLDZDJHCC` into [checkcoverage.apple.com](https://checkcoverage.apple.com) manually — must return "not a valid serial". If it matches a real Mac, regenerate via `Source Code/macserial`.

**Known caveats (hardware/OS limits, not config bugs):**
- Intel 8265 WiFi: no native Apple wireless → no AirDrop / Handoff / Continuity / Sidecar. Browsing works after OCLP root patches.
- Safari can't play DRM video (Netflix / Apple TV+) — use Chrome/Firefox.
- NVMe SM2263 DRAM-less: macOS doesn't support HMB → ~30-40% lower random IOPS (sequential I/O fine).
- Fingerprint reader (Synaptics): no macOS driver.
- Tahoe runs hotter than Sequoia on UHD 620; ~30 min less battery.

&nbsp;

## ⚠️ Critical post-install steps for Tahoe 26 on this T480

The EFI alone gets you to the installer and a working desktop. Tahoe dropped support for our SMBIOS class (MacBookPro15,2 isn't on Apple's Tahoe supported list) and **removed AppleHDA entirely**, so two community-maintained patches are required after first boot:

### 1. Audio (AppleHDA gone in Tahoe)
Apple removed `AppleHDA.kext` from macOS 26 beta 2 onward. `AppleALC` is a Lilu plugin that patches AppleHDA — without the host kext you'll have NO audio. Fix:

**Option A (recommended):** Install [OCLP-Mod 3.0+ (laobamac fork)](https://github.com/laobamac/OCLP-Mod) or [OCLP-Plus (YBronst)](https://github.com/YBronst/OCLP-Plus). Open the app → enable AppleHDA root-patch → reboot. Re-apply after every macOS update.

**Option B (fallback):** Use [VoodooHDA-Tahoe (chris1111)](https://github.com/chris1111/VoodooHDA-Tahoe) installed to `/Library/Extensions`. Lower quality, no headphone auto-switching.

The EFI's `OCLP-Settings = -allow_fv -allow_amfi` NVRAM entry is already set for OCLP-Mod to function.

### 2. WiFi (Intel 8265 on Tahoe IOSkywalk stack)
The EFI blocks `IOSkywalkFamily` and ships `AirportItlwm` with a BCM4360 spoof so OCLP can root-patch the WiFi stack. After first boot:

```
sudo "/Applications/OpenCore-Legacy-Patcher.app/Contents/MacOS/OpenCore-Legacy-Patcher" --patch-sys-vol --patch-kexts
```

(Or use [OCLP-Mod's GUI](https://github.com/laobamac/OCLP-Mod) → Post-Install Root Patch → check Wi-Fi.) After patches apply, the BCM4360 spoof in `DeviceProperties` can be commented out and the native WiFi menu bar should function. **Browsing works, but AirDrop/Handoff/Continuity won't** — Intel WiFi hardware limit.

### 3. USB ports (Tahoe key rename)
Tahoe expects new port-personality property keys in `USBMap.kext`. Without the rename, USB-3 ports may degrade to USB-2 speeds. After first boot, run:

```
git clone https://github.com/corpnewt/USBMap.git
cd USBMap && python3 USBMapInjectorEdit.command
```

Drag the `USBMap.kext` from the mounted ESP → choose **"Update Keys for macOS 26 (Tahoe)"** → save. Then remount ESP and write the updated kext back.

### 4. SMBIOS serial verification (manual — Apple blocks programmatic checks)
Before first boot, open [checkcoverage.apple.com](https://checkcoverage.apple.com) in a browser and paste `C02ZLDZDJHCC`. Expected result: **"This serial number is not valid"**. If Apple recognizes it as a real Mac, regenerate via:

```
"Source Code/macserial" --model MacBookPro15,2 --generate --num 5
```

Pick the next unassigned one and update `PlatformInfo > Generic` in `config.plist`.

### 5. BIOS settings to set (one-time, in T480 firmware setup)
- Secure Boot → **Disabled**
- Intel SGX / PTT / Computrace → **Disabled**
- Fast Boot → **Disabled**
- Always-On USB → **Disabled** (critical for Thunderbolt 3 hotplug + sleep stability)
- Thunderbolt BIOS Assist Mode → **Disabled**
- Wake on Thunderbolt → **Disabled**
- TB Security Level → **User Authorization**
- TB Pre-Boot Support → **Enabled**
- VT-d → **Enabled** (the `DisableIoMapper` kernel quirk handles the macOS side)
- VT-x → **Enabled** · Hyper-Threading → **Enabled**
- CSM Support → **Disabled** · UEFI/Legacy → **UEFI Only**
- Sleep State → **Linux** (= S3, NOT "Windows 10" which is S0ix and breaks macOS sleep)
- Display → Total Graphics Memory → **512MB**

### 6. Post-install boot-arg cleanup
Once you've successfully booted 2-3 times, strip the verbose/debug flags from `boot-args`:

Remove: `-v keepsyms=1 debug=0x100` (keep the rest)

This gives a clean boot screen and cuts boot logging overhead.

&nbsp;

### Optional: if first install attempt panics with USBMap loaded
Tahoe's XHCI key schema changed; some users see a kernel panic referencing USB on first boot. If that happens:

1. Reboot from the USB installer.
2. At OpenCore picker, press **`O`** to enter Tools → OpenShell.
3. Mount the EFI partition of the USB, edit `config.plist`, set `USBMap.kext`'s `Enabled = False`.
4. Retry the install.
5. After macOS is fully installed, re-enable USBMap and (recommended) run `corpnewt/USBMap`'s `USBMapInjectorEdit.command` → "Update Keys for macOS 26 (Tahoe)" to refresh port keys.

Most builds don't hit this — `usb-port-number` keys are already in our USBMap and `USBToolBox.kext` 1.2.0 is loaded as the parent, which should cover it. The fallback above is for the edge case.

&nbsp;

### 7. CRITICAL: skip FileVault during Setup Assistant

Tahoe auto-enables FileVault for Apple-Account users. On a hackintosh without a real T2 chip, the APFS decryption path is **broken** — your next boot will be locked out with no recovery.

**On the first-boot Setup Assistant:**
- Choose **"Set Up for Myself"** then **"Don't sign in"** (skip Apple Account for now).
- Create a **local user account** with password.
- If FileVault is offered, choose **"Set up later in System Settings"** — never accept it during Setup.

You can sign into your Apple Account *after* boot from System Settings → Apple Account; just don't let Setup Assistant turn on FileVault.

&nbsp;

### 8. Post-install: sleep stability + Liquid Glass perf

Tahoe re-enables S4 hibernation each major update — kernel-panics on hackintosh. After first successful boot, run in Terminal:

```bash
sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0 powernap 0 ttyskeepawake 0 networkoversleep 0
sudo rm -f /var/vm/sleepimage
```

UHD 620 is underpowered for Tahoe's Liquid Glass UI — these defaults dramatically reduce WindowServer CPU/GPU load:

```bash
defaults write -g com.apple.SwiftUI.DisableSolarium -bool YES     # kills Liquid Glass shader entirely
defaults write -g NSAutoFillHeuristicControllerEnabled -bool false # fix typing-lag bug
defaults write -g NSAutomaticInlinePredictionEnabled -bool false   # fix cursor-stall bug
```

Then in System Settings:
- **Accessibility → Display → Reduce Transparency** = ON
- **Accessibility → Display → Reduce Motion** = ON
- **Spotlight → Search Results** → **uncheck** "Show Related Content" and "Help Apple Improve Search" (fixes `corespotlightd` 100% CPU + `mds_stores` runaway RAM)

Logout / login for the `defaults` changes to take effect.

&nbsp;

### 9. After every macOS update — re-apply

Tahoe minor updates (26.x → 26.y) wipe several things you'll need to re-apply:

1. **AppleHDA root patch** (audio dies otherwise) — open OCLP-Mod → Post-Install Root Patch → re-run.
2. **`pmset` hibernation block** — Tahoe upgrade resets `hibernatemode` to 3.
3. **Lilu / WhateverGreen / AppleALC / VirtualSMC** — update kexts in EFI **before** running the macOS update, not after. Otherwise the new kernel may not match.

&nbsp;

### 10. Heads-up: 49-day TCP overflow kernel bug (Apple, not fixed in 26.5)

XNU has a `uint32_t` millisecond counter that overflows at 49d 17h 2m 47s of uptime. When it does, ALL new TCP connections fail (ping still works). Apple hasn't patched it. T480 typically sleeps daily so you'll never see this, but if you keep the laptop running for ~6+ weeks straight, reboot before hitting the wall.

&nbsp;

## Troubleshooting (if you hit specific symptoms)

These are *contingent* fixes — only apply if you actually see the symptom.

| Symptom | Fix | Source |
|---|---|---|
| Audio dies after every macOS update (root patches reverted) | Switch from OCLP-Mod's AppleHDA root patch to [chris1111/VoodooHDA-Tahoe](https://github.com/chris1111/VoodooHDA-Tahoe) installed to `/Library/Extensions` — survives updates without re-patching. Lower quality but zero maintenance. | T490 #73, MML #49 |
| Headphone jack distorted / weak after sleep wake | Apply [lolipuru's AppleALC WakeConfigData patch](https://github.com/lolipuru/Thinkpad-T480-Opencore/commit/4981a8d) to layout-86 codec in `AppleALC.kext/Contents/Info.plist` (EAPD + Pin Widget Control verbs added). | EETagent #10, valnoxy #160/162 |
| CPU stuck at 600-800 MHz after 1+ sleep cycles (BD-PROCHOT throttle stuck) | Add [DisablePROCHOT.efi](https://github.com/arter97/DisablePROCHOT) to UEFI Drivers + [SimpleMSR.kext](https://github.com/lvs1974/SimpleMSR) to Kernel.Add. Re-enables PROCHOT clear after each S3 wake. | T490 #44 |
| External HDMI displays with color banding / yellow tint | Try `AAPL,ig-platform-id = <0000C087>` (UHD 617 spoof) instead of `<00001659>` (UHD 620 native). Test, revert if it breaks internal. | EETagent #60/82, bugtracker #1159 |
| External display only works after physical re-plug post-wake | MBP15,2 SMBIOS lacks HDMI port descriptor. Use USB-C→HDMI adapter, or experiment with MBP16,3 SMBIOS. | valnoxy #154 |
| Thunderbolt 3 hot-plug or DP-alt-mode fails | Update Thunderbolt EEPROM (NVM23) from Windows: download `n24th13w.exe` from [Lenovo TB3 firmware](https://support.lenovo.com/us/en/downloads/ds502613). Stock NVM20 causes hotplug failures. | T490 #64, Lenovo |
| Random Bluetooth dongle failed messages | Two NVRAM keys under `7C436110...`: `bluetoothExternalDongleFailed=00`, `bluetoothInternalControllerInfo`=11 null bytes. **Already in this EFI** — just noting cause if you see logs. | valnoxy #115/104 |
| iMessage / FaceTime activation fails repeatedly | Intel WiFi hardware limit. Either disable SIP temporarily during activation, or hardware-swap to Broadcom DW1560 / BCM94352Z (M.2 2230, ~$15). | OpenIntelWireless #942 |
| CMOS checksum bad / boot loop after long (>1h) sleep | Already mitigated by `rtcfx_exclude=80-AB` + RTCMemoryFixup + HibernationFixup. If still happens, add `Booter.ReservedMemory` dict for RTC region per [OpenCorePkg 76bf9bd](https://github.com/acidanthera/OpenCorePkg/commit/76bf9bd). | T490 #35, EETagent #20 |
| Samsung 970 EVO Plus NVMe acting up post-wake | Disable NVMeFix in Kernel.Add. SM2263 in this build is fine with NVMeFix enabled. | bugtracker #1645 |
| OpenCore picker doesn't show Windows dual-boot | Re-scan disks (`d` in picker), increase `Misc.Boot.Timeout`, ensure `OpenLinuxBoot.efi` placement is correct. | valnoxy #97 |

&nbsp;

## One-shot install USB builder: `create-install-usb.sh`

Run on Linux to build the install USB end-to-end with no manual file copying:

```bash
./create-install-usb.sh                          # TUI: pick USB drive interactively
./create-install-usb.sh --dry-run                # print what would happen, no destructive ops
./create-install-usb.sh --device /dev/sdX --yes  # automation (CAREFUL)
```

The script:
1. Installs missing deps (`whiptail`, `parted`, `dosfstools`, `hfsprogs`, `dmg2img`) via `dnf`/`apt`.
2. Validates `EFI - Tahoe/EFI/` via `ocvalidate`.
3. Whiptail TUI lists USB drives; hard-excludes your system disk.
4. Triple confirmation before any write.
5. Downloads macOS Tahoe recovery via `macrecovery.py` (~700 MB).
6. Partitions GPT: 300 MiB ESP (FAT32) + remainder HFS+.
7. `rsync`s `EFI - Tahoe/EFI/` to ESP; `dd`s `BaseSystem.dmg` to the recovery partition.
8. Verifies the result.

Logs to `/tmp/t480-usb-builder-<timestamp>.log`. Internal NVMe is never touched.

<a href="https://github.com/OpenIntelWireless/HeliPort/releases"><strong>
Download HeliPort app »</strong></a>

<details>
<summary><strong>💻 My Hardware</strong></summary>
<br>
These are the Hardware component I use. But this OpenCore configuation <strong>should still work</strong> with your device, even if the components are not equal.

> **Note** Check the model of your WiFi & Bluetooth card. Intel cards should be compatible with itlwm (or AirportItlwm). If your card is from another manufacturer, please check if your card supports macOS.

| Category  | Component                            |
| --------- | ------------------------------------ |
| CPU       | Intel Core i5-8350U                  |
| GPU       | Intel UHD Graphics 620               |
| SSD       | Pioneer APS 1TB SATA SSD		   |
| Memory    | 24GB DDR4 2400Mhz                    |
| Camera    | 720p Camera                          |
| WiFi & BT | Intel 18265 Wifi 	                   |

</details>  

</details>

<details>  
<summary><strong> 📸 Photos </strong></summary>
</br>

![IMG_2310](https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480/assets/72415505/b347f8fb-5dd1-4f3e-a24b-30a7f39c7c0c)
![IMG_2178](https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480/assets/72415505/d055f1cb-c093-49d1-ad91-81d56e7d1f8d)
![IMG_2130](https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480/assets/72415505/309a9feb-3264-425c-ad2e-c46104a2f0b8)
![IMG_1279](https://github.com/MultimediaLucario/Lenovo-ThinkPad-T480/assets/72415505/a9a4d6a2-ea6a-4045-8c1d-b6f5050cc2a9)


</details>  

</details>


&nbsp;

## Installation

<details>  
<summary><strong> ⚠️ Anti-Piracy Warning / Disclaimer ⚠️ </strong></summary>
</br>
	
### ⚠️ PIRACY IS NO PARTY! ⚠️
I do not endorse or condone the use of pre-configured Hackintosh Distros because not only they cause unnecessary harm to your machine but it is considered to be a form of **Software Piracy**. Software Piracy is a serious crime according to copyright law and is punishable for up to 10 years in prison. 
</details>



<details>  
<summary><strong> ⚠️ Important Information for any i7 and/or macOS Sonoma Users ⚠️ </strong></summary>
</br>
	
### 🛜 AirPortItlwm for So is still not stable yet! 🛜
If you're using a ThinkPad T480, T480s or X280 that either is rocking an Intel Core i7 CPU and/or is running macOS Sonoma, please be aware that the ```AirPortItlwm``` kext is **NOT STABLE** yet. What I mean is that while the kext actually functions, **you will not be able to access any iServices (iMessage, FaceTime,etc.).** In order to have any access to iServices, please use the ```itlwm``` kext along with the ```HeliPort``` application until the ```AirPortItlwm``` kext is updated.
</details>


<details>  
<summary><strong>📝 Requirements</strong></summary>
</br>

You must have the following items:
- Lenovo ThinkPad T480 (Obviously 😁).
- Access to a working Windows machine with Python installed.
- A pendrive with more than 4 GB (Remember that during the preparation we will format the flash drive to create the installation media). (For Sequoia and newer, you'll need a drive with 32 GB of storage because Sequoia and newer only work with the offline installer for now.)
- an Internet connection (recommended via Ethernet).
- 1-2 hours of your time.

</details>

<details>  
<summary><strong>⚙️ macOS Sequoia Installer Guide</strong></summary>
</br>

**Since Wi-Fi does not work until you apply a post-install patch, the only way to install Sequoia is through the offline installer method.**

Step 1: Download macOS Installer on Windows. Use gibMacOS to download the macOS installer.

- [![Download](https://img.shields.io/badge/Download-gibmacOS-red.svg)](https://github.com/corpnewt/gibMacOS)
- Extract and run gibMacOS.bat in Windows.
- When the terminal opens, you’ll see a list of macOS versions. Select macOS 15 Sequoia by entering its index number.
- Wait for the download to complete; it will save the files in a new directory.

Step 2: Convert the Downloaded Files into an Installer

You need to use a macOS or macOS virtual machine to convert these .pkg files into a macOS installer. Here’s how:

- Copy the downloaded folder from your Windows machine to a macOS machine or a virtual macOS environment.
- On the macOS machine:
	Open Terminal and navigate to the folder containing the downloaded files. Run the following command:bashCopy codesudo installer -pkg InstallAssistant.pkg -target /Applications
	This command will install the macOS installer to your Applications folder.
	After running this command, you should now see Install macOS Sequoia in the Applications folder on macOS.

- With the installer on macOS, follow these steps to make the USB bootable:

	Insert the USB drive into the macOS system.
	Open Disk Utility, select the USB drive, and format it as Mac OS Extended (Journaled) with the GUID Partition Map scheme. Name it something like MyUSB.
	Open Terminal and run the following command, which will create a bootable USB with the macOS installer:Replace MyUSB with the name of your USB drive if different.bashCopy code sudo /Applications/Install\ macOS\ Sequoia.app/Contents/Resources/createinstallmedia --volume /Volumes/MyUSB
	This will erase the USB and copy the installer files onto it, making it bootable.

Step 3: Copy OpenCore Files to the USB Drive

- Mount the USB drive, and within the EFI partition, copy over the EFI folder that you configured with OpenCore.
Now your USB should be fully prepared to boot into macOS Sequoia via OpenCore.



</details>

<details>  
<summary><strong>⚙️ Preperation</strong></summary>
</br>

### Create the install media

First of all, you will need the install media of macOS. I will use [macrecovery](https://github.com/acidanthera/OpenCorePkg) to download and create the macOS Install media.

With macrecovery, the process is the following:
- Download [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg) as a ZIP.
- Extract the OpenCorePkg-master.zip file.
- Open ```cmd.exe``` with Administrator privileges and change the directory to OpenCorePkg-master\Utilities\macrecovery.
- Enter the following command to download macOS:
```
# Monterey (12)
python macrecovery.py -b Mac-E43C1C25D4880AD6 -m 00000000000000000 download

# Ventura (13)
python macrecovery.py -b Mac-7BA5B2D9E42DDD94 download

# Sonoma (14)
python macrecovery.py -b Mac-CFF7D910A743CAAF -m 00000000000000000 download
```
- After the download succeeded, type ```diskpart``` and wait until you see ```DISKPART>```

- Plug-in your pendrive and type ```list disk``` to see your disk id.

- Select your pendrive by typing ```select disk <diskid>```

- Now we are gonna clean the pendrive and convert it to GPT. First, type ```clean``` and then ```convert gpt```.

>  **Note**: If an error occurred, try to convert again by typing ```convert gpt```.

- After the pendrive is clean and converted, we will create a new partition where we can put our files on. First, type ```create partition primary```, then select the new partition with ```select partition 1``` and format it ```format fs=fat32 quick```.

- Finally, mount your pendrive by typing ```assign```

- Now, close the Command Prompt and create the folder ```com.apple.recovery.boot``` on the pendrive. Copy ```OpenCorePkg-master\Utilities\macrecovery\BaseSystem.dmg``` and ```Basesystem.chunklist``` into that folder.

>  **Note**: If you can't find BaseSystem.dmg, use RecoveryImage.dmg and RecoveryImage.chunklist instead.

After the install media was created, we need to make the USB drive bootable.

### Configure and install OpenCore
Download the EFI folder from this repo, you will find the latest files under the release tab or just download the repo as it is. Move the folder to the root of your pendrive (e.g. J:\) and rename the folder to ```EFI```.

#### GenSMBIOS
We need a script, called [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS), to create fake serial number, UUID and MLB numbers. **This step is essential to have working iMessage, so do not skip it!**

The process is the following:

- Download GenSMBIOS as a ZIP, then extract it.
- Start GenSMBIOS.bat and use option ```1``` to download MacSerial.
- Choose option ```2```, to select the path of the config.plist file. It will be located in ```EFI -> OC``` folder.
- Choose option ```3```, and enter ```MacBookPro15,2``` as the machine type.
- Press ```Q``` to quit. Your config now should contain the requied serials.

#### Enter the proper ROM value
After adding serials to your config.plist, you have to add the computer's MAC address to the config.plist file. **This step is also essential to have a working iMessage, so do not skip it.** We need a Plist editior, to write the MAC address into the config.plist file. I used [ProperTree](https://github.com/corpnewt/ProperTree), since it works on Windows too. You have to change the MAC address value in the config.plist at

```PlatformInfo -> Generic -> ROM```

Delete the generic ```112233445566``` value, and enter your MAC address into the field, without any colons. Save the Plist file, and it is now ready to be written out to the EFI partition of your install media.

#### Default keyboard layout and language
The default keyboard layout and language is ```German```. To change the language, edit the value of ```NVRAM -> Add -> 7C436110-AB2A-4BBB-A880-FE41995C9F82 -> prev-lang:kbd``` to the value of your language. If your value contains an underscore "```_```", replace it with a hyphen "```-```". The value for English would be ```en-US:0```. You can find a list of all language values [here](https://github.com/acidanthera/OpenCorePkg/blob/master/Utilities/AppleKeyboardLayouts/AppleKeyboardLayouts.txt).

##### ACPI patches
Please enable / disable the following patches depending on what is installed in your device.

| SSDT              | Affected device            | Description                                                |
| ----------------- | -------------------------- | ---------------------------------------------------------- |
| SSDT-ARPT.aml     | Broadcom cards             | Disable Broadcom card during sleep                         |
| SSDT-OFFTB.aml    | Thunderbolt                | Disable Thunderbolt                                        |
| SSDT-OFFGDGPU.aml | NVIDIA GeForce MX 150      | Disable NVIDIA GPU (necessary if installed)                |

### Install OpenCore
After you've finished with the neccesary tweaks, you have to copy the EFI folder to the EFI partition of your pendrive.

</details>

<details>  
<summary><strong>🚚 Installation</strong></summary>
</br>

### Prepare BIOS
The bios must be properly configured prior to installing macOS.
In Security menu, set the following settings:

-  `Security > Security Chip`: must be **Disabled**
-  `Memory Protection > Execution Prevention`: must be **Enabled**
-  `Virtualization > Intel Virtualization Technology`: must be **Enabled**
-  `Virtualization > Intel VT-d Feature`: must be **Enabled**
-  `Anti-Theft > Computrace -> Current Setting`: must be **Disabled**
-  `Secure Boot > Secure Boot`: must be **Disabled**
-  `Intel SGX -> Intel SGX Control`: must be **Disabled**
-  `Device Guard`: must be **Disabled**

In Startup menu, set the following options:

-  `UEFI/Legacy Boot`: **UEFI Only**
-  `CSM Support`: **No**

In Thunderbolt menu, set the following options:

-  `Thunderbolt BIOS Assist Mode`: **UEFI Only**
-  `Wake by Thunderbolt(TM) 3`: **No**
-  `Security Level`: **No**
-  `Support in Pre Boot Environment > Thunderbolt(TM) device`: **No**

Now you can go through the install.

### Install macOS
1. Boot from USB, press ```SPACE``` and select the USB drive inside of OpenCore ```"NO NAME (DMG)" or similar```.
>  **Note:** The first boot may take up to 20 minutes.
2. Wait for the macOS Utilities screen.
3. Select Disk Utility, select your disk and click erase. Give a name and choose **APFS** with **GUID Partition Map**.
4. After erasing, go back and select **Reinstall macOS** and follow the steps on your screen. The installation make take up to **2 hours**.
>  **Note:** Your PC will restart multiple times. Just boot from USB and select your disk inside of OpenCore. (named macOS Installer or the disk name).
5. Once you see the `Region selection` screen, you are good to proceed.
6. Create your user accound and everything else.

</details>

<details>  
<summary><strong>♻️ Upgrade macOS / Switch EFI</strong></summary>
</br>

If you plan to upgrade your macOS (or updating the EFI / switching to HeliPort), you'll need a different OpenCore configuation (EFI). Please follow these steps:

> Note: Download the desired macOS version in the Settings before following these steps, if you are connected via WiFi.

1. Download the newest release & [ProperTree](https://github.com/corpnewt/ProperTree) and extract it.
2. Start ProperTree and load the ```Config.plist``` on your EFI partition. (File -> Open)
> Note: You can mount your EFI partition by pressing ```ALT + SPACE```, typing Terminal and enter the following command: ```sudo diskutil mountDisk disk0s1```.
3. Now also load the new configuration file from the repo for the desired macOS installation (or HeliPort config). 
4. You should now have 2 ProperTree-windows open on your screen.
5. Go in both windows to ```Root -> PlatformInfo -> Generic```. Transfer ```MLB, ROM, SystemProductName, SystemSerialNumber and SystemUUID``` to the new config. 
6. Save the new config (File -> Save) and close both windows.
7. Now delete your existing EFI folder from the EFI partition and copy the new one to it. (Make sure that the Directorys ```Boot and OC``` are in ```EFI```).

If you want to upgrade macOS, download the desired macOS version in the Settings app and perform the upgrade like on a real Mac.

</details>

&nbsp;

## Post-Install Guide

<details>  
<summary><strong>💾 Install OpenCore to your boot drive</strong></summary>
</br>

1. Press `ALT + SPACE` and open terminal. Type `sudo diskutil mountDisk disk0s1` (where disk0s1 corresponds to the EFI partition of the main disk)
2. Open Finder and copy the EFI folder of your USB device to the main disk's EFI partition.
3. Unplug the USB device and reboot your laptop. Now you can boot macOS without your USB device.

</details>

<details>  
<summary><strong>✏️ Create an offline installer (Optional)</strong></summary>
</br>

In case of reinstalling macOS, a offline install media can save some time. You also don't need an Ethernet connection for the installation.
To create a offline install media, you need the following stuff: 

- macOS Installer from the App Store.
- A 16 GB pendrive (Keep in mind, during the preperation we will format the disk to create the install media).

Press `ALT + SPACE` and open Disk utility. Select your USB device and click erase. Name it `MyUSB` and choose **Mac OS Extended** with **GUID Partition Map**. After erasing the USB device, close Disk utility.

Now press `ALT + SPACE` and open terminal. Type the following command:

Big Sur:
```sudo /Applications/Install\ macOS\ Big\ Sur.app/Contents/Resources/createinstallmedia --volume /Volumes/MyUSB --downloadassets```

Monterey:
```sudo /Applications/Install\ macOS\ Monterey.app/Contents/Resources/createinstallmedia --volume /Volumes/MyUSB --downloadassets```

After creating the install media, copy your EFI folder to the EFI partition of your USB device.

</details>


<details>  
<summary><strong>🛜 Intel Wi-Fi Patch for macOS Sequoia </strong></summary>
</br>

**Intel Wi-Fi does not work on macOS Sequoia unless you install this patch.**

> Credit to [ResQre](https://github.com/ResQre) for these instructions

What you need
- Intel Wi-Fi Card (of course)
- Hackintool (for device path) + your favorite plist editor (in my case, OCAuxiliaryTools)
- [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) 

1. Open Hackintool and go to the Pcie menu, look for where it says "Intel Wireless" (in my case, Wireless 8260).
![ภาพถ่ายหน้าจอ 2024-12-26 เวลา 1 49 07 AM](https://github.com/user-attachments/assets/93566ae7-5b73-47ba-8d26-b1241e8c8dda)

2. Open a .plist editor (in this case, we'll use OCAuxiliaryTools), add the device path (without #), then add the following device details:

| Key   |      Data Type      |  Value |
|----------|:-------------:|:------:|
| IOName |  String | pci14e4,43a0|
| compatible |    String   | pci106b,117 |
| device-id | Data | A0430000 |
| device_type | String | Network Controller |
| model | String | BCM4360 802.11ac Wireless Network Adapter |
| name | String | pci14e4,43a0 |
| pci-aspm-default | Number | 0 |
| subsystem-id | Data | 17010000 |
| subsystem-vendor-id | Data | 6B100000 |
| vendor-xt | Data | E4140000 |

It should look like this:

![image](https://github.com/user-attachments/assets/2a7b1d5b-29a7-4740-aaba-9ce1eb661f3f)


Press save and reboot (no need for setting the kext up since it's already presented inside of the efi.)

3. If you done the setup correctly, you should be able to install the OCLP root patch.

![ภาพถ่ายหน้าจอ 2024-12-26 เวลา 2 36 01 AM](https://github.com/user-attachments/assets/6a44dd01-c7cf-4db5-8db7-e54683529687)

4. Install the patch, then you can remove the spoof id (or add the # instead) and Intel Wi-Fi should work without the need for Heliport.

![ภาพถ่ายหน้าจอ 2024-12-26 เวลา 2 41 25 AM](https://github.com/user-attachments/assets/8b7edcd6-3416-4b81-8f3f-192605804a65)


</details>


<details>  
<summary><strong>🎧 Fix Audio </strong></summary>
</br>
	
**One of macOS's most imfamous post-install issues is a glitch with the AUX port. Everytime I update the EFI always causes a problem with my audio patch. "Give one a fish you feed them for a day but teach one how to fish and you feed them for a lifetime."  So, here is a guide on how to fix the audio yourself.**

<details>  
<summary><strong>Required Tools</strong></summary>
</br> 

- [OpenCore Configurator](https://mackie100projects.altervista.org/download-opencore-configurator/?doing_wp_cron=1741176165.9179310798645019531250)
- [Hackintool](https://github.com/benbaker76/Hackintool/releases)
- Your macOS USB pendrive with your EFI loaded in case of any errors

</details>

<details>  
<summary><strong>Instructions</strong></summary>
</br> 

1. Download and install both [OpenCore Configurator](https://mackie100projects.altervista.org/download-opencore-configurator/?doing_wp_cron=1741176165.9179310798645019531250) and [Hackintool](https://github.com/benbaker76/Hackintool/releases).
2. Open Hackintool, navigate to the ```Sound``` section, then go to the bottom half where it says ```Audio Info```. There, you will find a little drop down menu that is labled ```ALC Layout ID```. Click on the drop down menu and you will find a couple different numbers to choose from. These are the potential audio layout ids that can work for your system. Make sure to keep track of them.
3. Open OpenCore Configurator, select ```Tools``` up in the menubar, and then select ```Mount EFI```. Go to the EFI partition for your boot drive, click ```Mount Partition```, and enter your macOS password.
4. Now, go to the menubar, select ```File```, ```Open```, and then Go to the drive that says ```EFI```, open the folder ```EFI```, double click on the ```OC``` folder and the file named ```Config.plist```.
5. Go to ```NVRAM```, the codes listed in this section are the UUIDs. Click on the 3rd one that starts with ```7C``` and navigate to the ```boot-args``` section.
6. In the ```boot-args``` section, go to the part where it says ```Value``` , right click to open the menu and navigate to ```boot-args```, ```AppleALC```, and select ```alcid=layoutid```.
7. Change the layoutid part of ```alcid=layoutid``` to one of the numbers presented in Hackintool (ex: ```alcid=86```), save the config.plist and restart your computer. (Make sure to go through each and every one of those ID numbers until you find the one that works the best with your system.)
8. Congratulations, you've successfully fixed the audio for your T480! 🥳

</details>



</details>

<details>  
<summary><strong> 💻 Change System Information (GenSMBIOS)  </strong></summary>
</br>

1. Run the following script in Terminal:

```git clone https://github.com/corpnewt/GenSMBIOS && cd GenSMBIOS && chmod +x GenSMBIOS.command && ./GenSMBIOS.command```

2. Mount your EFI partition using [OpenCore Configurator](https://mackie100projects.altervista.org/download-opencore-configurator/?doing_wp_cron=1741176165.9179310798645019531250).
3. Go to your EFI partition, enter the EFI folder, then the OC folder and then look for the file known as ```Config.plist```.
4. Go back to ```GenSMBIOS``` , type 2 and hit ENTER to then drag your ```Config.Plist``` file into the command line, press ENTER when finished.
5. Type 3 to Generate SMBIOS, then press ENTER. Type ```MacbookPro15,2``` then press ENTER. Leave this Terminal window open.
6. Type 4 to Generate UUID and press ENTER.
7. Type 5 to Generate ROM and press ENTER.
8. Type Q to Quit and press ENTER.
9. Restart your ThinkPad and enjoy!
</details>

</details>

<details>  
<summary><strong> 🖥️ Intel UHD 620 Graphics Patch  </strong></summary>
</br>

## This patching guide for the Intel UHD 620 GPU not only gives you better Graphics Acceleration but it improves the docking audio and video compatibility as well.

Required Tools: [OpenCore Configurator](https://mackie100projects.altervista.org/download-opencore-configurator/?doing_wp_cron=1741176165.9179310798645019531250).

1. Open [OpenCore Configurator](https://mackie100projects.altervista.org/download-opencore-configurator/?doing_wp_cron=1741176165.9179310798645019531250), mount your EFI partition and open your Config.Plist file.
2. Go to ```DeviceProperties``` and in the section that says ```Devices``` select the middle option as that is where all of the juicy iGPU information is stored.
3. Look for the key known as ```AAPL,ig-platform-id```, select the code that is right next to it and change that from the default value to ```0000C087```.
4. Save the ```Config.Plist``` file in [OpenCore Configurator](https://mackie100projects.altervista.org/download-opencore-configurator/?doing_wp_cron=1741176165.9179310798645019531250) and restart your ThinkPad.
5. Congratulations, you've successfully patched the iGPU in your ThinkPad! Now you have improved performance and improved video and audio output support! 🥳
</details>
 
&nbsp;

## Status

<details>  
<summary><strong>✅ What's working</strong></summary>
</br>
 
- [X] Intel WiFi & Bluetooth ([Itlwm](https://github.com/OpenIntelWireless/itlwm) + [Heliport](https://github.com/OpenIntelWireless/HeliPort/releases) for macOS Sonoma users.)
- [X] Brightness / Volume Control
- [X] Battery Information
- [X] Audio (Audio Jack & Speaker)
- [X] USB Ports & Built-in Camera
- [X] Graphics Acceleration
- [X] Trackpoint / Touchpad
- [X] Power management / Sleep
- [X] FaceTime / iMessage (iServices)
- [X] HDMI
- [X] Automatic OS updates
- [X] Handoff / Universal Clipboard
- [X] Sidecar (Cable) / AirPlay to Mac
- [X] SIP / FireVault 2
- [X] USB-C

</details>

<details>  
<summary><strong>⚠️ What's not working</strong></summary>
</br>

- [ ] Safari DRM ```Use Chromium powered Browser or Firefox to watch Amazon Prime Video, Netflix, Disney+ and others```
- [ ] AirDrop & Continuity
- [ ] Fingerprint Reader (Disabled with NoTouchID kext)
- [ ] Thunderbolt 3
- [ ] Sidecar Wireless
- [ ] Apple Watch Unlock

</details>

<details>  
<summary><strong>🔄 Not tested</strong></summary>
</br>

- [ ] WWAN
- [ ] Dualbooting Windows / Linux (with OpenCore)

</details>

&nbsp;

## ⭐️ Feedback
Did you find any bugs or just have some questions? Feel free to provide your feedback using the Discussions tab.

&nbsp;

## 📜 License

This repo is licensed under the [MIT License](https://github.com/valnoxy/t480-oc/blob/main/LICENSE).

OpenCore is licensed under the [BSD 3-Clause License](https://github.com/acidanthera/OpenCorePkg/blob/master/LICENSE.txt).

<hr>
<h6 align="center">© 2018 - 2022 valnoxy. All Rights Reserved. 
<br>
By Jonas Günner &lt;jonas@exploitox.de&gt;</h6>
<p align="center">
	<a href="https://github.com/valnoxy/t480-oc/blob/main/LICENSE"><img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&logoColor=d9e0ee&colorA=363a4f&colorB=b7bdf8"/></a>
</p>
