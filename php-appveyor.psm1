# This file is part of the php-appveyor.psm1 project.
#
# (c) Serghei Iakovlev <sadhooklay@gmail.com>
#
# For the full copyright and license information, please view
# the LICENSE file that was distributed with this source code.

Set-Variable `
	-name _PHP_SDK_BASE_URI_ `
	-value "https://github.com/Microsoft/php-sdk-binary-tools" `
	-Scope Global `
	-Option ReadOnly `
	-Force

Set-Variable `
	-name _PHP_DOWNLOADS_BASE_URI_ `
	-value "http://windows.php.net/downloads/releases" `
	-Scope Global `
	-Option ReadOnly `
	-Force

Set-Variable `
	-name _PECL_DOWNLOADS_BASE_URI_ `
	-value "https://windows.php.net/downloads/pecl/releases" `
	-Scope Global `
	-Option ReadOnly `
	-Force

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
	$RemoteUrl = "${_PHP_SDK_BASE_URI_}/archive/${FileName}.zip"
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

	$RemoteUrl = "${_PHP_DOWNLOADS_BASE_URI_}/php-${Version}-${BuildType}-vc${VC}-${Platform}.zip"
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

	$RemoteUrl = "${_PHP_DOWNLOADS_BASE_URI_}/php-devel-pack-${Version}-${BuildType}-vc${VC}-${Platform}.zip"
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

	$BaseUri = "${_PECL_DOWNLOADS_BASE_URI_}/${Name}/${Version}"
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

		Expand-Item7zip $DestinationPath "${InstallPath}"
	}
}

function SetupPhpVersionString {
	param (
		[Parameter(Mandatory=$true)] [String] $Pattern
	)

	$RemoteUrl   = "${_PHP_DOWNLOADS_BASE_URI_}/sha256sum.txt"
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

	Write-Debug "Unzipping ${Archive} to ${UnzipPath} ..."

	if (-not (Test-Path -Path $Destination -PathType Container)) {
		New-Item $Destination -ItemType Directory | Out-Null
	}

	$Result   = (& 7z x "$Archive" "-o$Destination" -aoa -bd -y -r)
	$ExitCode = $LASTEXITCODE

	If ($ExitCode -ne 0) {
		throw "An error occurred while unzipping '${Archive}' to '${Destination}'"
	}
}
