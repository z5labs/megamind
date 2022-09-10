# Contributing to Megamind

* [Getting Started](#getting-started)
* [Setting up the Development Environment](#setting-up-the-development-environment)
  * [Prerequisites](#prerequisites)
  * [Setup Megamind from source repo](#setup-megamind-from-source-repo)
  * [Build Megamind](#build-megamind)
  * [Testing](#testing)
* [Contributing](#contributing)
   * [Guidelines](#guidelines)
   * [Code style](#code-style)
   * [License Header](#license-header)
   * [Signed Commits](#signed-commits)

## Getting Started

Before beginning to work on Megamind, it is highly encouraged to familiarize yourself with
both [Kubernetes](https://kubernetes.io/) and [Knative](https://knative.dev).

## Setting up the Development Environment

### Prerequisites

- Install [bazelisk](https://github.com/bazelbuild/bazelisk) (this will then automatically install and manage [bazel](https://bazel.build/) for you)
  - Depending on how you install bazelisk, it may not automatically add an alias for bazel. In that case, please manually alias bazel to bazelisk e.g. `alias bazel=bazelisk`.
- Install [Docker](https://docs.docker.com/install/)
- Have access to a [Kubernetes](https://kubernetes.io/) cluster for testing.
  - Personally, recommend [minikube](https://minikube.sigs.k8s.io/docs/start/) for local development and testing.

### Setup Megamind from source repo

Simply clone the Megamind repository to anywhere you like on your development machine.

```bash
$ git clone https://github.com/z5labs/megamind.git
```

### Build Megamind

Megamind uses a monorepo structure for managing all of its various components.
[Bazel](https://bazel.build/) is then used to build and test this monorepo. To build all components of Megamind,
simply use the following command:

```bash
$ bazel build //...
```

### Testing

#### Unit tests

To run all unit tests in Megamind, use the following command:

```bash
$ bazel test //...
```

#### End-to-end tests

*TBD*

## Contributing

### Guidelines

- **Pull requests are welcome**, as long as you're willing to put in the effort to meet the guidelines.
- Aim for clear, well written, maintainable code.
- Simple and minimal approach to features, like Go.
- Refactoring existing code now for better performance, better readability or better testability wins over adding a new feature.
- Don't add a function to a module that you don't use right now, or doesn't clearly enable a planned functionality.
- Don't ship a half done feature, which would require significant alterations to work fully.
- Avoid [Technical debt](https://en.wikipedia.org/wiki/Technical_debt) like cancer.
- Leave the code cleaner than when you began.

### Code style
- We're following [Go Code Review](https://github.com/golang/go/wiki/CodeReviewComments).
- Use `go fmt` to format your code before committing.
- If you see *any code* which clearly violates the style guide, please fix it and send a pull request. No need to ask for permission.
- Avoid unnecessary vertical spaces. Use your judgment or follow the code review comments.
- Wrap your code and comments to 100 characters, unless doing so makes the code less legible.

### License Header

Every new source file must begin with a license header.

Megamind is licensed under the Apache 2.0 license:

    /*
     * Copyright 2022 Z5Labs and Contributors
     *
     * Licensed under the Apache License, Version 2.0 (the "License");
     * you may not use this file except in compliance with the License.
     * You may obtain a copy of the License at
     *
     *    http://www.apache.org/licenses/LICENSE-2.0
     *
     * Unless required by applicable law or agreed to in writing, software
     * distributed under the License is distributed on an "AS IS" BASIS,
     * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
     * See the License for the specific language governing permissions and
     * limitations under the License.
     */

### Signed Commits

Signed commits help in verifying the authenticity of the contributor. We use signed commits in Megamind, and we prefer it, though it's not compulsory to have signed commits. This is a recommended step for people who intend to contribute to Megamind on a regular basis.

Follow instructions to generate and setup GPG keys for signing code commits on this [Github Help page](https://help.github.com/articles/signing-commits-with-gpg/).