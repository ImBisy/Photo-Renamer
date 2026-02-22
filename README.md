# Photo Renamer 📸

**Automatically import, rename, and organize your camera photos in one step.**

This script takes photos from your camera's SD card, copies them to your computer, and renames them with the date they were taken—like `25-12-25-001.ORF` for a photo taken on December 25, 2025.

---

## Quick Start (Do This First!)

### 1. Install Homebrew and exiftool

Open Terminal (press `Cmd + Space`, type "Terminal", press Enter), then run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install exiftool
```

### 2. Download This Script

**Option A: Using Git (Recommended)**

```bash
git clone https://github.com/ImBisy/Photo-Renamer.git
cd "Photo-Renamer"
```

**Option B: Manual Download**

1. Go to https://github.com/ImBisy/Photo-Renamer
2. Click the green **"Code"** button
3. Select **"Download ZIP"**
4. Unzip the file and put it somewhere safe (like your Documents folder)
5. Open Terminal and type `cd ` (with a space), then drag the folder into Terminal and press Enter

### 3. Set Up the Script

1. Open `PhotoImportPipeline.sh` in a text editor (double-click it or open in TextEdit/VS Code)
2. Find these lines near the top (around lines 12-16):

```bash
PHOTOS_DIR="/Users/YOUR_USERNAME/Pictures/Your Photo Folder"
LOG_DIR="/Users/YOUR_USERNAME/Photo-Renamer/Logs/"
```

3. Change `YOUR_USERNAME` to your actual Mac username
4. Change `Your Photo Folder` to where you want photos saved (or leave it as-is—the script will create the folder)
5. **Save the file**

### 4. Make It Run

In Terminal, run this command (while inside the Photo-Renamer folder):

```bash
chmod +x PhotoImportPipeline.sh
```

This tells your Mac it's okay to run this script.

---

## How to Use It

### Every Time You Import Photos

1. **Connect your camera** via USB (or insert the SD card)
2. **Wait 5-10 seconds** for it to show up in Finder
3. **Open Terminal** and go to the Photo-Renamer folder
4. **Run the script:**
   ```bash
   ./PhotoImportPipeline.sh
   ```
5. **Follow the prompts:**
   - Type `i` to import from your camera
   - Pick your SD card from the list (type the number)
   - Type `y` to rename the files

That's it! Your photos will be copied, renamed with dates, and organized.

---

## What Each Option Means

When the script asks you to choose, here's what to pick:

| Option | What It Does             | When to Use                                                |
| ------ | ------------------------ | ---------------------------------------------------------- |
| `i`    | Import + Rename + Log    | **Most common** - when you have new photos on your camera  |
| `r`    | Just Rename + Log        | When photos are already on your computer and need renaming |
| `t`    | Test mode (preview only) | Want to see what would happen without actually doing it    |
| `y`    | Yes, rename files        | **Most common** - actually rename the files                |
| `n`    | Skip renaming            | Don't rename anything this time                            |

---

## File Naming Explained

Your photos will be renamed from this:

```
DSC_0123.ORF
IMG_4567.JPG
```

To this:

```
25-12-25-001.ORF  (December 25, 2025 - photo #1)
25-12-25-002.JPG  (December 25, 2025 - photo #2)
```

The format is: `YY-MM-DD-###.ext`

- **YY** = Year (25 = 2025)
- **MM** = Month (12 = December)
- **DD** = Day (25 = 25th)
- **###** = Photo number for that day (001, 002, etc.)

---

## Troubleshooting

### "No external volumes detected"

**What it means:** Your camera or SD card isn't showing up.

**Fix it:**

1. Check that your camera appears in Finder (look under "Locations")
2. On your camera, make sure USB mode is set to "Storage" or "Mass Storage" (not "PC Auto" or "MTP")
3. Try unplugging and plugging it back in
4. Wait 10 seconds after plugging in before running the script

### "exiftool is not installed"

**Fix it:**

```bash
brew install exiftool
```

### "Permission denied"

**Fix it:**

```bash
chmod +x PhotoImportPipeline.sh
```

### "Photos directory not found"

**Fix it:**
The script will try to create the folder automatically. If it can't:

1. Check that the path in the script is correct (Step 3 in Quick Start)
2. Make sure your username is spelled correctly
3. Create the folder manually if needed

### Camera keeps disconnecting

**Try this:**

- Use a different USB cable
- Plug directly into your Mac (not through a USB hub)
- Make sure your camera battery is charged

---

## Optional: Build Log from Existing Photos

**Only do this if you already have photos in the format `25-12-25-001.ORF` that weren't processed by this script.**

1. Open `PhotoImportPipeline.sh` in a text editor
2. Find the section that says `TEMPORARY: BUILD FULL LOG FROM EXISTING FILES` (around line 225)
3. Remove the `#` from the beginning of each line in that section (or use Cmd+/ in VS Code to uncomment)
4. Save and run the script once
5. **Important:** Add the `#` back to each line when done (so it doesn't run every time)

This creates a log of your existing photos so the script knows what's already there.

---

## What Gets Created

After running the script, you'll have:

```
📁 Your Photo Folder/           ← All your renamed photos
   ├── 25-12-25-001.ORF
   ├── 25-12-25-002.JPG
   └── ...

📁 Photo-Renamer/
   ├── PhotoImportPipeline.sh  ← This script
   └── Logs/
       └── seen-files.txt     ← List of processed files
```

---

## Requirements

- **Mac computer** (this won't work on Windows)
- **macOS Catalina or later** (2019+)
- **Olympus, or other camera that saves ORF/JPG files**
- **Internet connection** (only needed for initial setup)

---

## Need Help?

1. Read the error message carefully—it usually tells you exactly what's wrong
2. Check the Troubleshooting section above
3. Make sure you've completed all 4 steps in Quick Start
4. Double-check your folder paths in the script

---

GitHub: https://github.com/ImBisy/Photo-Renamer
