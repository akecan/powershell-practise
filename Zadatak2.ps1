param (
    [int]$num5DigitFolders = 5, # Zeljeni broj petocifrenih foldera
    [int]$numDateFolders = 4,   # Zeljeni broj datum foldera unutar svakog petocifrenog foldera
    [int]$numFilesPerFolder = 3 # Broj random fajlova koje treba ignorisati u svakom datum folderu
)

# Kreiranje root foldera "izvodi"
New-Item -Path "izvodi" -ItemType Directory -Force

# Globalni hashtable koji prati asocijaciju izmedju petocifrenih foldera i njihovih trinaestocifrenih brojeva
$global:digitNumberMap = @{}

# Ova funkcija ili vraca postojece trinaestocifrene brojeve za zadati petocifreni broj ili kreira nove ako ne postoje i ubacuje ih u hashtable 
function GetOrCreate13DigitNumbers {
    param ([string]$fiveDigitNumber)
    if (-not $global:digitNumberMap.ContainsKey($fiveDigitNumber)) {
        $firstNumber = Get-Random -Minimum 1000000000000 -Maximum 9999999999999
        $secondNumber = Get-Random -Minimum 1000000000000 -Maximum 9999999999999
        $global:digitNumberMap[$fiveDigitNumber] = @($firstNumber, $secondNumber)
    }
    return $global:digitNumberMap[$fiveDigitNumber]
}

# Ova funkcija pravi PDF.ZIP, JSON.ZIP i TXT.ZIP fajlove za zadati trinaestocifreni broj
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

# ovaj deo skripte generise imena petocifrenih foldera i poziva funkciju GetOrCreate13DigitNumbers za svaki
$allFolderNumbers = @()
1..$num5DigitFolders | ForEach-Object {
    do {
        $randomNumber = Get-Random -Minimum 10000 -Maximum 99999
    } while ($randomNumber -in $allFolderNumbers)
    $allFolderNumbers += $randomNumber
    GetOrCreate13DigitNumbers $randomNumber 
}

# Glavna petlja koja prolazi kroz svaki petocifreni broj i za njega pravi datum foldere, _sve-partije.json fajlove i random fajlove koje treba ignorisati
foreach ($folderNumber in $allFolderNumbers) {
    $folderPath = Join-Path "izvodi" $folderNumber
    New-Item -Path $folderPath -ItemType Directory -Force

    # Pravi datum foldere 
    $dateFolderNames = @()
    for ($i = 0; $i -lt $numDateFolders; $i++) {
        $randomDate = Get-Random -Minimum (Get-Date).AddMonths(-2).Ticks -Maximum (Get-Date).Ticks
        $dateFolderName = (Get-Date $randomDate).ToString("yyyy-MM-dd")
        if (-not $dateFolderNames.Contains($dateFolderName)) {
            $dateFolderNames += $dateFolderName
            $dateFolderPath = Join-Path $folderPath $dateFolderName
            New-Item -Path $dateFolderPath -ItemType Directory -Force
            
            #dodaje random fajlove
            1..$numFilesPerFolder | ForEach-Object {
                $fileName = "file$_.txt"
                New-Item -Path (Join-Path $dateFolderPath $fileName) -ItemType File
            }

            # Poziva Create-FormattedFiles funkciju za svaki od trinaestocifrenih brojeva asociranih sa petoicfrenim folderom
            $ownNumbers = GetOrCreate13DigitNumbers $folderNumber
            foreach ($number in $ownNumbers) {
                Create-FormattedFiles -path $dateFolderPath -number $number
            }
        }
    }

    # Generise JSON kontent za folder u kojem se _sve-partije.json nalazi
    $jsonContent = New-Object PSObject
    $ownNumbers = GetOrCreate13DigitNumbers $folderNumber
    $jsonContent | Add-Member -MemberType NoteProperty -Name "$folderNumber" -Value $ownNumbers

    # Generise JSON kontent za ostale foldere
    foreach ($additionalNumber in $allFolderNumbers | Where-Object { $_ -ne $folderNumber }) {
        $additionalNumbers = GetOrCreate13DigitNumbers $additionalNumber
        $jsonContent | Add-Member -MemberType NoteProperty -Name "$additionalNumber" -Value $additionalNumbers
    }

    # Konvertuje kontent u JSON i cuva u _sve-partije.json
    $jsonString = $jsonContent | ConvertTo-Json -Depth 3
    $jsonFilePath = Join-Path $folderPath "${folderNumber}_sve-partije.json"
    Set-Content -Path $jsonFilePath -Value $jsonString
}

Write-Host "Struktura foldera i fajlova uspesno generisana."
