# `php-appveyor.psm1`

Install PHP and its tooling on AppVeyor CI.

`php-appveyor.psm1` is a small PowerShell script which provides functions to
install stable PHP versions, PHP DevPack, PHP SDK binary tools and doing some
usual provision tasks on the AppVeyor CI.

## Usage

Add the following to your `.appveyor.yml` file:

``` yaml
environment:
  # Use this matrix as an example
  matrix:

    # Specify matrix item for your app
    - PHP_VERSION: 7.3
      VC_VERSION: 15
      BUILD_TYPE: nts-Win32
      APPVEYOR_BUILD_WORKER_IMAGE: Visual Studio 2015

  # Specify required PHP SDK binary tools if you need SDK
  PHP_SDK_VERSION: 2.1.9

  PHP_AVM: https://raw.githubusercontent.com/sergeyklay/php-appveyor/master/php-appveyor.psm1

# Cache PHP and tooling
cache:
  # The C:\Downloads directory will be used as a storage for downloaded archives.
  # So you may want to cache it.
  - 'C:\Downloads -> .appveyor.yml'

# Specify required architecture.
# Supported architectures are ``x86`` and ``x64``
platform:
  - x64

install:
  # Download php-appveyor.psm1 module and invoke it to the current session
  - ps: (new-object Net.WebClient).DownloadString($Env:PHP_AVM) | iex

  - ps: InstallPhpSdk     $Env:PHP_SDK_VERSION $Env:VC_VERSION $Env:PLATFORM
  - ps: InstallPhp        $Env:PHP_VERSION $Env:BUILD_TYPE $Env:VC_VERSION $Env:PLATFORM
  - ps: InstallPhpDevPack $Env:PHP_VERSION $Env:BUILD_TYPE $Env:VC_VERSION $Env:PLATFORM

  # An example to install PECL extension
  - ps: >-
      InstallPeclExtension `
        -Name       psr `
        -Version    0.6.1 `
        -PhpVersion $Env:PHP_VERSION `
        -BuildType  $Env:BUILD_TYPE `
        -VC         $Env:VC_VERSION `
        -Platform   $Env:PLATFORM

  # An example to enable PHP extension
  - ps: >-
      EnablePhpExtension `
        -Name          my_ext `
        -PhpPath       C:\php `       # Optional
        -ExtPath       C:\my_ext `    # Optional
        -PrintableName "My Extension" # Optional

build_script:
  # Your code here
```

For more completely example see `.appveyor.yml` in this project.

## Real world projects with `php-appveyor.psm1`

- [Phalcon Framework][1] - High performance, full-stack PHP framework delivered
  as a C extension
- [PHP Zephir Parser][2] - The Zephir Parser delivered as a C extension for the
  PHP language

# License

`php-appveyor.psm1` is open source software licensed under the MIT License (MIT).
See the [LICENSE][3] file for more information.

[1]: https://github.com/phalcon/cphalcon
[2]: https://github.com/phalcon/php-zephir-parser
[3]: https://github.com/sergeyklay/php-appveyor/blob/master/LICENSE
