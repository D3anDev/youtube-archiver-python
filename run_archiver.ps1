# download-from-archive.ps1 with prefix-aware archive loading

$ArchiveFile = "yt-dlp\downloaded_archive.txt"
$ChannelsFile = "channels.txt"
$DownloadBase = "yt-dlp"
$CookiesFile = "cookies.txt"
$TempMetadataDir = "tmp_metadata"

# Ensure base download and temp metadata directories exist
if (-not (Test-Path $DownloadBase)) {
    New-Item -ItemType Directory -Force -Path $DownloadBase | Out-Null
}
if (-not (Test-Path $TempMetadataDir)) {
    New-Item -ItemType Directory -Force -Path $TempMetadataDir | Out-Null
}

# Load archive video IDs for quick lookup, stripping any prefix like 'youtube '
$DownloadedVideos = @{}
if (Test-Path $ArchiveFile) {
    Write-Host "Loading archive file with prefix-aware parsing..."
    Get-Content $ArchiveFile | ForEach-Object {
        $line = $_.Trim()
        if ($line) {
            # Split line by whitespace, take the last token as video ID
            $parts = $line -split '\s+'
            $videoId = $parts[-1]
            if (-not [string]::IsNullOrWhiteSpace($videoId)) {
                $DownloadedVideos[$videoId] = $true
            }
        }
    }
    Write-Host ("Loaded {0} video IDs from archive.`n" -f $DownloadedVideos.Count)
}
else {
    Write-Host "Archive file not found. Starting fresh.`n"
}

# Read the list of channels
$Channels = Get-Content $ChannelsFile
$totalChannels = $Channels.Count
$currentChannelIndex = 0

foreach ($ChannelURL in $Channels) {
    $currentChannelIndex++

    if ([string]::IsNullOrWhiteSpace($ChannelURL)) {
        Write-Host "Skipping empty line at channel index $currentChannelIndex" -ForegroundColor Yellow
        continue
    }

    # Extract channel ID from URL for folder naming
    $ChannelID = ($ChannelURL -replace "https://www\.youtube\.com/@([^/]+).*", '$1')
    $channelFolderPath = Join-Path $DownloadBase $ChannelID

    # Ensure channel folder exists
    if (-not (Test-Path $channelFolderPath)) {
        New-Item -ItemType Directory -Force -Path $channelFolderPath | Out-Null
        Write-Host "Created folder: $channelFolderPath"
    } else {
        Write-Host "Using existing folder: $channelFolderPath"
    }

    Write-Host "`n[$currentChannelIndex/${totalChannels}] Processing channel: $ChannelID" -ForegroundColor Cyan

    # Fetch flat playlist for video IDs (fast, minimal metadata)
    Write-Host "Fetching video IDs..."
    yt-dlp --ignore-errors --flat-playlist --print "%(id)s" --cookies $CookiesFile $ChannelURL > "$TempMetadataDir\videos.txt"

    $videoIds = Get-Content "$TempMetadataDir\videos.txt"
    $totalVideos = $videoIds.Count
    Write-Host "Found $totalVideos videos."

    # Filter videos not in archive, print detailed messages
    $VideosToDownload = @()
    $skippedCount = 0
    foreach ($videoId in $videoIds) {
        $videoId = $videoId.Trim()
        if ($DownloadedVideos.ContainsKey($videoId)) {
            Write-Host "Already in archive, skipping video ID: $videoId" -ForegroundColor Yellow
            $skippedCount++
        }
        else {
            Write-Host "Queued for download: $videoId" -ForegroundColor Green
            $VideosToDownload += "https://www.youtube.com/watch?v=$videoId"
        }
    }

    # Cleanup temporary video list file
    Remove-Item "$TempMetadataDir\videos.txt" -ErrorAction SilentlyContinue

    Write-Host "`nSummary for ${ChannelID}:" `
               "`n  Total Videos: ${totalVideos}" `
               "`n  Skipped (in archive): ${skippedCount}" `
               "`n  To Download: $($VideosToDownload.Count)`n"

    if ($VideosToDownload.Count -eq 0) {
        Write-Host "No new videos to download for channel $ChannelID." -ForegroundColor Yellow
        continue
    }

    # yt-dlp arguments for downloading and updating archive
    $ytDlpArgs = @(
        "--download-archive", $ArchiveFile,
        "--cookies", $CookiesFile,
        "-f", "bestvideo+bestaudio/best",
        "--merge-output-format", "mp4",
        "--write-info-json",
        "--write-description",
        "--write-thumbnail",
        "--write-sub",
        "--write-auto-sub",
        "--embed-subs",
        "--embed-thumbnail",
        "--embed-metadata",
        "--ignore-errors",
        "--output", (Join-Path $channelFolderPath "%(upload_date)s - %(title)s [%(id)s].%(ext)s")
    )
    $ytDlpArgs += $VideosToDownload

    Write-Host "Starting download of $($VideosToDownload.Count) videos for channel $ChannelID..." -ForegroundColor Cyan
    & yt-dlp @ytDlpArgs
    Write-Host "Finished downloading channel: $ChannelID" -ForegroundColor Green
}

Write-Host "`nAll channels processed. Downloads complete." -ForegroundColor Magenta
Write-Host "Press any key to exit..."
[System.Console]::ReadKey() | Out-Null