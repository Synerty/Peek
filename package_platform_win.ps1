param([String]$wantedVer)

# Make Powershell stop if it has errors
$ErrorActionPreference = "Stop"

if (-Not [string]::IsNullOrEmpty($wantedVer)) {
    Write-Host "Requested version is $wantedVer"
}

# Get the current location
$startDir=Get-Location

$baseDir="$startDir\peek_dist_win";

# Delete the existing dist dir if it exists
If (Test-Path $baseDir){
    Remove-Item $baseDir -Force -Recurse;
}

# Create our new dist dir
New-Item $baseDir -ItemType directory;

# ------------------------------------------------------------------------------
# Download the peek platform and all it's dependencies
New-Item "$baseDir\py" -ItemType directory;
Set-Location "$baseDir\py";

Write-Host "Downloading and creating windows wheels";
pip wheel --no-cache synerty-peek;

# Make sure we've downloaded the right version
$peekPkgName = Get-ChildItem ".\" |
                    Where-Object {$_.Name.StartsWith("synerty_peek-")} |
                    Select-Object -exp Name;
$peekPkgVer = $peekPkgName.Split('-')[1];

if (-Not [string]::IsNullOrEmpty($wantedVer) -and $peekPkgVer -ne $wantedVer) {
    Set-Location "$startDir";
    Write-Error "We've downloaded version $peekPkgVer, but you wanted ver $wantedVer";
} else {
    Write-Host "We've downloaded version $peekPkgVer";
}


# Download pymssql, As to 11/Apr/2017, there are no standard built wheels for 3.6.1
$pymssqlUrl = 'http://www.lfd.uci.edu/%7Egohlke/pythonlibs/tuoh5y4k/pymssql-2.1.3-cp36-cp36m-win_amd64.whl';
$pymssqlFile = 'pymssql-2.1.3-cp36-cp36m-win_amd64.whl';
Invoke-WebRequest -Uri $pymssqlUrl -UseBasicParsing -OutFile $pymssqlFile;

# Download shapely, it's not a dependency on windows because pip doesn't try to get the windows dist.
$shapeUrl = 'http://www.lfd.uci.edu/~gohlke/pythonlibs/tuth5y6k/Shapely-1.5.17-cp35-cp35m-win_amd64.whl';
$shapeFile = 'Shapely-1.5.17-cp35-cp35m-win_amd64.whl';
Invoke-WebRequest -Uri $shapeUrl -UseBasicParsing -OutFile $shapeFile;

# ------------------------------------------------------------------------------
# Download node, npm, @angular/cli, typescript and tslint

Set-Location "$baseDir";
$nodeVer = "7.7.4";

# Download the file
$nodeUrl = "https://nodejs.org/dist/v$nodeVer/node-v$nodeVer-win-x64.zip";
$nodeFile = "node.zip";
Invoke-WebRequest -Uri $nodeUrl -UseBasicParsing -OutFile $nodeFile;

# Unzip it
Write-Host "Using standard windows zip handler, this will be slow";
Add-Type -Assembly System.IO.Compression.FileSystem;
[System.IO.Compression.ZipFile]::ExtractToDirectory("$baseDir\$nodeFile", $baseDir);

# Remove the downloaded file
Remove-Item "$baseDir\$nodeFile" -Force -Recurse;

# Move NODE into place
Move-Item "$nodeVer" "node"

# Set the path for future NODE commands
$env:Path = "$baseDir\node;$env:Path"

# Install the required NPM packages
npm -g upgrade npm
npm -g install @angular/cli typescript tslint;


# ------------------------------------------------------------------------------
# Download the node_packages


# Define the node packages we want to download
$nodePackages = @(
    # node modules are not required unless developing, which will be installed later.
    # @{"dir" = "$baseDir\mobile-build-ns";
    #     "packageJsonUrl" = "https://raw.githubusercontent.com/Synerty/peek-mobile/master/peek_mobile/build-ns/package.json"
    # },
    @{"dir" = "$baseDir\mobile-build-web";
        "packageJsonUrl" = "https://raw.githubusercontent.com/Synerty/peek-mobile/master/peek_mobile/build-web/package.json"
    },
    @{"dir" = "$baseDir\admin-build-web";
        "packageJsonUrl" = "https://raw.githubusercontent.com/Synerty/peek-admin/master/peek_admin/build-web/package.json"
    }
);

foreach ($element in $nodePackages) {
    # Get the variables for this package
    $nmDir = $element.Get_Item("dir");
    $packageJsonUrl = $element.Get_Item("packageJsonUrl");

    # Create the tmp dir
    New-Item "$nmDir\tmp" -ItemType directory;
    Set-Location "$nmDir\tmp";

    # Download pacakge.json
    Invoke-WebRequest -Uri $packageJsonUrl -UseBasicParsing -OutFile "package.json";

    # run npm install
    npm install

    # Move to where we want node_modules and delete the tmp dir
    # some packages create extra files that we don't want
    Set-Location $nmDir;
    Move-Item "tmp\node_modules" ".\"

    # Cleanup the temp dir
    Remove-Item "tmp" -Force -Recurse;
}

# ------------------------------------------------------------------------------
# Set the location back to where we were.
Set-Location $startDir;

# Finally, version the directory
$releaseDir="$($baseDir)_$($peekPkgVer)";
$relaseZip="$($releaseDir).zip"
Move-Item $baseDir $releaseDir -Force;

# Create the zip file
Add-Type -Assembly System.IO.Compression.FileSystem;
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal;
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $releaseDir, $relaseZip, $compressionLevel, $false)

# We're all done.
Write-Host "Successfully created release $peekPkgVer";
Write-Host "Located at $relaseZip";
