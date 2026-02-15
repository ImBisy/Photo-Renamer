# Photo Import Pipeline

An automated, all-in-one shell script for importing, renaming, and logging photos from your camera's SD card. Everything happens seamlessly in one script - no separate tools needed. The script detects your camera storage, imports photos, renames them to a consistent format (YY-MM-DD-###), and maintains a log of processed files.

## What This Does

1. **Detects SD Cards**: Automatically scans for mounted camera storage devices (optional)
2. **Imports Photos**: Copies camera files (ORF, JPG, XMP) from SD card to your destination folder
3. **Renames Files**: Converts filenames to a consistent `YY-MM-DD-###.ext` format using EXIF data
4. **Logs Processed Files**: Maintains a log to track which files have been processed

**Two Modes:**
- **Import + Rename + Log**: Full pipeline from SD card to renamed files
- **Rename + Log Only**: Skip import and just rename existing files in your workspace

## Prerequisites

### System Requirements
- **macOS** (this script is designed for macOS)
- **zsh shell** (comes pre-installed on macOS Catalina and later)

### Required Software

#### 1. Install Git (if you haven't already)

**Check if Git is installed:**
```bash
git --version
```

**If Git is not installed:**

**Option A: Using Homebrew (Recommended)**
1. First, install Homebrew if you don't have it:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
2. Then install Git:
   ```bash
   brew install git
   ```

