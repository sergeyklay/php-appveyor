# This file is part of the php-appveyor.psm1 project.
#
# (c) Serghei Iakovlev <sadhooklay@gmail.com>
#
# For the full copyright and license information, please view
# the LICENSE file that was distributed with this source code.

function InstallPhpSdk {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Version,
		[Parameter(Mandatory=$true)]  [System.String] $VC,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = "C:\php-sdk"
	)

	Write-Debug "Install PHP SDK binary tools: ${Version}"
	SetupPrerequisites

	$FileName  = "php-sdk-${Version}"
	$RemoteUrl = "https://github.com/Microsoft/php-sdk-binary-tools/archive/${FileName}.zip"
	$Archive   = "C:\Downloads\${FileName}.zip"

	if (-not (Test-Path $InstallPath)) {
		if (-not [System.IO.File]::Exists($Archive)) {
			DownloadFile -RemoteUrl $RemoteUrl -Destination $Archive
		}

		$UnzipPath = "${Env:Temp}\php-sdk-binary-tools-${FileName}"
		If (-not (Test-Path "${UnzipPath}")) {
			Expand-Item7zip -Archive $Archive -Destination $Env:Temp
		}

		Move-Item -Path $UnzipPath -Destination $InstallPath
	}

	EnsureRequiredDirectoriesPresent `
		-Directories bin,lib,include `
		-Prefix "${InstallPath}\phpdev\vc${VC}\${Platform}"
}

function InstallPhp {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Version,
		[Parameter(Mandatory=$true)]  [System.String] $BuildType,
		[Parameter(Mandatory=$true)]  [System.String] $VC,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = "C:\php"
	)

	SetupPrerequisites
	$Version = SetupPhpVersionString -Pattern $Version

	Write-Debug "Install PHP v${Version}"

	$RemoteUrl = "http://windows.php.net/downloads/releases/php-${Version}-${BuildType}-vc${VC}-${Platform}.zip"
	$Archive   = "C:\Downloads\php-${Version}-${BuildType}-VC${VC}-${Platform}.zip"

	if (-not (Test-Path $InstallPath)) {
		if (-not [System.IO.File]::Exists($Archive)) {
			DownloadFile $RemoteUrl $Archive
		}

		Expand-Item7zip $Archive $InstallPath
	}

	if (-not (Test-Path "${InstallPath}\php.ini")) {
		Copy-Item "${InstallPath}\php.ini-development" "${InstallPath}\php.ini"
	}
}

function InstallPhpDevPack {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $PhpVersion,
		[Parameter(Mandatory=$true)]  [System.String] $BuildType,
		[Parameter(Mandatory=$true)]  [System.String] $VC,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = "C:\php-devpack"
	)

	SetupPrerequisites
	$Version = SetupPhpVersionString -Pattern $PhpVersion

	Write-Debug "Install PHP Dev for PHP v${Version}"

	$RemoteUrl = "http://windows.php.net/downloads/releases/php-devel-pack-${Version}-${BuildType}-vc${VC}-${Platform}.zip"
	$Archive   = "C:\Downloads\php-devel-pack-${Version}-${BuildType}-VC${VC}-${Platform}.zip"

	if (-not (Test-Path $InstallPath)) {
		if (-not [System.IO.File]::Exists($Archive)) {
			DownloadFile $RemoteUrl $Archive
		}

		$UnzipPath = "${Env:Temp}\php-${Version}-devel-VC${VC}-${Platform}"
		If (-not (Test-Path "$UnzipPath")) {
			Expand-Item7zip $Archive $Env:Temp
		}

		Move-Item -Path $UnzipPath -Destination $InstallPath
	}
}

