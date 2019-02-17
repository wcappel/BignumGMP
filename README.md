# BignumGMP
A Swift wrapper around the GNU Multiple Precision Arithmetic Library ([libgmp](https://gmplib.org/)), largely compatible with the OpenSSL-based [Swift big number library](https://github.com/Bouke/Bignum).

## Prerequisites

This package makes [libgmp](https://gmplib.org/) available for Swift as a system library target. Therefore, prior to compiling, you need to have a copy of [libgmp](https://gmplib.org/) installed for your operating system.

### Linux

For [apt](https://wiki.debian.org/Apt)-based Linux distributions (such as [Debian](https://www.debian.org) or [Ubuntu](https://www.ubuntu.com)), you need to install the `libgmp-dev` package first:

	sudo apt install libgmp-dev

### macOS

Install `gmp` via [Homebrew](http://brew.sh/):

	brew install gmp

## Compiling and Testing

This library uses the [Swift Package Manager](https://swift.org/package-manager/). To build and test use:

	swift build  -Xcc -I/usr/local/include -Xlinker -L/usr/local/lib
	swift test   -Xcc -I/usr/local/include -Xlinker -L/usr/local/lib

### Using pkg-config

When you want to use `pkg-config` instead of manually adding the linker paths, look into `gmp.pc`. Make sure that the declared path fits your installation and make that file available to `pkg-config` by using for example _one of those commands_:

	export PKG_CONFIG_PATH=`pwd`:$PKG_CONFIG_PATH
	ln -s /path/to/gmp.pc /usr/local/lib/pkgconfig/gmp.pc

## Limitations

At the moment, only a small number of `BigInt` operations corresponding to the [libgmp](https://gmplib.org/) `mpz` type are implemented.
