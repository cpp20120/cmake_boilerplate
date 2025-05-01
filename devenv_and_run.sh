#!/bin/bash

# Exit on error and trace execution
set -e
set -o xtrace

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to prompt with yes/no
prompt_yes_no() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to select multiple options
select_multiple() {
    local prompt="$1"
    shift
    local options=("$@")
    local selections=()

    echo -e "${YELLOW}$prompt${NC}"
    for i in "${!options[@]}"; do
        if prompt_yes_no "  ${options[$i]}"; then
            selections+=("${options[$i]}")
        fi
    done
    echo "${selections[@]}"
}

# Function to install packages based on package manager
install_packages() {
    echo -e "${GREEN}Detecting package manager and installing base packages...${NC}"
    
    if [ -x "$(command -v apt-get)" ]; then
        echo "Detected apt-get, installing packages for Debian/Ubuntu..."
        sudo add-apt-repository -y contrib
        sudo add-apt-repository -y non-free
        sudo apt-get update -y
        sudo apt-get install -y zsh build-essential neofetch git clang clang-tools mold clang-format gcc cmake ninja-build lld lldb valgrind graphviz libgtest-dev lcov gcovr python3-pip doxygen neovim fd-find qtbase5-dev qt6-base-dev libglfw3 libglfw3-dev glew-utils libglew-dev libglm-dev libvulkan1 vulkan-validationlayers glslang-dev spirv-tools spirv-cross libsfml-dev ripgrep lazygit python3 nodejs npm fd-find unzip
        # Install cmake-format
        sudo pip3 install cmake-format
    elif [ -x "$(command -v dnf)" ]; then
        echo "Detected dnf, installing packages for Fedora/RHEL..."
        sudo dnf install -y dnf5
        sudo dnf5 install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
        sudo dnf5 install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
        sudo dnf5 install -y zsh @development-tools neofetch git clang clang-tools-extra compiler-rt mold gcc cmake ninja-build lld lldb valgrind graphviz lcov gcovr python3 python3-pip gtest doxygen neovim fd-find SFML SFML-devel qt5-qtbase-devel qt5-qtbase qt6-core qt6-qtbase qt6-qtbase-devel qt6-qtmultimedia glfw glm-devel glew vulkan-headers vulkan-loader vulkan-tools vulkan-volk-devel glslang spirv-tools spirv-llvm-translator ripgrep lazygit bottom nodejs npm fd-find unzip
        # Install cmake-format
        sudo pip3 install cmake-format
    elif [ -x "$(command -v pacman)" ]; then
        echo "Detected pacman, installing packages for Arch/Manjaro..."
        sudo pacman -Syyu --noconfirm zsh base-devel neofetch neovim python python-pip lua git clang mold compiler-rt gcc cmake doxygen ninja make lld lldb valgrind graphviz gcov gcovr lcov gtest fd qt5-base qt5-multimedia qt5-quick3d qt6-tools qt6-quick3d qt6-multimedia glfw glew glm vulkan-extra-layers vulkan-extra-tools vulkan-headers vulkan-tools vulkan-validation-layers spirv-llvm-translator sfml ripgrep lazygit bottom nodejs npm fd unzip
        # Install cmake-format
        sudo pip install cmake-format
    elif [ -x "$(command -v brew)" ]; then
        echo "Detected brew, installing packages for macOS..."
        brew install zsh xcodebuild neofetch neovim python3 fd git clang cmake doxygen ninja make lld lldb valgrind graphviz lcov gcovr qt5 qt6 glfw glew glm vulkan-headers vulkan-loader vulkan-tools vulkan-extenstionlayer vulkan-validationlayer spirv-cross spirv-headers spirv-llvm-translator xcode-build-server googletest sfml ripgrep lazygit bottom node npm fd unzip
        # Install cmake-format
        pip3 install cmake-format
    else
        echo -e "${RED}Failed to detect package manager. Please install packages manually.${NC}"
        exit 1
    fi
}

# Function to setup Zsh
setup_zsh() {
    echo -e "${GREEN}Setting up Zsh...${NC}"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Install plugins
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    # Create .zshrc
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

    # Change default shell to Zsh
    chsh -s $(which zsh) $(whoami)
    source ~/.zshrc
}

