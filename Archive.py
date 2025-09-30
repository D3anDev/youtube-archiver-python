import os
import subprocess

# Required Files
ARCHIVE_FILE = "yt-dlp/downloaded_archive.txt"
CHANNELS_FILE = "channels.txt"
DOWNLOAD_BASE = "yt-dlp"
COOKIES_FILE = "cookies.txt"
TEMP_METADATA_DIR = "tmp_metadata"


# Ensures base download and temp metadata dirs exist
os.makedirs(DOWNLOAD_BASE,exist_ok=True)
os.makedirs(TEMP_METADATA_DIR, exist_ok=True)

# Def array of downloaded videos from archive
downloaded_videos = {}
if os.path.exists(ARCHIVE_FILE):
    print("Loading archive file with prefix aware parsing...")
    with open(ARCHIVE_FILE, 'r') as archive:
        for line in archive:
            line = line.strip()
            video_id = parts[-1]
            if video_id:
                downloaded_videos[video_id] = True
    print(f"Loaded {len(downloaded_videos)} video IDs from archive.\n")
else:
    print("Archive file not found. Starting fresh.\n")