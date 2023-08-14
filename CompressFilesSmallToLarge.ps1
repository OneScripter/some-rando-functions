# ============================================================
# Author: Jay Adams, Noxigen LLC
# Created: 2023-08-14
# ============================================================

param(
	[string]$Path,
	[string]$Filter,
	[switch]$KeepOriginal,
	[switch]$SkipNewest
	)

function Write-Log ($message)
{
	$entry = "{0}`t{1}" -f (Get-Date).ToString("o"), $message
	
	Write-Output $entry
}

Write-Log "CompressFilesSmallToLarge.ps1 - Compress files from smallest to largest to minimize impact during operations."

if ([string]::IsNullOrWhiteSpace($Filter))
{
	Write-Log "Error: No file filter provided. Example: -Filter *.log"
	exit
}

$files = Get-ChildItem -File -Path $Path -Filter $Filter | Sort-Object LastWriteTime

if ($files.Count -eq 0)
{
	Write-Log "No files matched the search filter."
	exit
}

if ($SkipNewest -and $files.Count -eq 1)
{
	Write-Log "Error: Only one file found."
	exit
}

$newestFile = $files | Select-Object -Last 1

$files = $files | Sort-Object Length

$successCount = 0
$deleteCount = 0
$bytesSaved = 0

foreach ($file in $files)
{
	if ($SkipNewest -and $file.FullName -eq $newestFile.FullName)
	{
		$result = "Skipping newest file.`t{0}`t{1}" -f $file.FullName, $file.Length
		Write-Log $result
		continue
	}
	
	$zipFilePath = "{0}.zip" -f $file.FullName
	
	if ((Test-Path -Path $zipFilePath -Type Leaf))
	{
		$result = "Zip file already exists.`t{0}" -f $zipFilePath
		Write-Log $result
		continue
	}
	
	Write-Log "Compressing $($file.FullName)..."
	Compress-Archive -Path $file.FullName -DestinationPath $zipFilePath -CompressionLevel Optimal
	
	$successCount++
	
	$zipFile = Get-Item $zipFilePath
	
	$sizeDiff = (($file.Length - $zipFile.Length) / $file.Length) * 100
	
	$result = "Saved {0:N2} %`t{1}`t{2}`t=>`t{3}`t{4}" -f $sizeDiff, $file.FullName, $file.Length, $zipFile.FullName, $zipFile.Length
	
	Write-Log $result
	
	if ($KeepOriginal -eq $false)
	{
		try
		{
			$file.Delete()
			$deleteCount++
			$bytesSaved += ($file.Length - $zipFile.Length)
		}
		catch
		{
			$result = "Error deleting '$($file.FullName)'. Reason: $($PSItem.Exception.Message)"
		}
	}
}

$mbSaved = [math]::Round($bytesSaved / 1Mb, 2)

$result = "Done. Found {0} files. Compressed {1}. Deleted {2}. Freed up {3} MB." -f $files.Count, $successCount, $deleteCount, $mbSaved
	
Write-Log $result
