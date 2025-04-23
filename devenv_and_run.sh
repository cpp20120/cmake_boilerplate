#!/bin/bash

# Exit on error and trace execution
set -e
set -o xtrace

# Function to install packages based on package manager
install_packages() {
    if [ -x "$(command -v apt-get)" ]; then
        echo "Detected apt-get, installing packages for Debian/Ubuntu..."
        sudo add-apt-repository -y contrib
        sudo add-apt-repository -y non-free
        sudo apt-get update -y
        sudo apt-get install -y zsh build-essential neofetch git clang clang-tools mold clang-format gcc cmake ninja-build lld lldb valgrind libgtest-dev lcov gcovr python3-pip doxygen neovim qtbase5-dev qt6-base-dev libglfw3 libglfw3-dev glew-utils libglew-dev libglm-dev libvulkan1 vulkan-validationlayers glslang-dev spirv-tools spirv-cross libsfml-dev ripgrep lazygit python3 nodejs npm fd-find unzip rustc cargo
        git clone https://github.com/microsoft/vcpkg.git
        cd vcpkg
        ./bootstrap-vcpkg.sh
        ./vcpkg integrate install
        cd ..
    elif [ -x "$(command -v dnf)" ]; then
        echo "Detected dnf, installing packages for Fedora/RHEL..."
        sudo dnf install -y dnf5
        sudo dnf5 install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
        sudo dnf5 install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
        sudo dnf5 install -y zsh @development-tools neofetch git clang clang-tools-extra compiler-rt mold gcc cmake ninja-build lld lldb valgrind lcov gcovr python3 python3-pip gtest doxygen neovim SFML SFML-devel qt5-qtbase-devel qt5-qtbase qt6-core qt6-qtbase qt6-qtbase-devel qt6-qtmultimedia glfw glm-devel glew vulkan-headers vulkan-loader vulkan-tools vulkan-volk-devel glslang spirv-tools spirv-llvm-translator ripgrep lazygit bottom nodejs npm fd-find unzip rustc cargo
    elif [ -x "$(command -v pacman)" ]; then
        echo "Detected pacman, installing packages for Arch/Manjaro..."
        sudo pacman -Syyu --noconfirm zsh base-devel neofetch neovim python python-pip lua git clang mold compiler-rt gcc cmake doxygen ninja make lld lldb valgrind gcov gcovr lcov gtest qt5-base qt5-multimedia qt5-quick3d qt6-tools qt6-quick3d qt6-multimedia glfw glew glm vulkan-extra-layers vulkan-extra-tools vulkan-headers vulkan-tools vulkan-validation-layers spirv-llvm-translator sfml ripgrep lazygit bottom nodejs npm fd unzip rustup
    elif [ -x "$(command -v brew)" ]; then
        echo "Detected brew, installing packages for macOS..."
        brew install zsh xcodebuild neofetch neovim python3 git clang cmake doxygen ninja make lld lldb valgrind lcov gcovr qt5 qt6 glfw glew glm vulkan-headers vulkan-loader vulkan-tools vulkan-extenstionlayer vulkan-validationlayer spirv-cross spirv-headers spirv-llvm-translator xcode-build-server googletest sfml ripgrep lazygit bottom node npm fd unzip rustup
    else
        echo "Failed to detect package manager. Please install packages manually."
        exit 1
    fi
}

