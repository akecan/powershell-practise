param (
    [int]$num5DigitFolders = 5, # Desired number of 5-digit folders
    [int]$numDateFolders = 4,   # Desired number of date folders within each 5-digit folder
    [int]$numFilesPerFolder = 3 # Number of random files to include in each date folder
)

# Create the root folder "izvodi"
New-Item -Path "izvodi" -ItemType Directory -Force

# Hashtable to track the association between 5-digit folders and their 13-digit numbers
$digitNumberMap = @{}

# Function to either return existing 13-digit numbers for a given 5-digit number or create new ones if they don't exist, and insert them into the hashtable
function GetOrCreate13DigitNumbers {
    param ([string]$fiveDigitNumber)
    if (-not $digitNumberMap.ContainsKey($fiveDigitNumber)) {
        $firstNumber = Get-Random -Minimum 1000000000000 -Maximum 9999999999999
        $secondNumber = Get-Random -Minimum 1000000000000 -Maximum 9999999999999
        $digitNumberMap[$fiveDigitNumber] = @($firstNumber, $secondNumber)
    }
    return $digitNumberMap[$fiveDigitNumber]
}

# Function to create PDF.ZIP, JSON.ZIP, and TXT.ZIP files for a given 13-digit number
function Create-FormattedFiles {
    param (
        [String]$path,
        [String]$number
    )
    $formats = @("pdf", "json", "txt")
    foreach ($format in $formats) {
        $fileName = "$number.$format"
        $fullPath = Join-Path $path $fileName
        Set-Content -Path $fullPath -Value "Sample content for $fileName"
        $zipPath = "$fullPath.zip"
        if (-not (Test-Path $zipPath)) {
            Compress-Archive -Path $fullPath -DestinationPath $zipPath
            Remove-Item -Path $fullPath
        }
    }
}

# Generate names for the 5-digit folders and call GetOrCreate13DigitNumbers function for each
$allFolderNumbers = @()
1..$num5DigitFolders | ForEach-Object {
    do {
        $randomNumber = Get-Random -Minimum 10000 -Maximum 99999
    } while ($randomNumber -in $allFolderNumbers)
    $allFolderNumbers += $randomNumber
    GetOrCreate13DigitNumbers $randomNumber 
}

# Main loop to iterate through each 5-digit folder, creating date folders and corresponding files
foreach ($folderNumber in $allFolderNumbers) {
    $folderPath = Join-Path "izvodi" $folderNumber
    New-Item -Path $folderPath -ItemType Directory -Force

    # Create date folders
    $dateFolderNames = @()
    for ($i = 0; $i -lt $numDateFolders; $i++) {
        $randomDate = Get-Random -Minimum (Get-Date).AddMonths(-2).Ticks -Maximum (Get-Date).Ticks
        $dateFolderName = (Get-Date $randomDate).ToString("yyyy-MM-dd")
        $dateFolderPath = Join-Path $folderPath $dateFolderName
        if (-not $dateFolderNames.Contains($dateFolderName)) {
            New-Item -Path $dateFolderPath -ItemType Directory -Force
            1..$numFilesPerFolder | ForEach-Object {
                $fileName = "file$_.txt"
                New-Item -Path (Join-Path $dateFolderPath $fileName) -ItemType File
            }

            $ownNumbers = GetOrCreate13DigitNumbers $folderNumber
            foreach ($number in $ownNumbers) {
                Create-FormattedFiles -path $dateFolderPath -number $number
            }
        }
    }

    # Generate JSON content for the folder where the _sve-partije.json file resides
    $jsonContent = New-Object PSObject
    $ownNumbers = GetOrCreate13DigitNumbers $folderNumber
    $jsonContent | Add-Member -MemberType NoteProperty -Name "$folderNumber" -Value $ownNumbers

    # Generate JSON content for other folders
    foreach ($additionalNumber in $allFolderNumbers | Where-Object { $_ -ne $folderNumber }) {
        $additionalNumbers = GetOrCreate13DigitNumbers $additionalNumber
        $jsonContent | Add-Member -MemberType NoteProperty -Name "$additionalNumber" -Value $additionalNumbers
    }

    # Convert content to JSON and save to _sve-partije.json
    $jsonString = $jsonContent | ConvertTo-Json -Depth 3
    $jsonFilePath = Join-Path $folderPath "${folderNumber}_sve-partije.json"
    Set-Content -Path $jsonFilePath -Value $jsonString
}

Write-Host "Folder and file structure successfully generated."
