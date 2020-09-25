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

$currentDir = Get-Location

$version = "1.0.0.0"
$tenantName = "CustomerA" # Demo, CustomerA, CustomerB

$commandMakeAppx = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\makeappx.exe"
$commandSignTool = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"

$certificatePfx = Join-Path $currentDir "StoreLogo.Setup\StoreLogo.Setup_TemporaryKey.pfx"

$msixBundleFile = Join-Path $currentDir "StoreLogo.Setup\AppPackages\StoreLogo.Setup_1.0.0.0_Test\StoreLogo.Setup_1.0.0.0_x64.msixbundle"

$msixBundleOutputFile = Join-Path $currentDir "Output\StoreLogo.Setup_1.0.0.0_x64.msixbundle"

$unbundlePath = Join-Path $currentDir "Unbundle"

$msixFile = "$unbundlePath\StoreLogo.Setup_1.0.0.0_x64.msix"
$msixScale100File = "$unbundlePath\StoreLogo.Setup_1.0.0.0_scale-100.msix"
$msixScale125File = "$unbundlePath\StoreLogo.Setup_1.0.0.0_scale-125.msix"
$msixScale150File = "$unbundlePath\StoreLogo.Setup_1.0.0.0_scale-150.msix"
$msixScale400File = "$unbundlePath\StoreLogo.Setup_1.0.0.0_scale-400.msix"

$unpackBasePath = Join-Path $currentDir "Unpack"
$unpackPath = "$unpackBasePath\x64"
$unpackScale100Path = "$unpackBasePath\scale-100"
$unpackScale125Path = "$unpackBasePath\scale-125"
$unpackScale150Path = "$unpackBasePath\scale-150"
$unpackScale400Path = "$unpackBasePath\scale-400"

# ----------------
# MAIN SCRIPT
# ----------------

Write-Host "Start unbundle commmand"
& $commandMakeAppx unbundle /o /p $msixBundleFile /d $unbundlePath

Write-Host "Start unpack commmand for the main msix"
& $commandMakeAppx unpack /o /p $msixFile /d $unpackPath

Write-Host "Start unpack commmand for the scale-100 msix"
& $commandMakeAppx unpack /o /p $msixScale100File /d $unpackScale100Path

Write-Host "Start unpack commmand for the scale-125 msix"
& $commandMakeAppx unpack /o /p $msixScale125File /d $unpackScale125Path

Write-Host "Start unpack commmand for the scale-150 msix"
& $commandMakeAppx unpack /o /p $msixScale150File /d $unpackScale150Path

Write-Host "Start unpack commmand for the scale-400 msix"
& $commandMakeAppx unpack /o /p $msixScale400File /d $unpackScale400Path

if ($tenantName -ne "Demo") {
    Write-Host "Change AppxBundleManifest.xml of the bundle"
    Update-AppxBundleManifest -ManifestPath "$unbundlePath\AppxMetadata\AppxBundleManifest.xml" -TenantName $tenantName

    Write-Host "Change AppxManifest.xml of all the msix packages"
    Update-AppxManifest -ManifestPath "$unpackPath\AppxManifest.xml" -TenantName $tenantName
    Update-AppxManifest -ManifestPath "$unpackScale100Path\AppxManifest.xml" -TenantName $tenantName
    Update-AppxManifest -ManifestPath "$unpackScale125Path\AppxManifest.xml" -TenantName $tenantName
    Update-AppxManifest -ManifestPath "$unpackScale150Path\AppxManifest.xml" -TenantName $tenantName
    Update-AppxManifest -ManifestPath "$unpackScale400Path\AppxManifest.xml" -TenantName $tenantName

    Write-Host "Update images of all the msix packages"
    Update-Images -UnpackPath $unpackPath -TenantName $tenantName
    Update-Images -UnpackPath $unpackScale100Path -TenantName $tenantName
    Update-Images -UnpackPath $unpackScale125Path -TenantName $tenantName
    Update-Images -UnpackPath $unpackScale150Path -TenantName $tenantName
    Update-Images -UnpackPath $unpackScale400Path -TenantName $tenantName

    Write-Host "Update AppxBlockMap.xml of all the msix packages"
    Update-AppxBlockMap -BlockMapPath "$unpackPath\AppxBlockMap.xml"
    Update-AppxBlockMap -BlockMapPath "$unpackScale100Path\AppxBlockMap.xml"
    Update-AppxBlockMap -BlockMapPath "$unpackScale125Path\AppxBlockMap.xml"
    Update-AppxBlockMap -BlockMapPath "$unpackScale150Path\AppxBlockMap.xml"
    Update-AppxBlockMap -BlockMapPath "$unpackScale400Path\AppxBlockMap.xml"
}

Write-Host "Start pack commmand for the main msix"
& $commandMakeAppx pack /v /o /h SHA256 /d $unpackPath /p $msixFile

Write-Host "Start pack commmand for the scale-100 msix"
& $commandMakeAppx pack /v /o /h SHA256 /d $unpackScale100Path /p $msixScale100File

Write-Host "Start pack commmand for the scale-125 msix"
& $commandMakeAppx pack /v /o /h SHA256 /d $unpackScale125Path /p $msixScale125File

Write-Host "Start pack commmand for the scale-150 msix"
& $commandMakeAppx pack /v /o /h SHA256 /d $unpackScale150Path /p $msixScale150File

Write-Host "Start pack commmand for the scale-400 msix"
& $commandMakeAppx pack /v /o /h SHA256 /d $unpackScale400Path /p $msixScale400File

Write-Host "Start bundle command"
& $commandMakeAppx bundle /v /o /bv $version /d $unbundlePath /p $msixBundleOutputFile

Write-Host "Start sign commmand"
& $commandSignTool sign /fd SHA256 /t "http://timestamp.digicert.com" /f $certificatePfx $msixBundleOutputFile
