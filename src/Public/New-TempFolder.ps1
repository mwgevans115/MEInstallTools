function New-TempFolder {
    param(
        [String]
        $Root
    )
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    If ($Root) {
        New-Item -ItemType Directory -Path (Join-Path $parent "$name\$root") -Force
    } else {
        New-Item -ItemType Directory -Path (Join-Path $parent $name)
    }
  }