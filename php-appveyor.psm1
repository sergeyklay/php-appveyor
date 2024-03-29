# This file is part of the php-appveyor.psm1 project.
#
# (c) Serghei Iakovlev <sadhooklay@gmail.com>
#
# For the full copyright and license information, please view
# the LICENSE file that was distributed with this source code.

# $ErrorActionPreference = "Stop"

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

	if (-not (Test-Path "${InstallPath}\bin\php\php.exe")) {
		if (-not (Test-Path $Archive)) {
			DownloadFile -RemoteUrl $RemoteUrl -Destination $Archive
		}

		$UnzipPath = "${Env:Temp}\php-sdk-binary-tools-${FileName}"
		if (-not (Test-Path "${UnzipPath}")) {
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
	$FullVersion = SetupPhpVersionString -Pattern $Version

	Write-Debug "Install PHP v${FullVersion}"

	$ReleasesPart = "releases"
	if ([System.Convert]::ToDecimal($Version) -lt 7.2) {
		$ReleasesPart = "releases/archives"
	}

	# Workaround for different prefix for compiler version
	# For all PHP 7.x - prefix was `vc`
	# From PHP 8.0 - prefix changed to `vs`
	$CompilerVersion = "vc${VC}"
	if ([System.Convert]::ToDecimal($Version) -ge 8.0) {
		$CompilerVersion = "vs${VC}"
	}

	$RemoteUrl = "http://windows.php.net/downloads/{0}/php-{1}-{2}-{3}-{4}.zip" -f
	$ReleasesPart, $FullVersion, $BuildType, $CompilerVersion, $Platform

	$Archive   = "C:\Downloads\php-${FullVersion}-${BuildType}-${CompilerVersion}-${Platform}.zip"

	if (-not (Test-Path "${InstallPath}\php.exe")) {
		if (-not (Test-Path $Archive)) {
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

	$ReleasesPart = "releases"
	if ([System.Convert]::ToDecimal($PhpVersion) -lt 7.2) {
		$ReleasesPart = "releases/archives"
	}

	# Workaround for different prefix for compiler version
	# For all PHP 7.x - prefix was `vc`
	# From PHP 8.0 - prefix changed to `vs`
	$CompilerVersion = "vc${VC}"
	if ([System.Convert]::ToDecimal($PhpVersion) -ge 8.0) {
		$CompilerVersion = "vs${VC}"
	}

	$RemoteUrl = "http://windows.php.net/downloads/{0}/php-devel-pack-{1}-{2}-{3}-{4}.zip" -f
	$ReleasesPart, $Version, $BuildType, $CompilerVersion, $Platform

	$Archive   = "C:\Downloads\php-devel-pack-${Version}-${BuildType}-${CompilerVersion}-${Platform}.zip"

	if (-not (Test-Path "${InstallPath}\phpize.bat")) {
		if (-not (Test-Path $Archive)) {
			DownloadFile $RemoteUrl $Archive
		}

		$UnzipPath = "${Env:Temp}\php-${Version}-devel-${CompilerVersion}-${Platform}"
		if (-not (Test-Path "${UnzipPath}\phpize.bat")) {
			Expand-Item7zip $Archive $Env:Temp
		}

		if (Test-Path "${InstallPath}") {
			Move-Item -Path "${UnzipPath}\*" -Destination $InstallPath
		} else {
			Move-Item -Path $UnzipPath -Destination $InstallPath
		}
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
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = "C:\php\ext",
		[Parameter(Mandatory=$false)] [System.Boolean] $Enable = $false
	)

	SetupPrerequisites

	# Workaround for PHP 8 PSR extension
	# Because we don't have special archive for php 8
	# we must to use latest PSR release for PHP 7.4 :)
	# Example:
	# https://windows.php.net/downloads/pecl/releases/psr/1.0.1/php_psr-1.0.1-7.4-ts-vc15-x86.zip
	$PackageVersion = $Version
	$CompatiblePhpVersion = $PhpVersion
	if (([System.Convert]::ToDecimal($PhpVersion) -ge 8.0) -and ($Name -Match "psr")) {
		$PackageVersion = "1.0.1"
		$CompatiblePhpVersion = "7.4"
		$VC = "15"
	}

	$BaseUri = "https://windows.php.net/downloads/pecl/releases/${Name}/${PackageVersion}"
	$LocalPart = "php_${Name}-${PackageVersion}-${CompatiblePhpVersion}"

	if ($BuildType -Match "nts-Win32") {
		$TS = "nts"
	} else {
		$TS = "ts"
	}

	# A workaround for php 8.0
	$CompilerVersion = "vc${VC}"
	if ([System.Convert]::ToDecimal($PhpVersion) -ge 8.0) {
		$CompilerVersion = "vs${VC}"
	}

	$RemoteUrl = "${BaseUri}/${LocalPart}-${TS}-${CompilerVersion}-${Platform}.zip"
	$DestinationPath = "C:\Downloads\${LocalPart}-${TS}-${CompilerVersion}-${Platform}.zip"

	if (-not (Test-Path "${InstallPath}\php_${Name}.dll")) {
		if (-not (Test-Path $DestinationPath)) {
			DownloadFile $RemoteUrl $DestinationPath
		}

		Expand-Item7zip $DestinationPath $InstallPath
	}

	if ($Enable) {
		EnablePhpExtension -Name psr
	}
}

function InstallZephirParser {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Version,
		[Parameter(Mandatory=$true)]  [System.String] $BuildId,
		[Parameter(Mandatory=$true)]  [System.String] $PhpVersion,
		[Parameter(Mandatory=$true)]  [System.String] $BuildType,
		[Parameter(Mandatory=$true)]  [System.String] $VC,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = "C:\php\ext",
		[Parameter(Mandatory=$false)] [System.Boolean] $Enable = $false
	)

	SetupPrerequisites

	$BaseUri = "https://github.com/phalcon/php-zephir-parser/releases/download/v${Version}"
	$LocalPart = "zephir_parser_${Platform}_vc${VC}_php${PhpVersion}"

	if ($BuildType -Match "nts-Win32") {
		$TS = "-nts"
	} else {
		$TS = ""
	}

	$RemoteUrl = "${BaseUri}/${LocalPart}${TS}_${Version}-${BuildId}.zip"
	$DestinationPath = "C:\Downloads\${LocalPart}${TS}_${Version}-${BuildId}.zip"

	if (-not (Test-Path "${InstallPath}\php_zephir_parser.dll")) {
		if (-not (Test-Path $DestinationPath)) {
			DownloadFile $RemoteUrl $DestinationPath
		}

		Expand-Item7zip $DestinationPath "${InstallPath}"
	}

	if ($Enable) {
		EnablePhpExtension `
			-Name zephir_parser `
			-PrintableName "Zephir Parser"
	}
}

function InstallComposer {
	param (
		[Parameter(Mandatory=$false)] [System.String] $PhpInstallPath = 'C:\php',
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = '.'
	)

	$InstallPath = Resolve-Path $InstallPath

	$ComposerBatch = "${InstallPath}\composer.bat"
	$ComposerPhar  = "${InstallPath}\composer.phar"

	if (-not (Test-Path -Path $ComposerPhar)) {
		EnablePhpExtension -Name openssl
		Invoke-Expression "${PhpInstallPath}\php.exe -r `"copy('https://getcomposer.org/installer', 'composer-setup.php');`""
		Invoke-Expression "${PhpInstallPath}\php.exe composer-setup.php"
		Invoke-Expression "${PhpInstallPath}\php.exe -r `"unlink('composer-setup.php');`""
		#DownloadFile "https://getcomposer.org/composer.phar" "${ComposerPhar}"

		Write-Output '@echo off' | Out-File -Encoding "ASCII" $ComposerBatch
		Write-Output "${PhpInstallPath}\php.exe `"${ComposerPhar}`" %*" | Out-File -Encoding "ASCII" -Append $ComposerBatch
	}
}

function InstallZephir {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Version,
		[Parameter(Mandatory=$false)] [System.String] $PhpInstallPath = 'C:\php',
		[Parameter(Mandatory=$false)] [System.String] $InstallPath = '.'
	)

	$InstallPath = Resolve-Path $InstallPath

	$ZephirPhar  = "${InstallPath}\zephir.phar"
	$ZephirBatch = "${InstallPath}\zephir.bat"

	if (-not (Test-Path -Path $ZephirPhar)) {
		$BaseUri = "https://github.com/phalcon/zephir/releases/download"
		$RemoteUrl = "${BaseUri}/${Version}/zephir.phar"

		DownloadFile "${RemoteUrl}" "${ZephirPhar}"

		Write-Output '@echo off' | Out-File -Encoding "ASCII" $ZephirBatch
		Write-Output "${PhpInstallPath}\php.exe `"${ZephirPhar}`" %*" | Out-File -Encoding "ASCII" -Append $ZephirBatch
	}
}

function EnablePhpExtension {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Name,
		[Parameter(Mandatory=$false)] [System.String] $PhpInstallPath = 'C:\php',
		[Parameter(Mandatory=$false)] [System.String] $ExtPath = 'C:\php\ext',
		[Parameter(Mandatory=$false)] [System.String] $PrintableName = ''
	)

	$FullyQualifiedExtensionPath = "${ExtPath}\php_${Name}.dll"

	$IniFile = "${PhpInstallPath}\php.ini"
	$PhpExe  = "${PhpInstallPath}\php.exe"

	if (-not (Test-Path $IniFile)) {
		throw "Unable to locate ${IniFile}"
	}

	if (-not (Test-Path "${ExtPath}")) {
		throw "Unable to locate ${ExtPath} direcory"
	}

	Write-Debug "Add `"extension = ${FullyQualifiedExtensionPath}`" to the ${IniFile}"
	Write-Output "extension = ${FullyQualifiedExtensionPath}"  | Out-File -Encoding "ASCII" -Append $IniFile

	if (Test-Path -Path "${PhpExe}") {
		if ($PrintableName) {
			Write-Debug "Minimal load test using command: ${PhpExe} --ri `"${PrintableName}`""
			$Result = (& "${PhpExe}" --ri "${PrintableName}")
		} else {
			Write-Debug "Minimal load test using command: ${PhpExe} --ri ${Name}"
			$Result = (& "${PhpExe}" --ri "${Name}")
		}

		$ExitCode = $LASTEXITCODE
		if ($ExitCode -ne 0) {
			throw "An error occurred while enabling ${Name} at ${IniFile}. ${Result}"
		}
	}
}

