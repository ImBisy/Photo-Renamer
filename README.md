# Photo Renamer 📸

**Automatically import, rename, and organise your camera photos in one step… because manually sorting 4,000 shots is how photographers develop existential dread.** (and also sort by date captured is annoying)

This script grabs photos from your camera’s SD card, copies them over, and renames them with the date—like `25-12-25-001.ORF` for that blurry Christmas dinner masterpiece from 25 December 2025.

---

## Quick Start (Do This First or Suffer)

### 1. Install Homebrew, exiftool and Git

Open Terminal and paste this (it's safe i swear):

If you have homebrew installed already, skip the first command and just run the other two.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install exiftool
brew install git
```

It’ll probably ask for your password. macOS being extra, not a virus.

### 2. Download the Script

```bash
git clone https://github.com/ImBisy/Photo-Renamer.git
cd Photo-Renamer
```

### 3. Set Up the Config File

```bash
cp config.sh.template config.sh
```

Open `config.sh` and fix the paths (don’t skip this and think it isn't working):

```bash
PHOTOS_DIR="/Users/YOUR_USERNAME/Pictures/Your Photo Folder"
LOG_DIR="/Users/YOUR_USERNAME/Photo-Renamer/Logs/"
```

Swap `YOUR_USERNAME` for your actual Mac username. Config stays local only. GitHub never sees your chaotic folder / user names.

### 4. Make It Executable

```bash
chmod +x PhotoImportPipeline.sh
```

Unix for “stop being a coward and run this sh\*t”.

---

## How to Use It

1. Connect camera via USB (select Mass Storage/Storage mode) or insert SD card
2. Wait a few seconds till it pops up in Finder → Locations
3. Terminal → navigate to Photo-Renamer folder
4. Run it:
   - Double-click `PhotoImportPipeline.sh` in Finder (easiest for most)
   - Or Terminal: `./PhotoImportPipeline.sh`  
     (Pro move: drag to Dock for one-click launches)
5. Prompts:
   - `i` → import from camera
   - Pick SD card by number
   - `y` → yes, rename the damn things

Photos copied, dated, numbered. Breathe.

---

## What Each Option Does

| Option | What It Does                    | When to Use                                   |
| ------ | ------------------------------- | --------------------------------------------- |
| `i`    | Import + Rename + Log           | New photos from camera (your usual chaos)     |
| `r`    | Rename + Log only               | Files already dumped on computer, need fixing |
| `t`    | Test mode (preview, no changes) | Paranoid testing                              |
| `y`    | Yes, rename files               | Actually commit to the cleanup                |
| `n`    | No, skip renaming               | Copy/preview only, keep the mess for now      |

---

## File Naming Format

From tragic:

```
DSC_0123.ORF
IMG_4567.JPG
```

To civilised:

```
25-12-25-001.ORF    ← 25 December 2025, shot #1
25-12-25-002.JPG    ← 25 December 2025, shot #2
```

Format: `YY-MM-DD-###.ext`  
Because random numbering is a crime against organisation.

---

<details>
<summary>###Troubleshooting</summary>

**"No external volumes detected"**  
→ Camera ghosting you. Check Finder Locations, confirm USB Storage mode, replug, different cable, pray.

**"exiftool is not installed"**  
→ `brew install exiftool` again. It’s needy like that.

**"Permission denied"**  
→ Forgot `chmod +x`. Run it.

**"Photos directory not found"**  
→ Paths wrong in `config.sh`. Fix or `mkdir` manually.

Camera disconnects randomly? → Better cable, no hub, charge battery, blame Olympus.

</details>

---

## Optional but Recommended: Build Log from Existing Photos

Got old files already in `YY-MM-DD-###.ext` format that this script never touched? Note: This feature is not yet implemented in the current version. To manually build the log, you can scan your photos folder and add filenames to `Logs/seen-files.txt`.

---

## What Gets Created (Hopefully)

```
Your Photo Folder/
   ├── 25-12-25-001.ORF
   ├── 25-12-25-002.JPG
   └── ...

Photo-Renamer/
   ├── PhotoImportPipeline.sh
   └── Logs/
       └── seen-files.txt      ← the receipts
```

---

## Requirements

- Mac on macOS Catalina or later
- Olympus (or similar) camera spitting ORF/JPG and other raw formats (CR2, CR3, NEF, NRW, ARW, SR2, SRF, RAF, RW2, PEF, PTX, DNG, RWL, 3FR, IIQ, X3F) files (only properly tested on Olympus, Your MMV)
- Internet once (Homebrew setup)

---

## Coming Soon (Maybe. Idek anymore)

- Turn this into a GUI app for easier point-and-click importing without terminal commands
- Add undo functionality to revert renames in case of mistakes
- Batch processing mode for organizing large existing photo collections
- Add image preview for a few random photos in the sd card or folder

## Need Help?

Read the error, hit Troubleshooting, triple-check config paths, confirm Quick Start.
Still screwed? Open an issue on GitHub, then if I don't respond DM me on Reddit at u/Diligent-Register556 saying you opened an issue - I don’t bite (unprovoked).

GitHub: https://github.com/ImBisy/Photo-Renamer
