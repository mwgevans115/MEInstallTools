<#
.SYNOPSIS
Function to return the download folder

.DESCRIPTION
Function to return the download folder since it is not a standard well known folder

.EXAMPLE
Get-DownloadFolder

.NOTES
Author: Mark Evans
General notes
#>
function Get-DownloadFolder {
    Get-KnownFolderPath -KnownFolder 'Downloads'
}