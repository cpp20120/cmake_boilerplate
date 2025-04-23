#!/bin/bash
if [ -x "$(command -v apt-get)" ]; then
    sudo apt-get update
    sudo apt-get install -y zsh build-essential neofetch git clang clang-tools mold clang-format gcc cmake ninja-build lld lldb valgrind gtest python3-pip doxygen neovim qt5-default qtbase5-dev qt6-base-dev qt6-base glfw glew libglm-dev glew-utils libglew-dev vulkan-tools vulkan-utils vulkan-loader glslang-dev spirv-tools libsfml-dev sfml
    git clone https://github.com/microsoft/vcpkg.git
    cd vcpkg
    ./bootstrap-vcpkg.sh
    ./vcpkg integrate install

elif [ -x "$(command -v dnf)" ]; then
    sudo dnf install -y dnf5
    sudo dnf5 install -y zsh @development-tools neofetch git vcpkg clang clang-tools-extra mold gcc cmake ninja-build lld lldb valgrind python3 python3-pip gtest doxygen neovim SFML SFML-devel qt5-qtbase-devel qt5-qtbase qt6-core qt6-qtbase qt6-qtbase-devel qt6-qtmultimedia glfw glm-devel glew vulkan-headers vulkan-loader vulkan-tools vulkan-volk-devel glslang spirv-tools spirv-llvm-translator
elif [ -x "$(command -v pacman)" ]; then
    sudo pacman -Syyu --noconfirm zsh base-devel neofetch neovim python python-pip lua git clang mold compiler-rt gcc cmake doxygen ninja make lld lldb valgrind gtest qt5-base qt5-multimedia qt5-quick3d qt6-tools qt6-quick3d qt6-multimedia glfw glew glm vulkan-extra-layers vulkan-extra-tools vulkan-headers vulkan-tools vulkan-validation-layers spirv-llvm-translator sfml volk vcpkg
elif [ -x "$(command -v brew)" ]; then
    brew install zsh xcodebuild neofetch neovim python3 git clang cmake doxygen ninja make lld lldb valgrind qt5 qt6 glfw glew glm vulkan-headers vulkan-loader vulkan-tools vulkan-extenstionlayer vulkan-validationlayer spirv-cross spirv-headers spirv-llvm-translator xcode-build-server googletest sfml vcpkg
else
    echo "Не удалось определить дистрибутив и установщик пакетов."
    exit 1
fi