function EnableZendExtension {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $Name,
		[Parameter(Mandatory=$false)] [System.String] $PhpInstallPath = 'C:\php',
		[Parameter(Mandatory=$false)] [System.String] $ExtPath = 'C:\php\ext',
		[Parameter(Mandatory=$false)] [System.String] $PrintableName = ''
	)

	$FullyQualifiedExtensionPath = "${ExtPath}\php_${Name}.dll"

	$IniFile = "${PhpInstallPath}\php.ini"
	$PhpExe  = "${PhpInstallPath}\php.exe"

	if (-not (Test-Path $IniFile)) {
		throw "Unable to locate ${IniFile}"
	}

	if (-not (Test-Path "${ExtPath}")) {
		throw "Unable to locate ${ExtPath} direcory"
	}

	Write-Debug "Add `"zend_extension = ${FullyQualifiedExtensionPath}`" to the ${IniFile}"
	Write-Output "zend_extension = ${FullyQualifiedExtensionPath}"  | Out-File -Encoding "ASCII" -Append $IniFile

	if (Test-Path -Path "${PhpExe}") {
		if ($PrintableName) {
			Write-Debug "Minimal load test using command: ${PhpExe} --ri `"${PrintableName}`""
			$Result = (& "${PhpExe}" --ri "${PrintableName}")
		} else {
			Write-Debug "Minimal load test using command: ${PhpExe} --ri ${Name}"
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

	if (-not (Test-Path $IniFile)) {
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
		[Parameter(Mandatory=$false)] [System.String] $ReleaseFile,
		[Parameter(Mandatory=$false)] [System.String] $ReleaseDirectory,
		[Parameter(Mandatory=$false)] [System.String] $BasePath
	)

	$Destination = "${BasePath}\${ReleaseDirectory}"

	if (-not (Test-Path $Destination)) {
		New-Item -ItemType Directory -Force -Path "${Destination}" | Out-Null
	}

	$ReleaseFile = "${Destination}\${ReleaseFile}"
	$ReleaseDate = Get-Date -Format o

	$Image = $Env:APPVEYOR_BUILD_WORKER_IMAGE
	$Version = $Env:APPVEYOR_BUILD_VERSION
	$Commit = $Env:APPVEYOR_REPO_COMMIT
	$CommitDate = $Env:APPVEYOR_REPO_COMMIT_TIMESTAMP

	Write-Output "Release date: ${ReleaseDate}"      | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Release version: ${Version}"       | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Git commit: ${Commit}"             | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Commit date: ${CommitDate}"        | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Build type: ${BuildType}"          | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Platform: ${Platform}"             | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Target PHP version: ${PhpVersion}" | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
	Write-Output "Build worker image: ${Image}"      | Out-File -Encoding "ASCII" -Append "${ReleaseFile}"
}