# Function to setup Neovim with selected LSP servers
setup_neovim() {
    local lsp_servers=("$@")
    
    echo -e "${GREEN}Setting up Neovim with selected LSP servers...${NC}"
    
    # Create nvim config directory
    mkdir -p ~/.config/nvim/lua
    
    # Install lazy.nvim
    git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git ~/.local/share/nvim/lazy/lazy.nvim

    # Generate LSP configuration based on selections
    local lsp_config=""
    for server in "${lsp_servers[@]}"; do
        lsp_config+="\"$server\", "
    done

    # Create init.lua with selected LSP servers
    cat > ~/.config/nvim/init.lua << EOL
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

-- Set up LSP configuration
require("lazy").setup({
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { ${lsp_config} },
        automatic_installation = true,
      })

      local lspconfig = require("lspconfig")
EOL

    # Add specific LSP configurations
    for server in "${lsp_servers[@]}"; do
        case $server in
            "clangd")
                echo "      lspconfig.clangd.setup({})" >> ~/.config/nvim/init.lua
                ;;
            "rust_analyzer")
                echo "      lspconfig.rust_analyzer.setup({})" >> ~/.config/nvim/init.lua
                ;;
            "pyright")
                echo "      lspconfig.pyright.setup({})" >> ~/.config/nvim/init.lua
                ;;
            "tsserver")
                echo "      lspconfig.tsserver.setup({})" >> ~/.config/nvim/init.lua
                ;;
            "gopls")
                echo "      lspconfig.gopls.setup({})" >> ~/.config/nvim/init.lua
                ;;
            "lua_ls")
                echo "      lspconfig.lua_ls.setup({})" >> ~/.config/nvim/init.lua
                ;;
        esac
    done

    # Add the rest of the configuration
    cat >> ~/.config/nvim/init.lua << 'EOL'
    end
  },
  -- Add cmake-format support
  {
    "salkin-mada/cmake-format.nvim",
    config = function()
      require("cmake-format").setup({
        cmake_format = {
          style = "file",
        }
      })
    end
  }
})

-- Key mappings for LSP
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufopts = { noremap=true, silent=true, buffer=args.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
    vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  end
})
EOL

    # Install LSP servers through Neovim
    if [ ${#lsp_servers[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing selected LSP servers...${NC}"
        nvim --headless -c "MasonInstall ${lsp_servers[@]}" -c 'qall' 2>/dev/null
    fi
}

# Function to install Nerd Fonts
install_nerd_fonts() {
    if prompt_yes_no "Install Nerd Fonts (recommended for proper icons in terminal and Neovim)?"; then
        echo -e "${GREEN}Installing Nerd Fonts...${NC}"
        mkdir -p ~/.local/share/fonts
        cd ~/.local/share/fonts
        curl -fLo "Droid Sans Mono Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
        fc-cache -fv
        cd -
    fi
}

# Main installation process
main() {
    echo -e "${GREEN}Starting development environment setup...${NC}"
    
    # Install base packages
    install_packages
    
    # Setup Zsh
    if prompt_yes_no "Set up Zsh with Oh My Zsh and Powerlevel10k?"; then
        setup_zsh
    fi
    
    # Install Nerd Fonts
    install_nerd_fonts
    
    # Neovim setup
    if prompt_yes_no "Set up Neovim with LSP support?"; then
        # Select LSP servers to install
        echo -e "${YELLOW}Select which language servers to install:${NC}"
        lsp_choices=("clangd (C/C++)" "rust_analyzer (Rust)" "pyright (Python)" "tsserver (TypeScript/JavaScript)" "gopls (Go)" "lua_ls (Lua)")
        selected_lsp=($(select_multiple "Choose LSP servers to install:" "${lsp_choices[@]}"))
        
        # Map friendly names to actual server names
        declare -A lsp_map=(
            ["clangd (C/C++)"]="clangd"
            ["rust_analyzer (Rust)"]="rust_analyzer"
            ["pyright (Python)"]="pyright"
            ["tsserver (TypeScript/JavaScript)"]="tsserver"
            ["gopls (Go)"]="gopls"
            ["lua_ls (Lua)"]="lua_ls"
        )
        
        servers_to_install=()
        for choice in "${selected_lsp[@]}"; do
            servers_to_install+=("${lsp_map[$choice]}")
        done
        
        setup_neovim "${servers_to_install[@]}"
    fi
    
    # Completion message
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}Installation complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo "You may need to restart your terminal for all changes to take effect."
    
    if [ ${#servers_to_install[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Neovim LSP Servers installed:${NC}"
        for server in "${servers_to_install[@]}"; do
            echo "  - $server"
        done
        echo -e "\nFirst launch of Neovim may take a moment to finish setting up."
    fi
    
    echo -e "\n${YELLOW}CMake Format has been installed and configured for Neovim.${NC}"
    echo "You can format CMake files with the command ':CMakeFormat' in Neovim."
}

main