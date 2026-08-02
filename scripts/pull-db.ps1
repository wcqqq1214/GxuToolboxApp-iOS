$ErrorActionPreference = "Stop"

$PackageName = "com.gxu_tool_app.debug"
$DbName = "gxu_tool.db"
$OutDir = "debug-db"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Pull-DbFile {
  param (
      [string]$FileName,
      [bool]$Required = $false
  )

  $OutPath = Join-Path $OutDir $FileName
  $RemotePath = "databases/$FileName"

  cmd /c "adb exec-out run-as $PackageName cat $RemotePath > `"$OutPath`""

  if ($LASTEXITCODE -ne 0) {
      if (Test-Path $OutPath) {
          Remove-Item $OutPath -Force
      }

      if ($Required) {
          throw "Pull failed: $RemotePath"
      }

      Write-Host "Skip missing file: $FileName"
      return
  }

  Write-Host "Pulled: $OutPath"
}

Pull-DbFile $DbName $true
Pull-DbFile "$DbName-wal" $false
Pull-DbFile "$DbName-shm" $false

Write-Host "Done. Open debug-db\$DbName in IDEA."
