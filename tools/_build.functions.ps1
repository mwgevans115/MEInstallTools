<#
.SYNOPSIS
    Increment a Semantic Version
.DESCRIPTION
    Parse a string in the format of MAJOR.MINOR.PATCH and increment the
    selected digit.
.EXAMPLE
    C:\PS> Step-Version 1.1.1
    1.1.2

    Will increment the Patch/Build section of the Version
.EXAMPLE
    C:\PS> Step-Version 1.1.1 Minor
    1.2.0

    Will increment the Minor section of the Version
.EXAMPLE
    C:\PS> Step-Version 1.1.1 Major
    2.0.0

    Will increment the Major section of the Version
.EXAMPLE
    C:\PS> $v = [version]"1.1.1"
    C:\PS> $v | Step-Version -Type Minor
    1.2.0
.INPUTS
    String
.OUTPUTS
    String
.NOTES
    This function operates on strings.
#>
function Step-Version {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        # Version as string to increment
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String]
        $Version,

        # Version section to step
        [Parameter(Position=1)]
        [ValidateSet("Major", "Minor", "Build","Patch")]
        [Alias("Type")]
        [string]
        $By = "Patch"
    )

    Process
    {
        $currentVersion = [version]$Version

        $major = $currentVersion.Major
        $minor = $currentVersion.Minor
        $build = $currentVersion.Build

        switch ($By) {
            "Major" { $major++
                    $minor = 0
                    $build = 0
                    break }
            "Minor" { $minor++
                    $build = 0
                    break }
            Default { $build++
                    break }
        }

        $Version = New-Object Version -ArgumentList $major, $minor, $build

        Write-Output -InputObject $Version.ToString()
    }
}

function Test-GitRepo {
    try {
        git --no-pager -C $ProjectRoot tag 2>&1 | Out-Null
        [Bool]$Result = $true
    }
    catch {
        $Result=$false
    }
    Return $Result
}

function New-GitRepo{
    git -C $ProjectRoot init
    git -C $ProjectRoot add *
    $Version = "$((Test-ModuleManifest -Path $ManifestFile).Version)"
    git -C $ProjectRoot commit -m "[Version] Initial Version $Version" | Out-Null
    New-GitVersionTag
}

function New-GitVersionTag{
    $Version = "$((Test-ModuleManifest -Path $ManifestFile).Version)"
    if (!(git -C $ProjectRoot tag --list "Version $Version")){
        git -C $ProjectRoot tag -a "Version-$Version" -m "Version $Version"
    }
}

function Test-AllChangesCommitted{
    if (Test-GitRepo){
        try {
            [string]$GitDiff = git --no-pager -C $ProjectRoot diff 2>&1
        }
        catch {
            [string]$GitDiff = 'Unknown Result'
        }
    }
    Return [string]::IsNullOrEmpty($GitDiff)
}