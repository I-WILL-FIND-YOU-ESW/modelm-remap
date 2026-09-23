# modelm-remap

Remap keys on an **IBM Model M** that is connected through a **Soarer's
Converter** adapter — press a key, pick what it should become, and the tool
rewrites the converter's EEPROM so the change survives unplugging and works on
any computer.

Built for the common Mac case: the Model M has no Command key, so people remap
`RALT`/`RCTRL`/`CAPS_LOCK` to **Command**. On macOS, Command is the USB "GUI"
key, so the target token is `LGUI` (left ⌘) or `RGUI` (right ⌘).

```
modelm-remap  ·  Soarer's Converter
  adapter  Soarer's Keyboard Converter  (USB 16c0:047d)
  firmware v1.12   EEPROM 1024 bytes (990 bytes free)

STEP 1 — Press the key you want to remap.
  Press it on the IBM Model M now (Ctrl-C to abort)…
  ✔ Detected: RALT  (Option (right) ⌥, code 0x40)

STEP 2 — What should RALT do?
    Command / Mac modifiers
      1  LGUI   Command (left)   ⌘
      2  RGUI   Command (right)  ⌘
      ...
```

## Install

The low-level tools are vendored under `vendor/bin` and built once:

```sh
./build.sh          # clones thentenaar/sctools and compiles scas/scdis/sctool
```

`build.sh` needs only Xcode command-line tools (`clang`) — no Homebrew, no
autotools. `sctool` is compiled against the bundled hidapi macOS backend.

Put the CLI on your `PATH` (optional):

```sh
ln -sf "$PWD/modelm-remap" ~/.local/bin/modelm-remap
```

## Usage

```sh
modelm-remap                          # interactive wizard (the main flow)
modelm-remap --from RALT --to LGUI --dry-run   # preview, write nothing
modelm-remap set RALT LGUI            # non-interactive, with confirmation
modelm-remap set RCTRL RGUI -y        # no confirmation prompt
modelm-remap screenshot               # press a key -> Cmd+Shift+4 (region screenshot)
modelm-remap screenshot --from F10    # same, trigger key given up front
modelm-remap macro                    # press a key -> choose a shortcut to send
modelm-remap shortcut F10 CMD+SHIFT+4 # non-interactive shortcut macro
modelm-remap listen                   # print keys as you press them
modelm-remap show                     # config currently stored in the converter
modelm-remap keys CMD                 # list/search valid key names
modelm-remap info                     # firmware + EEPROM info
modelm-remap read backup.scb          # save the whole config
modelm-remap restore backup.scb       # write a saved config back
```

Options: `--dry-run` (show the result, don't write), `--yes/-y` (skip the
confirm prompt), `--timeout N` (key-capture timeout), `--bin-dir DIR`.

## How it works

A Soarer's Converter exposes three HID interfaces:

| Interface | Usage page | Used for |
|---|---|---|
| keyboard | `0x0001` | normal typing |
| diagnostic | `0xff31` / `0x0074` | key events (`+XX` = press) |
| config | `0xff99` / `0x2468` | read/write the EEPROM config |

`modelm-remap` uses the **diagnostic** interface to see the *physical* key you
press (before remapping), then:

1. reads the current config out of EEPROM,
2. disassembles it to Soarer's text (`scdis`),
3. merges your remap into the first `remapblock`,
4. assembles it (`scas`), writes it back (`sctool`),
5. reads it back and verifies the bytes match.

Existing remaps are preserved. Every write is preceded by a backup in
`~/.config/modelm-remap/backups/` (both `.scb` and a readable `.sc`).

The resulting source is a normal Soarer's config you can also edit by hand:

```
ifkeyboard any
ifselect any
remapblock
layer 0
    EXTRA_F10 LGUI
    RALT LGUI
endblock
```

## Shortcuts (macros)

A plain remap turns one key into one key. A **shortcut** is several keys at
once — a chord like `⌘⇧4` — so it is stored as a Soarer's Converter *macro*
that the converter synthesises from a single press:

```sh
modelm-remap screenshot               # the built-in one: Cmd+Shift+4
modelm-remap macro                    # pick any shortcut interactively
modelm-remap shortcut F10 CMD+SHIFT+4 # or name the chord yourself
```

`modelm-remap shortcut` accepts any trigger key and a chord built from
modifiers (`CMD`, `SHIFT`, `CTRL`, `OPT`, and their `R…`/right-hand forms) plus
one ordinary key. A named shortcut (`SCREENSHOT`) is just an alias for its
chord. The resulting config is a normal macro you can also edit by hand:

```
macroblock
	macro EXTRA_F10
		PUSH_META ASSIGN_META LGUI LSHIFT
		PRESS 4
		POP_META
	endmacro
endblock
```

Adding a shortcut for a key that already has a remap replaces that remap, and
adding one for a key that already has a macro replaces that macro.

## Mac key reference

| macOS | Soarer token | Notes |
|---|---|---|
| ⌘ Command (left) | `LGUI` | most common target |
| ⌘ Command (right) | `RGUI` | |
| ⌥ Option (left) | `LALT` | |
| ⌥ Option (right) | `RALT` | |
| ⌃ Control (left/right) | `LCTRL` / `RCTRL` | |
| ⇧ Shift | `LSHIFT` / `RSHIFT` | |

Aliases accepted by the tool: `CMD`, `COMMAND`, `SUPER`, `WIN` → `LGUI`;
`OPT`/`OPTION` → `LALT`; `CONTROL` → `LCTRL`; `RETURN` → `ENTER`.

## Troubleshooting

- **"no Soarer's Converter found"** — check the adapter is plugged in and the
  keyboard cable is seated. `system_profiler SPUSBDataType | grep -i soarer`
  should list it; the USB id is `16c0:047d`.
- **Nothing detected when pressing a key** — run `modelm-remap listen` and
  watch the output. The tool watches for the `+XX` press event; if your key is
  unusual, pass `--from NAME` explicitly (see `modelm-remap keys`).
- **Writing fails** — the converter may be busy; unplug/replug it and retry.
  Your previous config is always backed up first, and `restore` can put it back.
- **Keys also type into the terminal while capturing** — that's normal (the
  standard keyboard interface still delivers to macOS); the input is drained
  afterwards.

## Credits

`scas` / `scdis` / `sctool` come from
[thentenaar/sctools](https://github.com/thentenaar/sctools) (BSD-2-Clause),
a maintained replacement for Soarer's original converter tools. Soarer's
Converter firmware itself is by Soarer.
