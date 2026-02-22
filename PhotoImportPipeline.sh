#!/bin/zsh

# ═══════════════════════════════════════════════════════════════════════════
# COMPLETE PHOTO IMPORT → RENAME → LOG PIPELINE
# ALL CONFIGURABLE PATHS AT THE TOP
# ═══════════════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION - Load from external file
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONFIG_FILE="$(dirname "$0")/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Use config values or defaults
PHOTOS_DIR="${PHOTOS_DIR:-/Users/$USER/Pictures/OM Workspace}"
LOG_DIR="${LOG_DIR:-$(dirname "$0")/Logs/}"
AUTO_FIX_PERMISSIONS="${AUTO_FIX_PERMISSIONS:-0}"

# Seen-files tracking log
SEEN_LOG="$LOG_DIR/seen-files.txt"

# Rename log (from renamePhotos.sh)
RENAME_LOG="$LOG_DIR/rename-log.txt"

# File types to process
FILE_EXTENSIONS=('*.ORF' '*.JPG' '*.XMP')

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# END OF CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ═══════════════════════════════════════════════════════════════════════════
# MODE SELECTION
# ═══════════════════════════════════════════════════════════════════════════

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  📸 PHOTO IMPORT PIPELINE                         ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo
echo "  What would you like to do?"
echo
echo "    [i]  Import from SD card + Rename + Log"
echo "    [r]  Rename + Log (skip import, use config folder)"
echo "    [l]  Rename in place (any folder, no logging)"
echo
printf "👉 Choose [i/r/l]: "
read -r mode

if [[ "$mode" != "i" && "$mode" != "I" && "$mode" != "r" && "$mode" != "R" && "$mode" != "l" && "$mode" != "L" ]]; then
  echo "❌ Invalid selection. Exiting."
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# SD CARD DETECTION & SELECTION (only if import mode)
# ═══════════════════════════════════════════════════════════════════════════

CAMERA_IMPORT_DIR=""
SELECTED_NAME=""
SELECTED_SIZE=""
LOCAL_MODE=0

if [[ "$mode" == "l" || "$mode" == "L" ]]; then
  LOCAL_MODE=1
  echo
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  echo "┃  📁 LOCAL FOLDER MODE                             ┃"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo
  printf "👉 Enter the full path to the folder: "
  read -r LOCAL_FOLDER
  
  if [[ ! -d "$LOCAL_FOLDER" ]]; then
    echo "❌ Error: Folder not found: $LOCAL_FOLDER"
    exit 1
  fi
  
  PHOTOS_DIR="$LOCAL_FOLDER"
  echo
  echo "✅ Selected folder: $PHOTOS_DIR"
  echo
  
  printf "👉 Enable logging? [y/n]: "
  read -r enable_log
  if [[ "$enable_log" != "y" && "$enable_log" != "Y" ]]; then
    SKIP_LOGGING=1
    echo "  📝 Logging disabled"
  else
    SKIP_LOGGING=0
    echo "  📝 Logging enabled"
  fi
  echo
fi