function PrepareReleasePackage {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $PhpVersion,
		[Parameter(Mandatory=$true)]  [System.String] $BuildType,
		[Parameter(Mandatory=$true)]  [System.String] $Platform,
		[Parameter(Mandatory=$false)] [System.String] $ZipballName = '',
		[Parameter(Mandatory=$false)] [System.String[]] $ReleaseFiles = @(),
		[Parameter(Mandatory=$false)] [System.String] $ReleaseFile = 'RELEASE.txt',
		[Parameter(Mandatory=$false)] [System.Boolean] $ConverMdToHtml = $false,
		[Parameter(Mandatory=$false)] [System.String] $BasePath = '.'
	)

	$BasePath = Resolve-Path $BasePath
	$ReleaseDirectory = "${Env:APPVEYOR_PROJECT_NAME}-${Env:APPVEYOR_BUILD_ID}-${Env:APPVEYOR_JOB_ID}-${Env:APPVEYOR_JOB_NUMBER}"

	PrepareReleaseNote `
		-PhpVersion       $PhpVersion `
		-BuildType        $BuildType `
		-Platform         $Platform `
		-ReleaseFile      $ReleaseFile `
		-ReleaseDirectory $ReleaseDirectory `
		-BasePath         $BasePath

	$ReleaseDestination = "${BasePath}\${ReleaseDirectory}"

	$CurrentPath = Resolve-Path '.'

	# FIXME: pandoc installer is broken
	# if ($ConverMdToHtml) {
	# 	InstallReleaseDependencies
	# 	FormatReleaseFiles -ReleaseDirectory $ReleaseDirectory
	# }

	if ($ReleaseFiles.count -gt 0) {
		foreach ($File in $ReleaseFiles) {
			Copy-Item "${File}" "${ReleaseDestination}"
			Write-Debug "Copy ${File} to ${ReleaseDestination}"
		}
	}

	if (!$ZipballName) {
		if (!$Env:RELEASE_ZIPBALL) {
			throw "Required parameter `"ZipballName`" is missing"
		} else {
			$ZipballName = $Env:RELEASE_ZIPBALL;
		}
	}

	Ensure7ZipIsInstalled

	Set-Location "${ReleaseDestination}"
	$Output = (& 7z a "${ZipballName}.zip" *)
	$ExitCode = $LASTEXITCODE

	$DirectoryContents = Get-ChildItem -Path "${ReleaseDestination}"
	Write-Debug ($DirectoryContents | Out-String)

	if ($ExitCode -ne 0) {
		Set-Location "${CurrentPath}"
		throw "An error occurred while creating release zippbal: `"${ZipballName}`". ${Output}"
	}

	Move-Item "${ZipballName}.zip" -Destination "${BasePath}"
	Set-Location "${CurrentPath}"
}

