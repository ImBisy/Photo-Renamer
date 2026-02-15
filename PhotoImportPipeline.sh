#!/bin/zsh

# ═══════════════════════════════════════════════════════════════════════════
# COMPLETE PHOTO IMPORT → RENAME → LOG PIPELINE
# ALL CONFIGURABLE PATHS AT THE TOP
# ═══════════════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEFAULT CONFIGURATION
# These can be overridden by ~/.photo-pipeline.conf or command-line args
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Primary photo destination (where files are renamed and stored)
PHOTOS_DIR="/Users/YOUR_USERNAME/Pictures/Your Photo Folder"

# Log directory (created as a subfolder inside PHOTOS_DIR)
# This will be set to $PHOTOS_DIR/Logs after config is loaded
LOG_DIR=""

# Seen-files tracking log
SEEN_LOG=""

# Rename operation log
RENAME_LOG=""

# File types to process (RAW formats + JPEG + sidecars)
FILE_EXTENSIONS=('*.ORF' '*.JPG' '*.XMP' '*.CR2' '*.NEF' '*.ARW' '*.DNG' '*.RAF')

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOAD EXTERNAL CONFIG FILE (if exists)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONFIG_FILE="$HOME/.photo-pipeline.conf"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMMAND-LINE ARGUMENT PARSING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Defaults for CLI mode
CLI_MODE=""
CLI_RENAME=""
CLI_VOLUME=""
CLI_DRY_RUN=0
CLI_EJECT=0
CLI_NO_NOTIFY=0
CLI_NO_VERIFY=0

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -i, --import          Import mode (import + rename + log)"
  echo "  -r, --rename          Rename-only mode (skip import)"
  echo "  -v, --volume NAME     Specify SD card volume name"
  echo "  -y, --yes             Auto-rename (non-interactive, selective)"
  echo "  -a, --all             Rename all files (non-interactive)"
  echo "  -n, --dry-run         Preview only, don't make changes"
  echo "  -e, --eject           Eject SD card after import"
  echo "  --no-notify           Disable macOS notification"
  echo "  --no-verify           Skip checksum verification"
  echo "  -h, --help            Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                           # Interactive mode"
  echo "  $0 -i -v 'OLYMPUS' -y -e     # Import from OLYMPUS, rename, eject"
  echo "  $0 -r -n                     # Dry-run rename only"
  echo ""
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--import)
      CLI_MODE="i"
      shift
      ;;
    -r|--rename)
      CLI_MODE="r"
      shift
      ;;
    -v|--volume)
      CLI_VOLUME="$2"
      shift 2
      ;;
    -y|--yes)
      CLI_RENAME="y"
      shift
      ;;
    -a|--all)
      CLI_RENAME="a"
      shift
      ;;
    -n|--dry-run)
      CLI_DRY_RUN=1
      CLI_RENAME="t"
      shift
      ;;
    -e|--eject)
      CLI_EJECT=1
      shift
      ;;
    --no-notify)
      CLI_NO_NOTIFY=1
      shift
      ;;
    --no-verify)
      CLI_NO_VERIFY=1
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information."
      exit 1
      ;;
  esac
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SET UP LOG PATHS (after PHOTOS_DIR is finalized)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LOG_DIR="$PHOTOS_DIR/Logs"
SEEN_LOG="$LOG_DIR/seen-files.txt"
RENAME_LOG="$LOG_DIR/rename-log.txt"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Send macOS notification
notify() {
  if [[ $CLI_NO_NOTIFY -eq 0 ]]; then
    osascript -e "display notification \"$1\" with title \"Photo Import Pipeline\"" 2>/dev/null
  fi
}

# Calculate MD5 checksum
get_checksum() {
  md5 -q "$1" 2>/dev/null
}

# Verify file copy with checksum
verify_copy() {
  local src="$1"
  local dst="$2"
  
  if [[ $CLI_NO_VERIFY -eq 1 ]]; then
    return 0
  fi
  
  local src_md5=$(get_checksum "$src")
  local dst_md5=$(get_checksum "$dst")
  
  if [[ "$src_md5" == "$dst_md5" && -n "$src_md5" ]]; then
    return 0
  else
    return 1
  fi
}

# Log rename operation
log_rename() {
  local old_name="$1"
  local new_name="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $old_name → $new_name" >> "$RENAME_LOG"
}

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

# Use CLI mode if provided, otherwise prompt
if [[ -n "$CLI_MODE" ]]; then
  mode="$CLI_MODE"
  echo "  Mode: $([ "$mode" = "i" ] && echo "Import + Rename + Log" || echo "Rename + Log only")"