function InstallPeclExtension {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Name,
		[Parameter(Mandatory=$true)]  [System.String] $Version,
		[Parameter(Mandatory=$true)]  [System.String] $PhpVersion,
		[Parameter(Mandatory=$true)]  [System.String] $BuildType,
		[Parameter(Mandatory=$true)]  [System.String] $VC,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = "C:\php\ext"
	)

	SetupPrerequisites

	$BaseUri = "https://windows.php.net/downloads/pecl/releases/${Name}/${Version}"
	$LocalPart = "php_${Name}-${Version}-${PhpVersion}"

	If ($BuildType -Match "nts-Win32") {
		$TS = "nts"
	} Else {
		$TS = "ts"
	}

	$RemoteUrl = "${BaseUri}/${LocalPart}-${TS}-vc${VC}-${Platform}.zip"
	$DestinationPath = "C:\Downloads\${LocalPart}-${TS}-vc${VC}-${Platform}.zip"

	If (-not (Test-Path "${InstallPath}\php_${Name}.dll")) {
		If (-not [System.IO.File]::Exists($DestinationPath)) {
			DownloadFile $RemoteUrl $DestinationPath
		}

		Expand-Item7zip $DestinationPath $InstallPath
	}
}

function EnablePhpExtension {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Name,
		[Parameter(Mandatory=$false)] [System.String] $PhpPath = 'C:\php',
		[Parameter(Mandatory=$false)] [System.String] $ExtPath = 'C:\php\ext',
		[Parameter(Mandatory=$false)] [System.String] $PrintableName = ''
	)

	$FullyQualifiedExtensionPath = "${ExtPath}\php_${Name}.dll"

	$IniFile = "${PhpPath}\php.ini"
	$PhpExe  = "${PhpPath}\php.exe"

	if (-not [System.IO.File]::Exists($IniFile)) {
		throw "Unable to locate ${IniFile}"
	}

	if (-not (Test-Path "${ExtPath}")) {
		throw "Unable to locate ${ExtPath} direcory"
	}

	Write-Debug "Add `"extension = ${FullyQualifiedExtensionPath}`" to the ${IniFile}"
	Write-Output "extension = ${FullyQualifiedExtensionPath}"  | Out-File -Encoding "ASCII" -Append $IniFile

	if (Test-Path -Path "${PhpExe}") {
		if ($PrintableName) {
			$Result = (& "${PhpExe}" --ri "${PrintableName}")
		} else {
			$Result = (& "${PhpExe}" --ri "${Name}")
		}

		$ExitCode = $LASTEXITCODE

		if ($ExitCode -ne 0) {
			throw "An error occurred while enabling ${Name} at ${IniFile}. ${Result}"
		}
	}
}

function TuneUpPhp {
	param (
		[Parameter(Mandatory=$false)] [System.String]   $MemoryLimit = '256M',
		[Parameter(Mandatory=$false)] [System.String[]] $DefaultExtensions = @(),
		[Parameter(Mandatory=$false)] [System.String]   $IniFile = 'C:\php\php.ini',
		[Parameter(Mandatory=$false)] [System.String]   $ExtPath = 'C:\php\ext'
	)

	Write-Debug "Tune up PHP using file `"${IniFile}`""

	if (-not [System.IO.File]::Exists($IniFile)) {
		throw "Unable to locate ${IniFile} file"
	}

	if (-not (Test-Path $ExtPath)) {
		throw "Unable to locate ${ExtPath} direcory"
	}

	Write-Output "" | Out-File -Encoding "ASCII" -Append $IniFile

	Write-Output "extension_dir = ${ExtPath}"    | Out-File -Encoding "ASCII" -Append $IniFile
	Write-Output "memory_limit = ${MemoryLimit}" | Out-File -Encoding "ASCII" -Append $IniFile

	if ($DefaultExtensions.count -gt 0) {
		Write-Output "" | Out-File -Encoding "ASCII" -Append $IniFile

		foreach ($Ext in $DefaultExtensions) {
			Write-Output "extension = php_${Ext}.dll" | Out-File -Encoding "ASCII" -Append $IniFile
		}
	}
}

