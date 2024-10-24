# Adding Dependencies

Add a dependency to a package.

In this guide we will cover methods of adding a dependency to a package, and adding one of its products as a target dependency. In order to get the most out of this guide, you will need to have an working knowledge of the Swift programming language, and have successfully installed SwiftPM (and Swift toolchain).

Package dependencies are described in the package's `Package.swift` (package swift) file. There are two types of package dependencies: git and path. Git package dependencies are the most common. They make use of SwiftPM's package resolution mechanism to automatically clone the source code from git, and calculate a version of that package that matches all of the constraints. Key pieces of information needed for git package dependencies is the git URL, and the version constraint (e.g. from version x.y.z to the next major version). With this information you can add a dependency to your package using the SwiftPM command-line like this:

```
swift package add-dependency https://github.com/some/swift-package.git --from 1.0.0
```

After you run this command you will see that it changes your package swift file. Once you become familiar with the structure of the this file you might make this change yourself. Here is an example of the dependency being added to your package description:

```
import PackageDescription

let package = Package(
    name: "my-tool",
    dependencies: [
        .package(url: "https://github.com/some/swift-package.git", from: "1.2.0"), // <------ Here is the new dependency
    ],
    targets: [
    ...
    ]
)
```

Path dependencies are added in a similar way and have a similar syntax. Only one piece of information is required to add those, which is the file path to the directory that contains another package swift file. There is no version range for these dependencies and SwiftPM cannot automatically fetch or resolve a version of them for you.

Adding a package depenency gives you access to all of its products from this package. For example, you will now be able to run executable products, such as command-line tools. Let's list the available executables with this new dependency:

```
swift package show-executables

my-tool
another-tool (swift-package)
```

You can see that this package has an executable called "my-tool" and also a new "another-tool" from the new package. Let's try getting the help for this tool by running it with the "--help" flag:

```
swift run another-tool --help

Help: another-tool - does xyz and abc
```

Package dependencies aren't usually added to access command-line tools like this. Typically, you want to add a module as a dependency to one of your targets so that you can import it in your source code. Here's how you can add the target dependency for one of the library products.

```
let package = Package(
    name: "my-tool",
    dependencies: [
        .package(url: "https://github.com/some/swift-package.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "my-tool",
            dependencies: [
                .product(name: "SomeLibrary", package: "swift-package"), // <-------- Here is the target dependency
            ]
        ),
    ]
)
```

Now that we've added the target dependency you can expect to be able to import it from your Swift code:

```
import SomeLibrary
```

There are other reasons why you might add a package dependency, such as plugins, but that is covered in more detail in other guides. In this guide we have covered different approaches to adding package dependencies, and how to consume those dependencies in your package. Along the way we covered the differences between git dependencies and path dependencies.