# Function to setup Rust and rust-analyzer
setup_rust() {
    echo "Setting up Rust toolchain..."
    if ! command -v rustup &> /dev/null; then
        if [ -x "$(command -v pacman)" ] || [ -x "$(command -v brew)" ]; then
            # rustup should be installed via package manager on Arch/macOS
            echo "rustup should have been installed via package manager but wasn't found"
            exit 1
        else
            # Install rustup on other systems
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source $HOME/.cargo/env
        fi
    fi

    # Add rustup to PATH if it's not already there
    if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" >> ~/.zshrc
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    # Install stable toolchain and components
    rustup toolchain install stable
    rustup default stable
    rustup component add rust-src rust-analysis rustfmt clippy

    # Install rust-analyzer
    if ! command -v rust-analyzer &> /dev/null; then
        mkdir -p ~/.local/bin
        if [ -x "$(command -v pacman)" ]; then
            sudo pacman -S --noconfirm rust-analyzer
        elif [ -x "$(command -v brew)" ]; then
            brew install rust-analyzer
        else
            # Install from GitHub release
            latest_url=$(curl -s https://api.github.com/repos/rust-lang/rust-analyzer/releases/latest | grep -o 'https://.*rust-analyzer-.*-x86_64-unknown-linux-gnu.gz' | head -n 1)
            if [ -n "$latest_url" ]; then
                curl -L $latest_url | gunzip -c - > ~/.local/bin/rust-analyzer
                chmod +x ~/.local/bin/rust-analyzer
            else
                echo "Failed to find rust-analyzer download URL"
                exit 1
            fi
        fi
    fi
}

# Function to setup clangd
setup_clangd() {
    echo "Setting up clangd..."
    if ! command -v clangd &> /dev/null; then
        if [ -x "$(command -v pacman)" ]; then
            sudo pacman -S --noconfirm clang-tools-extra
        elif [ -x "$(command -v brew)" ]; then
            brew install llvm
            echo "export PATH=\"/usr/local/opt/llvm/bin:\$PATH\"" >> ~/.zshrc
            export PATH="/usr/local/opt/llvm/bin:$PATH"
        elif [ -x "$(command -v apt-get)" ]; then
            sudo apt-get install -y clangd
            sudo update-alternatives --install /usr/bin/clangd clangd 100
        elif [ -x "$(command -v dnf)" ]; then
            sudo dnf install -y clang-tools-extra
        else
            # Install from LLVM official releases
            echo "Installing clangd from LLVM official release..."
            latest_version=$(curl -s https://api.github.com/repos/llvm/llvm-project/releases/latest | grep -o 'tag/.*' | cut -d'/' -f2)
            if [ -n "$latest_version" ]; then
                wget https://github.com/llvm/llvm-project/releases/download/$latest_version/clangd-linux-$latest_version.zip
                unzip clangd-linux-$latest_version.zip
                sudo mv clangd_*/bin/clangd /usr/local/bin/
                rm -rf clangd_*
            else
                echo "Failed to find clangd download URL"
                exit 1
            fi
        fi
    fi
}



# Function to setup Zsh
setup_zsh() {
    echo "Setting up Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Install plugins
    if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    fi
    
    if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    fi
    
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    fi

    # Create .zshrc
    if [ ! -f ~/.zshrc ]; then
        cat > ~/.zshrc << 'EOL'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
    git
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
)

alias zshconfig="nvim ~/.zshrc"
alias src="source ~/.zshrc"
alias vim="nvim"
alias nv="nvim"

source $ZSH/oh-my-zsh.sh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Add local binaries to PATH
export PATH=$HOME/.local/bin:$PATH
EOL
    fi

    # Change default shell to Zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s $(which zsh) $(whoami)
    fi

    # Source the new .zshrc
    source ~/.zshrc
}

# Function to setup Neovim with lazy.nvim
setup_neovim() {
    echo "Setting up Neovim with lazy.nvim..."
    
    # Create nvim config directory
    mkdir -p ~/.config/nvim
    
    # Install lazy.nvim
    if [ ! -d ~/.local/share/nvim/lazy ]; then
        git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git ~/.local/share/nvim/lazy/lazy.nvim
    fi

    # Install Luanvim configuration
    if [ ! -d ~/.config/nvim/lua ]; then
        git clone https://gitlab.com/cppshizoid/dotfiles.git ~/dotfiles_temp
        cp -r ~/dotfiles_temp/luanvim/* ~/.config/nvim/
        rm -rf ~/dotfiles_temp
        
        # Ensure the lazy.nvim setup is properly referenced
        if [ ! -f ~/.config/nvim/init.lua ]; then
            cat > ~/.config/nvim/init.lua << 'EOL'
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

-- Load the rest of your configuration
require("config")
EOL
        fi
    fi
    
    # Install language servers and tools
    if command -v npm &> /dev/null; then
        npm install -g typescript typescript-language-server vscode-langservers-extracted pyright
    fi
    
    if command -v pip3 &> /dev/null; then
        pip3 install python-lsp-server
    fi
    nvim --headless -c 'MasonInstall clangd rust-analyzer' -c 'qall'
}

# Function to install Nerd Fonts
install_nerd_fonts() {
    echo "Installing Nerd Fonts..."
    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts
    
    if [ ! -f "Droid Sans Mono Nerd Font Complete.otf" ]; then
        curl -fLo "Droid Sans Mono Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
        fc-cache -fv
    fi
    
    cd -
}

# Main installation process
main() {
    install_packages
    setup_zsh
    install_nerd_fonts
    setup_rust
    setup_clangd
    setup_neovim
    
    echo ""
    echo "============================================"
    echo "Installation complete!"
    echo "Please restart your terminal or run:"
    echo "  source ~/.zshrc"
    echo ""
    echo "For Neovim, the first launch will automatically"
    echo "install plugins via lazy.nvim"
    echo ""
    echo "Installed language servers:"
    echo "  - clangd: $(which clangd)"
    echo "  - rust-analyzer: $(which rust-analyzer)"
    echo "============================================"
}

main