workspace(name = "megamind")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "f2dcd210c7095febe54b804bb1cd3a58fe8435a909db2ec04e31542631cf715c",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.31.0/rules_go-v0.31.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.31.0/rules_go-v0.31.0.zip",
    ],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "5982e5463f171da99e3bdaeff8c0f48283a7a5f396ec5282910b9e8a49c0dd7e",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.25.0/bazel-gazelle-v0.25.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.25.0/bazel-gazelle-v0.25.0.tar.gz",
    ],
)

http_archive(
    name = "com_google_protobuf",
    sha256 = "2d9084d3dd13b86ca2e811d2331f780eb86f6d7cb02b405426e3c80dcbfabf25",
    strip_prefix = "protobuf-3.21.1",
    urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.21.1.zip"],
)

git_repository(
    name = "vaticle_bazel_distribution",
    commit = "e61daa787bc77d97e36df944e7223821cab309ea",
    remote = "https://github.com/vaticle/bazel-distribution",
    shallow_since = "1655199056 +0100",
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("//:go_dependencies.bzl", "go_dependencies")

# gazelle:repository_macro go_dependencies.bzl%go_dependencies
go_dependencies()

go_rules_dependencies()

go_register_toolchains(version = "1.19")

gazelle_dependencies()

# gazelle:repository go_repository name=org_golang_x_xerrors importpath=golang.org/x/xerrors
