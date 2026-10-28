# LidGuard

A macOS menu bar app that cuts Wi-Fi and Bluetooth when you close the lid on
battery, and puts them back exactly as they were when you open it again.

On AC power it does nothing.

## The problem

An Apple Silicon MacBook can drain flat overnight with the lid closed on battery
because it never reaches deep sleep. The Wi-Fi chip wakes the SoC every time an
inbound IP packet matches its wake filter.

The measurement that started this, from a real overnight window:

| | |
|---|---|
| Charge at lid close, 03:58 | 39% |
| Charge at 11:46 | 1%, then force hibernate |
| Dark wakes in 7h47m | **3141** |
| Median interval between wakes | **8 to 9 seconds** |
| Time spent in dark wake | 10293s of 28020s, **37% of the night** |
| Drain rate | ~5%/hour |
| Wakes tagged `E_RX_IP_PACKET ARPT` | 3139 of 3141 |

Every dark wake carried the same reason string:

```
wifibt SMC.OutboxNotEmpty centauri-alpha E_RX_IP_PACKET ARPT
```

For scale, every other day in the retained `pmset` log had between 10 and 70
Wi-Fi dark wakes in total.

## Why the usual advice does not work

`powernap`, `womp` and `tcpkeepalive` were all already `0` on the battery profile.
None of them suppress `E_RX_IP_PACKET`. That wake filter lives on the NIC, so the
only reliable fix is to turn the radio off.

macOS Shortcuts cannot do it either. It has a "When my Mac wakes" trigger but no
sleep or lid-close trigger, and automations run in a user session that is gone
during the sleep transition. It can do the restore half and none of the cutoff
half.

The supported mechanism is `NSWorkspace.willSleepNotification`, which is what this
app uses.

## What it does

- **On sleep, on battery**: saves the current Wi-Fi and Bluetooth states, then
  turns both off. If a state is already saved it is not overwritten, so a sleep
  following a dark wake cannot clobber the real one.
- **On wake**: if the lid is still closed it does nothing, so dark wakes cannot
  re-arm the radios. Only a real lid open restores.
- **On quit**: restores the radios and stops managing them entirely.
- **On launch**: recovers if a previous run was killed with the radios off.
- **On AC**: nothing at all.

Every transition is logged with power source, charge, lid state and both radio
states, read back from the system after each change so a silently failed toggle
is visible rather than assumed.

## Install

Requires macOS 13 or later.

```
git clone https://github.com/adipascu/LidGuard.git
cd LidGuard
./scripts/build-app.sh
cp -R build/LidGuard.app /Applications/
open -a /Applications/LidGuard.app
```

The app is ad-hoc signed, so on first launch macOS may block it. Right click the
app, choose Open, then confirm.

### Launch at login

Off by default. The first launch offers it as a recommended option, and you can
change it any time from the menu bar. Scriptable too:

```
/Applications/LidGuard.app/Contents/MacOS/LidGuard --enable-login-item
/Applications/LidGuard.app/Contents/MacOS/LidGuard --disable-login-item
/Applications/LidGuard.app/Contents/MacOS/LidGuard --status
```

## Menu

| Item | Meaning |
|---|---|
| Status line | current state and battery percentage |
| Active | pause or resume without quitting |
| Cut Bluetooth too | Wi-Fi only, or both radios |
| Launch at Login | register or unregister the login item |
| Open Log | opens `~/Library/Logs/LidGuard.log` |
| Quit LidGuard | restores radios and stops managing them |

## Logging

`~/Library/Logs/LidGuard.log`, rotated at 1 MB.

```
23:55:58 INFO  app: launching version 1.0.0
23:55:58 INFO  core: started power='Battery Power' charge=70% lid=open wifi=on bluetooth=starting
23:56:01 INFO  radio: Bluetooth ready, state=on after 2.58s
01:12:44 INFO  sleep: fired power='Battery Power' charge=80% lid=closed wifi=on bluetooth=on
01:12:44 INFO  sleep: saved wifi=on bluetooth=on charge=80%
01:12:44 INFO  sleep: cut radios, verified wifi=off bluetooth=off
08:34:02 INFO  wake: dark wake with lid closed, charge=79%, radios stay off
09:01:19 INFO  wake: wake, restored wifi=on bluetooth=on wanted wifi=on bluetooth=on
09:01:19 INFO  wake: asleep 7h48m35s charge 80% -> 79% drain 1%
```

The last line gives drain per sleep cycle directly.

## Two findings worth writing down

**`blueutil` hangs under `launchd`.** The first version of this was a
`sleepwatcher` LaunchAgent. Called from a LaunchAgent, `blueutil` blocks forever
and times out, with or without `LimitLoadToSessionType = Aqua`, because Bluetooth
control needs a TCC grant a background agent cannot prompt for. `networksetup`
works fine in the same context. That matters a lot: a hang in a sleep hook holds
the IOKit sleep acknowledgement and stops the Mac sleeping at all, which is worse
than the drain. A real `.app` does not have this problem.

**The first `IOBluetooth` call from a freshly signed bundle can take 16 seconds.**
Measured at 16.56s once, 2.58s typically, then effectively zero. Because the app
is ad-hoc signed, every rebuild is a new identity to TCC. So Bluetooth is never
called synchronously on the main thread or on the sleep path. It is warmed up in
the background at launch and cached, and the sleep path skips it entirely if it is
not ready yet, so closing the lid is never delayed.

## Architecture

| File | Role |
|---|---|
| `main.swift` | entry point and CLI flags |
| `AppDelegate.swift` | lifecycle and first-run onboarding |
| `StatusItemController.swift` | menu bar item and menu |
| `LidGuardCore.swift` | sleep and wake logic, state persistence |
| `RadioController.swift` | CoreWLAN for Wi-Fi, cached async IOBluetooth |
| `PowerMonitor.swift` | IOPS power source and charge |
| `ClamshellMonitor.swift` | IORegistry `AppleClamshellState` |
| `Settings.swift` | UserDefaults and `SMAppService` login item |
| `Log.swift` | rotating file log |
| `Sources/CBluetoothShim` | C shim, `IOBluetooth` power functions are not exposed to Swift |

No third-party dependencies.

## Root cause of the original drain

Never established, and the app works regardless. Candidates, in the order the
evidence supports them:

- **TCP retransmissions from open sessions.** The storm began seconds after heavy
  browser video, audio and messaging use. Remote peers keep sending to a sleeping
  Mac and every inbound packet is an `E_RX_IP_PACKET`. Fits the 8 to 9 second
  cadence better than anything else. Untested.
- **A Chromecast / Android TV on the LAN.** Cast mDNS chatter is a documented wake
  source. Measured directly, it sent 2 packets in 86 seconds, nowhere near the
  observed cadence, so this is unsupported. It was likely in standby during the
  measurement, so not fully ruled out.
- **A Bluetooth BLE reconnection loop.** Documented on this exact model producing
  ~10 second wakes. The wake string says `ARPT`, which points at Wi-Fi, not BLE.
- **Router firmware.** In the most cited Apple thread on this symptom the reporter
  retracted the mDNS theory and the real cause was AP firmware.

The famous 2018 Chromecast mDNS flooding bug is **not** this. That was fixed in
January 2018 and the fault was in the Cast software on Android phones, not the
hardware.

## License

MIT
