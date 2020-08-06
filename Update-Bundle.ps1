# ----------------
# FUNCTIONS
# ----------------

function Update-AppxBundleManifest ([string]$ManifestPath, [string]$TenantName) {
    [xml]$bundleManifestXml = Get-Content -Path $ManifestPath
    $bundleManifestXml.Bundle.Identity.Name = "StoreLogo.App.$TenantName"
    $bundleManifestXml.Save($ManifestPath)
}

function Update-AppxManifest ([string]$ManifestPath, [string]$TenantName) {
    [xml]$manifestXml = Get-Content -Path $ManifestPath
    $manifestXml.Package.Identity.Name = "StoreLogo.App.$TenantName"
    $manifestXml.Package.Properties.DisplayName = "StoreLogo App $TenantName"
    if ($manifestXml.Package.Applications.Application.VisualElements) {
        $manifestXml.Package.Applications.Application.VisualElements.DisplayName = "StoreLogo App $TenantName"
        $manifestXml.Package.Applications.Application.VisualElements.Description = "StoreLogo App for $TenantName"
        $manifestXml.Package.Applications.Application.VisualElements.DefaultTile.ShortName = "StoreLogo $TenantName"
    }
    $manifestXml.Save($ManifestPath)
}

function Update-AppxBlockMap ([string]$BlockMapPath) {
    [xml]$blockMapXml = Get-Content -Path $BlockMapPath
    $blockMapXml.BlockMap.File | Where-Object Name -Like "CustomerImages*" | ForEach-Object {
        $blockMapXml.DocumentElement.RemoveChild($_)
    }
    $blockMapXml.Save($BlockMapPath)
}

function Update-Images ([string]$UnpackPath, [string]$TenantName) {
    Copy-Item -Path "$UnpackPath\CustomerImages\$TenantName\*.*" -Destination "$UnpackPath\Images" -Force
    Remove-Item -Path "$UnpackPath\CustomerImages" -Recurse -Force
}

# ----------------
# VARIABLES
# ----------------

$version = "1.0.0.0"
$tenantName = "CustomerA" # Demo, CustomerA, CustomerB

$commandMakeAppx = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\makeappx.exe"
$commandSignTool = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
$commandMakePri = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\makepri.exe"

$certificatePfx = ".\StoreLogo.Setup\StoreLogo.Setup_TemporaryKey.pfx"

$msixFile = ".\StoreLogo.Setup\AppPackages\StoreLogo.Setup_1.0.0.0_x64_Test\StoreLogo.Setup_1.0.0.0_x64.msix"

$msixOutputFile = ".\Output\StoreLogo.Setup_1.0.0.0_x64.msix"

$unpackRelativePath = ".\Unpack"

# ----------------
# MAIN SCRIPT
# ----------------

Write-Host "Start unpack commmand for the main msix"
& $commandMakeAppx unpack /o /p $msixFile /d $unpackRelativePath

$unpackPath =  Resolve-Path -Path $unpackRelativePath

if ($tenantName -ne "Demo") {
    Write-Host "Change AppxManifest.xml of all the msix packages"
    Update-AppxManifest -ManifestPath "$unpackPath\AppxManifest.xml" -TenantName $tenantName

    Write-Host "Update images of all the msix packages"
    Update-Images -UnpackPath $unpackPath -TenantName $tenantName

    Write-Host "Update AppxBlockMap.xml of all the msix packages"
    Update-AppxBlockMap -BlockMapPath "$unpackPath\AppxBlockMap.xml"
}

Write-Host "Generating resources.pri"
Set-Location -Path $unpackPath
& $commandMakePri createconfig /cf priconfig.xml /dq en-US /o
& $commandMakePri new /pr $unpackPath /cf priconfig.xml /o

cd..
Write-Host "Start pack commmand for the main msix"
& $commandMakeAppx pack /v /o /h SHA256 /d $unpackPath /p $msixOutputFile

Write-Host "Start sign commmand"
& $commandSignTool sign /fd SHA256 /t "http://timestamp.digicert.com" /f $certificatePfx $msixOutputFile
