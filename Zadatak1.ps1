param(
    [Parameter(Mandatory=$true)]
    [string]$dateFolder # Datum kao parametar u forrmatu 'yyyy-MM-dd'
)

$rootDir = "izvodi"

# Osigurati da izvodi postoje
if (-Not (Test-Path $rootDir)) {
    Write-Error "'$rootDir' direktorijum ne postoji."
    exit
}

# Prolazimo kroz svaki petocifreni folder
Get-ChildItem -Path $rootDir -Directory | Where-Object { $_.Name -match '^\d{5}$' } | ForEach-Object {
    $folder = $_
    $dateFolderPath = Join-Path -Path $folder.FullName -ChildPath $dateFolder
    
    # Nastavlja ako trazeni datum folder postoji
    if (Test-Path $dateFolderPath) {
        # Privremeni folder za ekstraktovane fajlove
        $tempExtractionPath = Join-Path -Path $dateFolderPath -ChildPath "temp_extraction"
        New-Item -Path $tempExtractionPath -ItemType Directory -Force | Out-Null

        # Pronalazi sve zip fajlove i ekstraktuje ih
        Get-ChildItem -Path $dateFolderPath -File | Where-Object { $_.Extension -eq '.zip' } | ForEach-Object {
            $zipFile = $_.FullName
            $unzipCommand = "unzip -o `"$zipFile`" -d `"$tempExtractionPath`""
            Invoke-Expression $unzipCommand
        }

        # Trazi PDF, JSON i TXT fajlove koji imaju u imenu trinaestocifreni broj
        $filesToZip = Get-ChildItem -Path $tempExtractionPath -File | Where-Object { $_.Name -match '^\d{13}\.(pdf|json|txt)$' }

        # Nastavlja ako pronadje odgovarajuci fajl
        if ($filesToZip.Count -gt 0) {
            $finalZipPath = Join-Path -Path $dateFolderPath -ChildPath "$($folder.Name)_sve-partije.zip"

            # Provera da li zip arhiva vec postoji radi idempodencije
            if (-Not (Test-Path $finalZipPath)) {
                # Pravi zip arhivu
                Compress-Archive -Path $filesToZip.FullName -DestinationPath $finalZipPath
                Write-Host "Arhiva napravljena: $finalZipPath"
            }
            else {
                Write-Host "Arhiva vec postoji: $finalZipPath"
            }
        }
        else {
            Write-Host "Nije pronadjen ni jedan validan trinaestocifreni fajl u '$dateFolderPath', arhiva nije napravljena."
        }

        # Brisanje privremenog foldera
        Remove-Item -Path $tempExtractionPath -Recurse -Force
    }
    else {
        Write-Host "Datumski folder '$dateFolderPath' ne postoji."
    }
}