else
  echo "  What would you like to do?"
  echo
  echo "    [i]  Import from SD card + Rename + Log"
  echo "    [r]  Just Rename + Log (skip import)"
  echo
  printf "👉 Choose [i/r]: "
  read -r mode
fi

if [[ "$mode" != "i" && "$mode" != "I" && "$mode" != "r" && "$mode" != "R" ]]; then
  echo "❌ Invalid selection. Exiting."
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# SD CARD DETECTION & SELECTION (only if import mode)
# ═══════════════════════════════════════════════════════════════════════════

CAMERA_IMPORT_DIR=""
SELECTED_NAME=""
SELECTED_SIZE=""

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

  # Use CLI volume if provided, otherwise prompt
  if [[ -n "$CLI_VOLUME" ]]; then
    # Find volume by name
    SELECTED=0
    for idx in {1..${#VOL_NAMES[@]}}; do
      if [[ "${VOL_NAMES[$idx]}" == "$CLI_VOLUME" ]]; then
        SELECTED=$idx
        break
      fi
    done
    if [[ $SELECTED -eq 0 ]]; then
      echo "❌ Volume '$CLI_VOLUME' not found."
      exit 1
    fi
  else
    # Prompt user to select SD card
    printf "👉 Enter the number of the SD card: "
    read -r choice
    SELECTED=$((choice))

    if [[ $SELECTED -le 0 || $SELECTED -gt ${#VOL_PATHS[@]} ]]; then
      echo "❌ Invalid selection. Please choose a number between 1 and ${#VOL_PATHS[@]}."
      exit 1
    fi
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

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
  echo "❌ Error: exiftool is not installed."
  echo "   Install it with: brew install exiftool"
  exit 1
fi

if [[ ! -d "$PHOTOS_DIR" ]]; then
  echo "❌ Error: Photos directory not found: $PHOTOS_DIR"
  echo "   Creating directory..."
  mkdir -p "$PHOTOS_DIR"
  if [[ ! -d "$PHOTOS_DIR" ]]; then
    echo "❌ Failed to create directory. Exiting."
    exit 1
  fi
  echo "✅ Created directory: $PHOTOS_DIR"
fi

# Only check CAMERA_IMPORT_DIR if we're in import mode
if [[ -n "$CAMERA_IMPORT_DIR" && ! -d "$CAMERA_IMPORT_DIR" ]]; then
  echo "❌ Error: SD card path not found: $CAMERA_IMPORT_DIR"
  exit 1
fi

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

# ═══════════════════════════════════════════════════════════════════════════
# AUTO-DETECT FIRST RUN: BUILD LOG FROM EXISTING FILES
# ═══════════════════════════════════════════════════════════════════════════

# Check if this appears to be first run (log file is empty or very small)
log_line_count=$(wc -l < "$SEEN_LOG" 2>/dev/null | tr -d ' ')
if [[ $log_line_count -lt 5 ]]; then
  # Count existing renamed files in folder
  existing_count=$(find "$PHOTOS_DIR" -maxdepth 1 -type f \( -iname '*.ORF' -o -iname '*.JPG' \) -print 2>/dev/null | \
    while read -r f; do basename "$f"; done | \
    grep -cE '^[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{3}\.(ORF|JPG)$' 2>/dev/null || echo "0")
  
  if [[ $existing_count -gt 10 ]]; then
    echo
    echo "🔍 Detected $existing_count existing renamed files but log is empty/small."
    echo "   Would you like to build the log from existing files?"
    echo
    printf "👉 Build log from existing files? [y/n]: "
    read -r build_log
    
    if [[ "$build_log" == "y" || "$build_log" == "Y" ]]; then
      echo
      echo "🔍 Building log from existing renamed files..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo
      
      existing_renamed_files=()
      while IFS= read -r line; do
        filename=$(basename "$line")
        if [[ "$filename" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{3}\.(ORF|JPG)$ ]]; then
          existing_renamed_files+=("$filename")
        fi
      done < <(find "$PHOTOS_DIR" -maxdepth 1 -type f \( -iname '*.ORF' -o -iname '*.JPG' \) -print 2>/dev/null | sort)
      
      echo "  Found ${#existing_renamed_files[@]} renamed files in folder"
      
      added_to_log=0
      for file in "${existing_renamed_files[@]}"; do
        if ! grep -Fxq "$file" "$SEEN_LOG" 2>/dev/null; then
          echo "$file" >> "$SEEN_LOG"
          ((added_to_log++))
        fi
      done
      
      sort -u "$SEEN_LOG" -o "$SEEN_LOG"
      
      echo "  ✅ Added $added_to_log files to log"
      echo "  📄 Log now contains $(wc -l < "$SEEN_LOG" | tr -d ' ') total files"
      echo
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# IMPORT → RENAME → LOG PIPELINE
# ═══════════════════════════════════════════════════════════════════════════

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  echo "┃  📸 IMPORT → RENAME → LOG PIPELINE               ┃"
else
  echo "┃  📸 RENAME → LOG PIPELINE                        ┃"
fi
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo
echo "  📂 Destination:    $PHOTOS_DIR"
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  echo "  📂 Source (SD):     $CAMERA_IMPORT_DIR ($SELECTED_NAME)"
fi
echo "  📂 Log folder:      $LOG_DIR"
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
    total_files=${#files_to_import[@]}
    echo "  Found $total_files files to import..."
    echo

    imported_count=0
    skipped_count=0
    failed_count=0
    current=0
    
    for file in "${files_to_import[@]}"; do
      ((current++))
      filename=$(basename "$file")
      dest="$PHOTOS_DIR/$filename"
      
      # Progress indicator
      printf "\r  [█] Copying %d/%d: %-40s" "$current" "$total_files" "${filename:0:40}"
      
      # Skip if file already exists
      if [[ -f "$dest" ]]; then
        ((skipped_count++))
        continue
      fi
      
      # Copy file
      if cp "$file" "$dest" 2>/dev/null; then
        # Verify checksum
        if verify_copy "$file" "$dest"; then
          ((imported_count++))
        else
          echo "\n  ⚠️  Checksum mismatch: $filename"
          ((failed_count++))
        fi
      else
        echo "\n  ❌ Failed to copy: $filename"
        ((failed_count++))
      fi
    done
    
    # Clear progress line
    printf "\r%80s\r" ""

    echo "  ✅ Import complete:"
    echo "     • Imported: $imported_count files"
    [[ $skipped_count -gt 0 ]] && echo "     • Skipped (existing): $skipped_count files"
    [[ $failed_count -gt 0 ]] && echo "     • Failed: $failed_count files"
    echo
  fi
fi

# STEP 2: RENAME FILES
echo "Step 2: Renaming files (YY-MM-DD-### format)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "  📂 Working in: $PHOTOS_DIR"
echo

# Use CLI rename choice if provided, otherwise prompt
if [[ -n "$CLI_RENAME" ]]; then
  rename_choice="$CLI_RENAME"
  echo "  Rename mode: $rename_choice"
else
  echo "  OPTIONS:"
  echo "    [t]   = test (ONLY non-YY-MM-DD-### files)"
  echo "    [y]   = rename (ONLY non-YY-MM-DD-### files)"
  echo "    [ta]  = test ALL files (even already-correct)"
  echo "    [a]   = rename ALL files (⚠️  DESTRUCTIVE)"
  echo "    [n]   = skip renaming"
  echo
  printf "👉 Choose [t/y/ta/a/n]: "
  read -r rename_choice
fi

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
    # Only pause for user input in interactive mode
    if [[ -z "$CLI_RENAME" ]]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo
      printf "👉 Press Enter to continue to logging... "
      read -r
      echo
    fi
  fi
fi

# STEP 3: LOGGING
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

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  🎉 PIPELINE COMPLETE!                            ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  echo "  📸 ${#newly_renamed[@]} files imported, renamed & logged"
else
  echo "  📸 ${#newly_renamed[@]} files renamed & logged"
fi
echo "  📝 Seen-files log: $SEEN_LOG"
echo

# Send macOS notification
notify "Pipeline complete! ${#newly_renamed[@]} files processed."

# SD Card Eject Option
if [[ -n "$CAMERA_IMPORT_DIR" ]]; then
  if [[ $CLI_EJECT -eq 1 ]]; then
    echo "💾 Ejecting SD card: $SELECTED_NAME..."
    if diskutil unmount "$CAMERA_IMPORT_DIR" 2>/dev/null; then
      echo "  ✅ SD card ejected safely."
      notify "SD card '$SELECTED_NAME' ejected safely."
    else
      echo "  ⚠️  Could not eject SD card. Please eject manually."
    fi
    echo
  elif [[ -z "$CLI_MODE" ]]; then
    # Interactive mode: ask user
    printf "👉 Eject SD card '$SELECTED_NAME'? [y/n]: "
    read -r eject_choice
    if [[ "$eject_choice" == "y" || "$eject_choice" == "Y" ]]; then
      echo "💾 Ejecting SD card..."
      if diskutil unmount "$CAMERA_IMPORT_DIR" 2>/dev/null; then
        echo "  ✅ SD card ejected safely."
        notify "SD card '$SELECTED_NAME' ejected safely."
      else
        echo "  ⚠️  Could not eject SD card. Please eject manually."
      fi
    fi
    echo
  fi
fi

exit 0

