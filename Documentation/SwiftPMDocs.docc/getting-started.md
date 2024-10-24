# Getting Started

Get started with the Swift Package Manager (SwiftPM).

> Note: This is the documentation set for the Swift Package Manager. If you want to learn about the Swift programming language see the [Swift Tour](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/guidedtour/).

SwiftPM is available as part of the Swift toolchain. You can find installation instructions at [swift.org](https://www.swift.org/install/). SwiftPM requires git, so you will need to install that too.

Once you have a toolchain you can use SwiftPM to build your package:

```
swift build # Build this entire package
```

To test it:

```
swift test # Run all of the tests for this package
```

And run it:

```
swift run my-tool # Run the my-tool product declared in this package
```

But first, you need to have a package and its source code on your computer. There is a variety of packages cataloged at the [Swift Package Index](https://swiftpackageindex.com) that you can clone and try out. You can create your own package with one of the built-in templates:

```
mkdir my-tool; cd my-tool
swift package init --type tool
```

Now you can try the commands above on your new package. Gain more insights into your package using SwiftPM's built-in commands. This command lists your dependencies:

```
swift package show-dependencies
```

You can also ask SwiftPM for the list of executables that you can run:

```
swift package show-executables
```

Typically, packages have the following structure, but this can be customized:

```
Package.swift - Package description, written in Swift, including targets, dependencies, and products
Package.resolved - Versions and hashes of the dependencies that satisfy all of the version constraints
Sources/ - Production source code
Tests/ - Test source code
```