function FormatReleaseFiles {
	param (
		[Parameter(Mandatory=$true)]  [System.String] $ReleaseDirectory,
		[Parameter(Mandatory=$false)] [System.String] $BasePath = '.'
	)

	EnsurePandocIsInstalled

	$CurrentPath = (Get-Item -Path ".\" -Verbose).FullName

	$BasePath = Resolve-Path $BasePath
	Set-Location "${BasePath}"

	Get-ChildItem (Get-Item -Path ".\" -Verbose).FullName *.md |
	ForEach-Object{
		$BaseName = $_.BaseName
		pandoc -f markdown -t html5 "${BaseName}.md" > "${BasePath}\${ReleaseDirectory}\${BaseName}.html"
	}

	Set-Location "${CurrentPath}"
}

function SetupPhpVersionString {
	param (
		[Parameter(Mandatory=$true)] [String] $Pattern
	)

	$RemoteUrl   = 'http://windows.php.net/downloads/releases/sha256sum.txt'
	$Destination = "${Env:Temp}\php-sha256sum.txt"

	if (-not (Test-Path $Destination)) {
		DownloadFile $RemoteUrl $Destination
	}

	$VersionString = Get-Content $Destination | Where-Object {
		$_ -match "php-($Pattern\.\d+(?:-\d+)?)-src"
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

function InstallReleaseDependencies {
	EnsureChocolateyIsInstalled
	$Output = (choco install -y --no-progress pandoc)
	$ExitCode = $LASTEXITCODE

	if ($ExitCode -ne 0) {
		throw "An error occurred while installing pandoc. ${Output}"
	}
}

function EnsureChocolateyIsInstalled {
	if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
		$ChocolateyInstallationDirectory = "${Env:ChocolateyInstall}\bin"

		if (-not (Test-Path "$ChocolateyInstallationDirectory")) {
			throw "The choco is needed to use this module"
		}

		$Env:Path += ";$ChocolateyInstallationDirectory"
	}
}

function EnsurePandocIsInstalled {
	if (-not (Get-Command "pandoc" -ErrorAction SilentlyContinue)) {
		$PandocInstallationDirectory = "${Env:ChocolateyInstall}\bin"

		if (-not (Test-Path "$PandocInstallationDirectory")) {
			throw "The pandoc is needed to use this module"
		}

		$Env:Path += ";$PandocInstallationDirectory"
	}

	$Output = (& "pandoc" -v)
	$ExitCode = $LASTEXITCODE

	if ($ExitCode -ne 0) {
		throw "An error occurred while self testing pandoc. ${Output}"
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

	Write-Debug "Downloading: '${RemoteUrl}' => '${Destination}' ..."

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

	$Output = (& 7z x "$Archive" "-o$Destination" -aoa -bd -y -r)
	$ExitCode = $LASTEXITCODE

	if ($ExitCode -ne 0) {
		throw "An error occurred while unzipping '${Archive}' to '${Destination}'. ${Output}"
	}
}
