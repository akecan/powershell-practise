# Optional parameter that allows specifying a particular date folder to process.
# If not provided, the script will process all available date folders within each 5-digit folder.
param(
    [string]$dateFolder 
)

# The root directory where the 5-digit folders are located.
$rootDir = "izvodi"

# Check if the root directory exists. If it doesn't, the script terminates with an error message.
if (-Not (Test-Path $rootDir)) {
    Write-Error "'$rootDir' directory does not exist."
    exit
}

# Function to calculate and return a hashtable of file hashes within a given directory.
# This aids in detecting file changes for idempotency.
function Get-FileHashes {
    param (
        [string]$directory
    )
    $hashes = @{}
    Get-ChildItem -Path $directory -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
        $hash = (Get-FileHash -Path $_.FullName -Algorithm MD5).Hash
        $hashes[$_.Name] = $hash
    }
    return $hashes
}

# Iterates through each 5-digit folder within the root directory.
Get-ChildItem -Path $rootDir -Directory | Where-Object { $_.Name -match '^\d{5}$' } | ForEach-Object {
    $folder = $_
    $dateFolderPaths = @()

    # Determines whether to process a specific date folder or all available date folders.
    if ($dateFolder) {
        $specificDateFolderPath = Join-Path -Path $folder.FullName -ChildPath $dateFolder
        if (Test-Path $specificDateFolderPath) {
            $dateFolderPaths += $specificDateFolderPath
        }
    } else {
        # Retrieves all date folders if no specific date is provided.
        $dateFolderPaths = Get-ChildItem -Path $folder.FullName -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } | ForEach-Object { $_.FullName }
    }

    # Processes each date folder.
    foreach ($dateFolderPath in $dateFolderPaths) {
        # Creates a unique temporary directory for extraction to avoid data remnant issues between runs.
        $tempExtractionPath = Join-Path -Path $dateFolderPath -ChildPath ("temp_extraction_" + [Guid]::NewGuid().ToString())
        New-Item -Path $tempExtractionPath -ItemType Directory -Force | Out-Null

        # Extracts all zip files found within the date folder.
        Get-ChildItem -Path $dateFolderPath -File | Where-Object { $_.Extension -eq '.zip' } | ForEach-Object {
            Expand-Archive -Path $_.FullName -DestinationPath $tempExtractionPath -Force
        }

        # Selects files for zipping based on a naming convention (13-digit number followed by file type).
        $filesToZip = Get-ChildItem -Path $tempExtractionPath -File | Where-Object { $_.Name -match '^\d{13}\.(pdf|json|txt)$' }
        $finalZipPath = Join-Path -Path $dateFolderPath -ChildPath "$($folder.Name)_sve-partije.zip"

        # Determines if the archive needs updating by comparing checksums.
        if ($filesToZip.Count -gt 0) {
            $currentHashes = Get-FileHashes -directory $tempExtractionPath

            $shouldUpdateArchive = $false
            if (Test-Path $finalZipPath) {
                $existingZipContentPath = Join-Path -Path $tempExtractionPath -ChildPath "existing"
                New-Item -Path $existingZipContentPath -ItemType Directory -Force | Out-Null
                Expand-Archive -Path $finalZipPath -DestinationPath $existingZipContentPath
                
                $existingHashes = Get-FileHashes -directory $existingZipContentPath
                
                # Compares hashes of existing files with current files. If different, the archive needs updating.
                $differences = Compare-Object -ReferenceObject $existingHashes.Values -DifferenceObject $currentHashes.Values
                if ($differences) {
                    $shouldUpdateArchive = $true
                }
            } else {
                $shouldUpdateArchive = $true
            }

            # Updates or creates the ZIP archive if necessary, with error handling for resilience.
            if ($shouldUpdateArchive) {
                try {
                    Compress-Archive -Path $filesToZip.FullName -DestinationPath $finalZipPath -Force
                    Write-Host "Archive created/updated: ${finalZipPath}"
                } catch {
                    Write-Warning "Failed to create/update archive ${finalZipPath}: $_"
                }
            } else {
                Write-Host "Archive is up to date, no update required: ${finalZipPath}"
            }
        }

        # Cleans up the temporary extraction path after processing.
        Remove-Item -Path $tempExtractionPath -Recurse -Force
    }
}

# Indicates the script has completed processing.
Write-Host "Processing completed."