if [[ "$mode" == "i" || "$mode" == "I" ]]; then
  echo
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  echo "┃  💾 SD CARD DETECTION                             ┃"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo

  # Arrays to store volume info
  declare -a VOL_PATHS
  declare -a VOL_NAMES
  declare -a VOL_SIZES
  declare -a VOL_TYPES

  # Debug: Show all volumes found
  echo "🔍 Scanning for mounted volumes..."
  echo

  # Scan /Volumes for mounted external drives
  i=1
  for vol in /Volumes/*; do
    # Skip if not a directory
    [[ ! -d "$vol" ]] && continue
    
    basename_vol=$(basename "$vol")
    
    # Skip system volumes and common non-SD entries
    if [[ "$basename_vol" =~ ^(Macintosh\ HD|com\.apple|Preboot|Update|VM|System) ]]; then
      continue
    fi

    # Check if volume is readable
    if [[ ! -r "$vol" ]]; then
      continue
    fi

    # Get filesystem type (helps identify camera storage)
    fstype=$(df -T "$vol" 2>/dev/null | awk 'NR==2 {print $2}')
    [[ -z "$fstype" ]] && fstype="unknown"

    # Get available free space in GB
    gbfree=$(df -g "$vol" 2>/dev/null | awk 'NR==2 {print $4}')
    [[ -z "$gbfree" ]] && gbfree="?"

    # Check if volume contains camera files (ORF, JPG, etc.) - helps identify camera
    has_camera_files=0
    if find "$vol" -maxdepth 3 -type f \( -iname '*.ORF' -o -iname '*.JPG' -o -iname '*.CR2' -o -iname '*.NEF' -o -iname '*.ARW' \) 2>/dev/null | head -1 | read; then
      has_camera_files=1
    fi

    # Store volume info
    VOL_PATHS+=("$vol")
    VOL_NAMES+=("$basename_vol")
    VOL_SIZES+=("$gbfree")
    VOL_TYPES+=("$fstype")

    # Display option with camera file indicator
    camera_indicator=""
    [[ $has_camera_files -eq 1 ]] && camera_indicator=" 📸"
    printf "  %d) %-25s [%sGB free, %s]%s\n" "$i" "$basename_vol" "$gbfree" "$fstype" "$camera_indicator"
    ((i++))
  done

  echo

  # Debug output: Show all volumes in /Volumes (for troubleshooting)
  if [[ ${#VOL_PATHS[@]} -eq 0 ]]; then
    echo "⚠️  No external volumes detected. Debug info:"
    echo "   All volumes in /Volumes:"
    for vol in /Volumes/*; do
      if [[ -d "$vol" ]]; then
        basename_vol=$(basename "$vol")
        # Check if readable
        readable=""
        [[ -r "$vol" ]] && readable=" (readable)"
        echo "     - $basename_vol$readable"
      fi
    done
    echo
    echo "   Checking for USB devices via diskutil..."
    diskutil list external 2>/dev/null | grep -E "(disk|volume)" | head -10 || echo "     (No external disks found)"
    echo
    echo "❌ No mounted SD cards or external volumes found!"
    echo "   Please ensure:"
    echo "   1. Camera is connected via USB"
    echo "   2. Camera is set to 'Storage' or 'Mass Storage' mode (not PTP/MTP)"
    echo "   3. Camera appears in Finder"
    echo "   4. Wait a few seconds after connecting and try again"
    echo
    echo "   💡 Tip: If camera doesn't appear, try:"
    echo "      - Disconnecting and reconnecting the USB cable"
    echo "      - Changing camera USB mode to 'Storage' or 'Mass Storage'"
    echo "      - Checking System Settings > Privacy & Security > Full Disk Access"
    echo
    printf "👉 Press Enter to exit: "
    read -r press
    exit 1
  fi

  # Prompt user to select SD card
  printf "👉 Enter the number of the SD card: "
  read -r choice
  SELECTED=$((choice))

  if [[ $SELECTED -le 0 || $SELECTED -gt ${#VOL_PATHS[@]} ]]; then
    echo "❌ Invalid selection. Please choose a number between 1 and ${#VOL_PATHS[@]}."
    exit 1
  fi

  # Set the camera import directory from selection
  # zsh arrays are 1-indexed, so SELECTED directly matches the array index
  CAMERA_IMPORT_DIR="${VOL_PATHS[$SELECTED]}"
  SELECTED_NAME="${VOL_NAMES[$SELECTED]}"
  SELECTED_SIZE="${VOL_SIZES[$SELECTED]}"

  echo
  echo "✅ Selected: $SELECTED_NAME ($SELECTED_SIZE GB free)"
  echo "   Path: $CAMERA_IMPORT_DIR"
  echo
fi

# ═══════════════════════════════════════════════════════════════════════════
# VALIDATION & SETUP
# ═══════════════════════════════════════════════════════════════════════════

# Check dependencies
check_exiftool() {
  if ! command -v exiftool &> /dev/null; then
    echo "❌ Error: exiftool is not installed."
    echo "   Install it with: brew install exiftool"
    exit 1
  fi
}

# Fix ownership permissions on photos directory and files
fix_permissions() {
  local dir="$1"
  
  # Check if directory is writable
  if [[ ! -w "$dir" ]]; then
    echo "⚠️  Permission issue: you don't own $dir"
    
    if [[ "${AUTO_FIX_PERMISSIONS:-0}" == "1" ]]; then
      echo "   Auto-fixing permissions..."
      sudo chown -R "$(whoami)" "$dir" 2>/dev/null && echo "✅ Permissions fixed" || echo "❌ Failed"
    else
      printf "👉 Fix permissions? [Y/n]: "
      read -r fix_choice
      if [[ "$fix_choice" == "" || "$fix_choice" == "y" || "$fix_choice" == "Y" ]]; then
        sudo chown -R "$(whoami)" "$dir" 2>/dev/null && echo "✅ Permissions fixed" || echo "❌ Failed"
      fi
    fi
    return
  fi
  
  # Check for files owned by root (common when copying from SD/external drives)
  local root_files=$(find "$dir" -maxdepth 1 -type f -user root 2>/dev/null | head -5)
  if [[ -n "$root_files" ]]; then
    local root_count=$(find "$dir" -maxdepth 1 -type f -user root 2>/dev/null | wc -l | tr -d ' ')
    echo "⚠️  Found $root_count files owned by root (from external drive)"
    
    if [[ "${AUTO_FIX_PERMISSIONS:-0}" == "1" ]]; then
      echo "   Auto-fixing file ownership..."
      if sudo chown -R "$(whoami)" "$dir" 2>/dev/null; then
        echo "✅ File ownership fixed"
      else
        echo "❌ Could not fix permissions"
        exit 1
      fi
    else
      printf "👉 Fix file ownership? [Y/n]: "
      read -r fix_choice
      if [[ "$fix_choice" == "" || "$fix_choice" == "y" || "$fix_choice" == "Y" ]]; then
        if sudo chown -R "$(whoami)" "$dir" 2>/dev/null; then
          echo "✅ File ownership fixed"
        else
          echo "❌ Could not fix permissions"
          exit 1
        fi
      else
        echo "❌ Cannot rename files without ownership. Exiting."
        exit 1
      fi
    fi
  fi
}

# Setup directories for standard modes (not local mode)
setup_directories() {
  if [[ $LOCAL_MODE -eq 1 ]]; then
    # For local mode, just check/fix permissions on the specified folder
    fix_permissions "$PHOTOS_DIR"
    return 0
  fi
  
  # Ensure photos directory exists
  if [[ ! -d "$PHOTOS_DIR" ]]; then
    echo "📁 Creating photos directory: $PHOTOS_DIR"
    mkdir -p "$PHOTOS_DIR"
    if [[ ! -d "$PHOTOS_DIR" ]]; then
      echo "❌ Failed to create photos directory. Exiting."
      exit 1
    fi
    echo "✅ Photos directory created"
  fi
  
  # Fix permissions if needed
  fix_permissions "$PHOTOS_DIR"
  
  # Ensure log directory exists
  if [[ ! -d "$LOG_DIR" ]]; then
    echo "📁 Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
    if [[ ! -d "$LOG_DIR" ]]; then
      echo "❌ Failed to create log directory. Exiting."
      exit 1
    fi
    echo "✅ Log directory created"
  fi
  
  # Ensure seen-files log exists
  if [[ ! -f "$SEEN_LOG" ]]; then
    echo "📝 Creating seen-files log: $SEEN_LOG"
    touch "$SEEN_LOG"
    echo "✅ Log file created"
  fi
}

# Run setup
check_exiftool
setup_directories

# Check SD card path if in import mode
if [[ -n "$CAMERA_IMPORT_DIR" && ! -d "$CAMERA_IMPORT_DIR" ]]; then
  echo "❌ Error: SD card path not found: $CAMERA_IMPORT_DIR"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# OPTIONAL: BUILD LOG FROM EXISTING FILES
# ═══════════════════════════════════════════════════════════════════════════
#
# Set BUILD_LOG_FROM_EXISTING=1 in config.sh or run with:
#   BUILD_LOG_FROM_EXISTING=1 ./PhotoImportPipeline.sh
#
# This scans your photos folder and adds ALL existing renamed files
# to the log file. Useful if you already have renamed files that
# weren't logged when they were renamed. Only needs to run once.
# ═══════════════════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════════════════
# IMPORT → RENAME → LOG PIPELINE
# ═══════════════════════════════════════════════════════════════════════════

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
    echo "┃  📸 IMPORT → RENAME → LOG PIPELINE                ┃"
elif [[ $LOCAL_MODE -eq 1 ]]; then
  if [[ $SKIP_LOGGING -eq 1 ]]; then
    echo "┃  📸 RENAME IN PLACE (no logging)                  ┃"
  else
    echo "┃  📸 RENAME IN PLACE + LOG                         ┃"
  fi
else
echo "┃  📸 RENAME → LOG PIPELINE                         ┃"
fi
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo
echo "  📂 Working folder: $PHOTOS_DIR"
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  echo "  📂 Source (SD):     $CAMERA_IMPORT_DIR ($SELECTED_NAME)"
fi
if [[ $LOCAL_MODE -eq 0 ]]; then
  echo "  📂 Log folder:      $LOG_DIR"
fi
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Initialize array to track newly renamed files (for fast logging)
newly_renamed_files=()

# STEP 1: IMPORT FROM SD CARD (if import mode)
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  echo "Step 1: Importing files from SD card..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo "  📥 Copying files to: $PHOTOS_DIR"
  echo

  # Find all camera files on SD card (exclude system directories)
  files_to_import=()
  while IFS= read -r line; do
    files_to_import+=("$line")
  done < <(find "$CAMERA_IMPORT_DIR" -type f \( -iname '*.ORF' -o -iname '*.JPG' -o -iname '*.XMP' \) ! -path "*/.Spotlight-V100/*" ! -path "*/.Trashes/*" ! -path "*/.fseventsd/*" ! -path "*/.VolumeIcon.icns" -print 2>/dev/null)

  if [[ ${#files_to_import[@]} -eq 0 ]]; then
    echo "  ⚠️  No camera files found on SD card."
    echo
  else
    echo "  Found ${#files_to_import[@]} files to import..."
    echo

    imported_count=0
    for file in "${files_to_import[@]}"; do
      filename=$(basename "$file")
      dest="$PHOTOS_DIR/$filename"
      
      # Skip if file already exists
      if [[ -f "$dest" ]]; then
        echo "  ⏭️  Skipped: $filename (already exists)"
        continue
      fi
      
      # Copy file
      if cp "$file" "$dest" 2>/dev/null; then
        echo "  ✅ Copied: $filename"
        ((imported_count++))
      else
        echo "  ❌ Failed: $filename"
      fi
    done

    echo
    echo "  ✅ Imported $imported_count new files to $PHOTOS_DIR"
    echo
  fi
fi

# STEP 2: RENAME FILES
echo "Step 2: Renaming files (YY-MM-DD-### format)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "  📂 Working in: $PHOTOS_DIR"
echo
echo "  OPTIONS:"
echo "    [t]   = test (ONLY non-YY-MM-DD-### files)"
echo "    [y]   = rename (ONLY non-YY-MM-DD-### files)"
echo "    [ta]  = test ALL files (even already-correct)"
echo "    [a]   = rename ALL files (⚠️  DESTRUCTIVE)"
echo "    [n]   = skip renaming"
echo
printf "👉 Choose [t/y/ta/a/n]: "
read -r rename_choice

if [[ "$rename_choice" != "n" && "$rename_choice" != "N" ]]; then
  cd "$PHOTOS_DIR" || { echo "❌ Error: Cannot cd to $PHOTOS_DIR"; exit 1; }

  # Determine mode
  test_mode=0
  selective=1
  
  if [[ "$rename_choice" == "t" || "$rename_choice" == "T" ]]; then
    test_mode=1
    selective=1
  elif [[ "$rename_choice" == "y" || "$rename_choice" == "Y" ]]; then
    test_mode=0
    selective=1
  elif [[ "$rename_choice" == "ta" || "$rename_choice" == "TA" ]]; then
    test_mode=1
    selective=0
  elif [[ "$rename_choice" == "a" || "$rename_choice" == "A" ]]; then
    test_mode=0
    selective=0
  else
    echo "  ❌ Invalid choice. Skipping rename."
    test_mode=0
    selective=0
  fi

  if [[ $test_mode -eq 1 ]]; then
    echo
    echo "  🧪 TEST MODE - Preview only"
    echo
  else
    echo
    echo "  🚀 RENAME MODE - Files will be renamed"
    echo
  fi

  # Rename function
  counter=1
  last_date=""
  renamed_count=0

  # Get list of PRIMARY files (ORF/JPG only, NOT sidecars)
  files_to_process=()

  if [[ $selective -eq 1 ]]; then
    # Only process files NOT matching YY-MM-DD-###.ext pattern
    while IFS= read -r file; do
      if [[ ! "$file" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{3}\.(ORF|JPG)$ ]]; then
        files_to_process+=("$file")
      fi
    done < <(find . -maxdepth 1 \( -iname "*.ORF" -o -iname "*.JPG" \) | sed 's|^\./||' | sort)
  else
    # Process ALL primary files
    while IFS= read -r file; do
      files_to_process+=("$file")
    done < <(find . -maxdepth 1 \( -iname "*.ORF" -o -iname "*.JPG" \) | sed 's|^\./||' | sort)
  fi

  # Process each PRIMARY file
  for file in "${files_to_process[@]}"; do
    # Get the file extension (preserve original case)
    ext="${file##*.}"
    filename_no_ext="${file%.*}"

    # Get DateTimeOriginal from exiftool
    datetime=$(exiftool -DateTimeOriginal "$file" 2>/dev/null | grep -oE '[0-9]{4}:[0-9]{2}:[0-9]{2}')

    if [ -z "$datetime" ]; then
      echo "  ⚠️  Warning: No DateTimeOriginal found for '$file'"
      continue
    fi

    # Parse the datetime: "2025:12:16" -> "25-12-16"
    full_year="${datetime:0:4}"
    month="${datetime:5:2}"
    day="${datetime:8:2}"
    year="${full_year: -2}"
    date_part="$year-$month-$day"

    # Reset counter if date changed
    if [[ "$date_part" != "$last_date" ]]; then
      counter=1
      last_date="$date_part"
    fi

    # Format counter with leading zeros (3 digits)
    counter_str=$(printf "%03d" $counter)
    newfile="$date_part-$counter_str.$ext"

    # Show primary file rename
    if [[ $test_mode -eq 1 ]]; then
      echo "  📸 '$file' → '$newfile'"
    else
      if [[ "$file" != "$newfile" ]]; then
        mv "$file" "$newfile"
        echo "  ✅ Renamed: '$file' → '$newfile'"
        ((renamed_count++))
        # Track this renamed file for logging (only ORF and JPG, not XMP)
        if [[ "$newfile" =~ \.(ORF|JPG)$ ]]; then
          newly_renamed_files+=("$newfile")
        fi
      else
        echo "  ⏭️  Skipped: '$file' (already perfect)"
      fi
    fi

    # Handle sidecars: ONLY keep .XMP, delete .xmp
    if [ -f "$filename_no_ext.XMP" ]; then
      newfile_sidecar="$date_part-$counter_str.XMP"
      if [[ $test_mode -eq 1 ]]; then
        echo "  📋 '$filename_no_ext.XMP' → '$newfile_sidecar'"
      else
        if [[ "$filename_no_ext.XMP" != "$newfile_sidecar" ]]; then
          mv "$filename_no_ext.XMP" "$newfile_sidecar"
          echo "  ✅ Renamed: '$filename_no_ext.XMP' → '$newfile_sidecar'"
        fi
      fi
    fi

    # Delete the lowercase .xmp (it's a duplicate)
    if [ -f "$filename_no_ext.xmp" ]; then
      if [[ $test_mode -eq 1 ]]; then
        echo "  🗑️  DELETE: '$filename_no_ext.xmp' (duplicate, keeping .XMP)"
      else
        rm "$filename_no_ext.xmp"
        echo "  🗑️  Deleted: '$filename_no_ext.xmp' (duplicate)"
      fi
    fi

    ((counter++))
  done

  echo
  if [[ $test_mode -eq 1 ]]; then
    echo "  ✅ Test complete. No files were changed."
    echo
  else
    echo "  ✅ Renamed $renamed_count files."
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    printf "👉 Press Enter to continue to logging... "
    read -r
    echo
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING (skip if local mode with no logging)
# ═══════════════════════════════════════════════════════════════════════════

if [[ $LOCAL_MODE -eq 1 && $SKIP_LOGGING -eq 1 ]]; then
  echo "Step 3: Logging skipped (disabled)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
else
  echo "Step 3: Logging renamed files..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo

# Use tracked files if available (fast), otherwise scan (slower but comprehensive)
if [[ ${#newly_renamed_files[@]} -gt 0 ]]; then
  # Fast path: use files tracked during rename
  newly_renamed=("${newly_renamed_files[@]}")
  echo "  📝 Adding ${#newly_renamed[@]} newly renamed files to log..."
else
  # Fallback: scan for all renamed files (slower, but ensures full log)
  echo "  🔍 Scanning for renamed files (this may take a moment)..."
  after_files=()
  while IFS= read -r line; do
    after_files+=("$line")
  done < <(find "$PHOTOS_DIR" -maxdepth 1 -type f \( -iname '*.ORF' -o -iname '*.JPG' \) -print 2>/dev/null | sort)

  # Find files matching YY-MM-DD-###.ext pattern
  newly_renamed=()
  for file in "${after_files[@]}"; do
    filename=$(basename "$file")
    if [[ "$filename" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{3}\.(ORF|JPG)$ ]]; then
      newly_renamed+=("$filename")
    fi
  done
  echo "  📝 Found ${#newly_renamed[@]} renamed files to log..."
fi

if [[ ${#newly_renamed[@]} -eq 0 ]]; then
  echo "  ✅ No files to log."
  echo
else
  # Update seen-files log (only add new entries)
  added_count=0
  for file in "${newly_renamed[@]}"; do
    # Check if file is already in log (avoid duplicates)
    if ! grep -Fxq "$file" "$SEEN_LOG" 2>/dev/null; then
      echo "$file" >> "$SEEN_LOG"
      ((added_count++))
    fi
  done

  # Deduplicate and sort the entire log
  sort -u "$SEEN_LOG" -o "$SEEN_LOG"

  if [[ $added_count -gt 0 ]]; then
    echo "  ✅ Added $added_count new files to log (${#newly_renamed[@]} total checked)"
  else
    echo "  ✅ All ${#newly_renamed[@]} files already in log"
  fi
  echo "  📄 Full log contains $(wc -l < "$SEEN_LOG" | tr -d ' ') total files"
  echo "  📝 Log file: $SEEN_LOG"
  echo
fi
fi

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  🎉 PIPELINE COMPLETE!                             ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  echo "  📸 ${#newly_renamed[@]} files imported, renamed & logged"
elif [[ $LOCAL_MODE -eq 1 ]]; then
  if [[ $SKIP_LOGGING -eq 1 ]]; then
    echo "  📸 ${#newly_renamed[@]} files renamed in place"
  else
    echo "  📸 ${#newly_renamed[@]} files renamed in place & logged"
  fi
else
  echo "  📸 ${#newly_renamed[@]} files renamed & logged"
fi
if [[ $LOCAL_MODE -eq 0 || $SKIP_LOGGING -eq 0 ]]; then
  echo "  📝 Seen-files log: $SEEN_LOG"
fi
echo

exit 0