function PrepareReleaseNote {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $PhpVersion,
		[Parameter(Mandatory=$true)]  [System.String] $BuildType,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $NoteFile = 'RELEASE.txt',
		[Parameter(Mandatory=$false)] [System.String] $NoteDirectory = ''
	)

	if ($NoteDirectory) {
		$Destination = "${Env:APPVEYOR_BUILD_FOLDER}\${NoteDirectory}"
	} else {
		$Destination = "${Env:APPVEYOR_BUILD_FOLDER}"
	}

	if (-not (Test-Path $Destination)) {
		New-Item -ItemType Directory -Force -Path "${Destination}" | Out-Null
	}

	$ReleaseFile = "${Destination}\${NoteFile}"
	$ReleaseDate = Get-Date -Format g

	$Image = $Env:APPVEYOR_BUILD_WORKER_IMAGE

	Write-Output "Release date: ${ReleaseDate}"                   | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Release version: ${Env:APPVEYOR_BUILD_VERSION}" | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Git commit: ${Env:APPVEYOR_REPO_COMMIT}"        | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Build type: ${BuildType}"                       | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Platform: ${Platform}"                          | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Target PHP version: ${PhpVersion}"              | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Build worker image: ${Image}"                   | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
}
function SetupPhpVersionString {
	param (
		[Parameter(Mandatory=$true)] [String] $Pattern
	)

	$RemoteUrl   = 'http://windows.php.net/downloads/releases/sha256sum.txt'
	$Destination = "${Env:Temp}\php-sha256sum.txt"

	If (-not [System.IO.File]::Exists($Destination)) {
		DownloadFile $RemoteUrl $Destination
	}

	$VersionString = Get-Content $Destination | Where-Object {
		$_ -match "php-($Pattern\.\d+)-src"
	} | ForEach-Object { $matches[1] }

	if ($VersionString -NotMatch '\d+\.\d+\.\d+' -or $null -eq $VersionString) {
		throw "Unable to obtain PHP version string using pattern 'php-($Pattern\.\d+)-src'"
	}

	Write-Output $VersionString.Split(' ')[-1]
}

function SetupPrerequisites {
	Ensure7ZipIsInstalled
	EnsureRequiredDirectoriesPresent -Directories C:\Downloads
}

function Ensure7ZipIsInstalled  {
	if (-not (Get-Command "7z" -ErrorAction SilentlyContinue)) {
		$7zipInstallationDirectory = "${Env:ProgramFiles}\7-Zip"

		if (-not (Test-Path "${7zipInstallationDirectory}")) {
			throw "The 7-zip file archiver is needed to use this module"
		}

		$Env:Path += ";$7zipInstallationDirectory"
	}
}

function EnsureRequiredDirectoriesPresent {
	param (
		[Parameter(Mandatory=$true)] [String[]] $Directories,
		[Parameter(Mandatory=$false)] [String] $Prefix = ""
	)

	foreach ($Dir in $Directories) {
		if (-not (Test-Path $Dir)) {
			if ($Prefix) {
				New-Item -ItemType Directory -Force -Path "${Prefix}\${Dir}" | Out-Null
			} else {
				New-Item -ItemType Directory -Force -Path "${Dir}" | Out-Null
			}

		}
	}
}

function DownloadFile {
	param (
		[Parameter(Mandatory=$true)] [System.String] $RemoteUrl,
		[Parameter(Mandatory=$true)] [System.String] $Destination
	)

	$RetryMax   = 5
	$RetryCount = 0
	$Completed  = $false

	$WebClient = New-Object System.Net.WebClient
	$WebClient.Headers.Add('User-Agent', 'AppVeyor PowerShell Script')

	Write-Debug "Downloading: ${RemoteUrl} => ${Destination} ..."

	while (-not $Completed) {
		try {
			$WebClient.DownloadFile($RemoteUrl, $Destination)
			$Completed = $true
		} catch  {
			if ($RetryCount -ge $RetryMax) {
				$ErrorMessage = $_.Exception.Message
				Write-Error -Message "${ErrorMessage}"
				$Completed = $true
			} else {
				$RetryCount++
			}
		}
	}
}

function Expand-Item7zip {
	param(
		[Parameter(Mandatory=$true)] [System.String] $Archive,
		[Parameter(Mandatory=$true)] [System.String] $Destination
	)

	if (-not (Test-Path -Path $Archive -PathType Leaf)) {
		throw "Specified archive file does not exist: ${Archive}"
	}

	Write-Debug "Unzipping ${Archive} to ${Destination} ..."

	if (-not (Test-Path -Path $Destination -PathType Container)) {
		New-Item $Destination -ItemType Directory | Out-Null
	}

	$Result   = (& 7z x "$Archive" "-o$Destination" -aoa -bd -y -r)
	$ExitCode = $LASTEXITCODE

	If ($ExitCode -ne 0) {
		throw "An error occurred while unzipping '${Archive}' to '${Destination}'"
	}
}
