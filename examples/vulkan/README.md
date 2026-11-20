# Headless Vulkan workflow

From the repository root on Linux x86-64, use a CMakeWorkflow release with the
`linux-clang` and `vcpkg` managed profiles. Put `CMakeWorkflow` in PATH or set
`CMAKEWORKFLOW` to its executable path. If both repositories are checked out
side by side, the launcher also checks the sibling CMakeWorkflow Release build.
The launcher needs Bash and jq.
The first install needs network access, glibc 2.31+, git, xz, and the host
utilities used by the selected vcpkg ports, including Python 3 and pkg-config.

```sh
bash examples/vulkan/reproduce.sh --plan
bash examples/vulkan/reproduce.sh --yes
```

`--plan` shows the pinned tool and dependency plans. `--yes` explicitly
approves setup, reuses verified tools and prepared dependencies when present,
and runs configure, build, and CTest. The separate example manifest pins
Vulkan headers, the loader and glslang through vcpkg. The build compiles
`verify.comp` with that glslang using the boilerplate shader helper.
CMake consumes the prepared dependency tree with manifest auto-install
disabled. The launcher writes the local dependency and environment-lock IDs
into a generated copy of `workflow.json`, so each checkout can use its own
path. The manifest, build and CMakeWorkflow run reports live under
`out/vulkan/`, or `CMAKEWORKFLOW_VULKAN_OUT` if set.

CTest first checks instance creation, compute-queue access and host-visible
storage-buffer allocation. It then dispatches the compiled SPIR-V and compares
the four values read back from Vulkan. Both checks work without a window.
A compatible Vulkan driver (ICD) must already be available to the current user.
To test with a software ICD such as Mesa Lavapipe, set `VK_DRIVER_FILES` to
the path of its installed JSON manifest when invoking the launcher.
[Khronos driver discovery](https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderDriverInterface.md)