**Option B: Download from Official Website**
- Visit [https://git-scm.com/download/mac](https://git-scm.com/download/mac)
- Download and install the macOS installer
- Follow the installation wizard

#### 2. Install a Text Editor (if needed)

You'll need to edit the script configuration. You can use:
- **Sublime Text**: [https://www.sublimetext.com/](https://www.sublimetext.com/)
- **VS Code**: [https://code.visualstudio.com/](https://code.visualstudio.com/)


#### 3. Terminal Access

- **Terminal.app**: Built into macOS (CMD+SPACE -> Terminal)

### Required Dependencies

#### exiftool (Required)

The script uses **exiftool** to read EXIF data from photos for renaming. You must install it:

**Check if exiftool is installed:**
```bash
exiftool -ver
```

**If exiftool is not installed:**

**Using Homebrew (Recommended):**
```bash
brew install exiftool
```

**Other installation methods:**
- Visit [https://exiftool.org/install.html](https://exiftool.org/install.html)
- Or download from [https://exiftool.org/](https://exiftool.org/)

#### Standard Unix Utilities

The script also uses standard Unix utilities that come with macOS:
- `find` - for searching files
- `df` - for checking disk space
- `awk` - for text processing
- `sort` - for sorting files

These are all pre-installed on macOS, so no additional installation needed.

## Installation

### Step 1: Clone or Download This Repository

**If you have Git installed:**
```bash
git clone <repository-url>
cd "photo-import-pipeline"
```

**If you don't have Git:**
1. Click the green "Code" button on GitHub
2. Select "Download ZIP"
3. Extract the ZIP file
4. Open Terminal and navigate to the extracted folder:
   ```bash
   cd ~/Downloads/photo-import-pipeline
   ```

### Step 2: Make the Script Executable

In Terminal, navigate to the project directory and run:
```bash
chmod +x PhotoImportPipeline.sh
```

This gives the script permission to run.

### Step 3: Install exiftool

The script requires exiftool to read EXIF data from photos. Install it with Homebrew:

```bash
brew install exiftool
```

If you don't have Homebrew, see the [Required Dependencies](#required-dependencies) section above.

### Step 4: Configure the Script

Open `PhotoImportPipeline.sh` in a text editor and update these paths at the top of the file (lines 12-28):

```bash
# Primary photo destination (where files are renamed and stored)
PHOTOS_DIR="/Users/YOUR_USERNAME/Pictures/Your Photo Folder"

# Logging and tracking folder
LOG_DIR="/Users/YOUR_USERNAME/Documents/Photo Import Pipeline/Logs/"
```

**Important Notes:**
- Replace `YOUR_USERNAME` with your actual macOS username
- Replace `Your Photo Folder` with your desired folder name
- The script will automatically create directories if they don't exist
- You can manually create them if you prefer:
  ```bash
  mkdir -p "/Users/YOUR_USERNAME/Pictures/Your Photo Folder"
  mkdir -p "/Users/YOUR_USERNAME/Documents/Photo Import Pipeline/Logs"
  ```

### Step 5: Build Initial Log File (One-Time Setup - Optional)

If you already have renamed files in your photos folder (files in `YY-MM-DD-###.ext` format) that weren't logged when they were renamed, you can build a complete log file from all existing files.

**To build the log from existing files:**

1. Open `PhotoImportPipeline.sh` in a text editor
2. Find the section marked `TEMPORARY: BUILD FULL LOG FROM EXISTING FILES` (around line 225)
3. **Uncomment** the code block by removing the `#` from the beginning of each line in that section
4. Save the file
5. Run the script once (you can choose any mode - it will build the log before the main process)
6. After it completes, **comment the code back out** by adding `#` to the beginning of each line
7. This only needs to be done once to build your initial log file

**What this does:**
- Scans your photos folder for all files matching the renamed pattern (`YY-MM-DD-###.ext`)
- Adds any files that aren't already in the log file
- Creates a complete log of all your renamed files

**Note:** After running this once, you can comment the code back out. The script will automatically log newly renamed files going forward.

## Usage

### Basic Usage

**Option 1: Import + Rename + Log (Full Pipeline)**
1. **Connect your camera** via USB or insert the SD card into your computer
2. **Wait a few seconds** for macOS to mount the storage
3. **Run the script**:
   ```bash
   ./PhotoImportPipeline.sh
   ```
4. **Choose `[i]`** for Import mode
5. **Select your SD card** from the list when prompted
6. **Choose rename option** when prompted:
   - `[t]` = test (preview only)
   - `[y]` = rename (only files not already in YY-MM-DD-### format)
   - `[ta]` = test all files
   - `[a]` = rename all files (⚠️ destructive)
   - `[n]` = skip renaming

**Option 2: Rename + Log Only (Skip Import)**
1. **Run the script**:
   ```bash
   ./PhotoImportPipeline.sh
   ```
2. **Choose `[r]`** for Rename-only mode
3. **Choose rename option** when prompted (same options as above)

### What Happens

**In Import Mode:**
1. The script scans for mounted volumes (SD cards, USB drives)
2. You select which volume contains your photos
3. Files are copied from SD card to your destination folder (`PHOTOS_DIR`)
4. The script prompts for rename options
5. Files are renamed to `YY-MM-DD-###.ext` format using EXIF data
6. Newly renamed files are logged to `seen-files.txt`

**In Rename-Only Mode:**
1. The script scans your photos directory for files
2. You choose rename options
3. Files are renamed to `YY-MM-DD-###.ext` format using EXIF data
4. Newly renamed files are logged to `seen-files.txt`

Everything happens seamlessly in one continuous flow!

## File Structure

After setup, your directory structure should look like:

```
/Users/YOUR_USERNAME/
├── Pictures/
│   └── Your Photo Folder/              # Your processed photos go here
├── Documents/
│   └── Photo Import Pipeline/
│       └── Logs/
│           ├── seen-files.txt           # Log of processed files
│           └── rename-log.txt           # Rename operation log
└── photo-import-pipeline/
    └── PhotoImportPipeline.sh           # The all-in-one script
```

**Note:** The script will automatically create the log directory if it doesn't exist.

## Troubleshooting

### "No external volumes detected"

**Possible causes:**
- Camera not connected or not in storage mode
- SD card not inserted properly
- macOS hasn't mounted the volume yet

**Solutions:**
1. Check that your camera appears in Finder
2. Ensure camera is set to "Storage" or "Mass Storage" mode (not PTP/MTP)
3. Wait a few seconds after connecting and try again
4. Try disconnecting and reconnecting the USB cable
5. Check System Settings > Privacy & Security > Full Disk Access

### "exiftool is not installed"

**Solution:**
- Install exiftool using Homebrew:
  ```bash
  brew install exiftool
  ```
- Or download from [https://exiftool.org/](https://exiftool.org/)
- Verify installation: `exiftool -ver`

### "Photos directory not found"

**Solution:**
- Create the directory specified in `PHOTOS_DIR`:
  ```bash
  mkdir -p "/Users/YOUR_USERNAME/Pictures/Your Photo Folder"
  ```
- Or update `PHOTOS_DIR` in the script to point to an existing directory

### Permission Denied

**Solution:**
- Make sure the script is executable:
  ```bash
  chmod +x PhotoImportPipeline.sh
  ```
- If you get permission errors accessing directories, you may need to grant Terminal Full Disk Access:
  - System Settings > Privacy & Security > Full Disk Access
  - Add Terminal

### Script Won't Run

**If you see "command not found" or similar:**
- Make sure you're in the correct directory
- Use the full path: `/path/to/photo-import-pipeline/PhotoImportPipeline.sh`
- Or use: `zsh PhotoImportPipeline.sh`

## Supported File Types

The script processes these camera file formats:
- **ORF** - Olympus RAW files
- **JPG** - JPEG images
- **XMP** - Sidecar metadata files

## Notes

- The script is designed for **macOS only** (uses `/Volumes` directory structure)
- Requires **zsh shell** (default on macOS Catalina+)
- Requires **exiftool** for reading EXIF data from photos
- Photos are renamed to format: `YY-MM-DD-###.ext` (e.g., `24-03-15-001.ORF`)
- The script maintains a log to prevent duplicate processing
- Everything is integrated into one script - no separate tools needed
- The script will automatically create directories if they don't exist

## License

[Add your license information here]

## Support

If you encounter issues:
1. Check the Troubleshooting section above
2. Review the error messages carefully
3. Ensure all paths are correctly configured
4. Verify that all required directories exist

