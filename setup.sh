#!/bin/bash
set -euo pipefail

# claude-skill-getvideo installer
# Installs dependencies and sets up the /getvideo skill for Claude Code

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SOURCE="$REPO_DIR/skills/getvideo"
SKILL_TARGET="$HOME/.claude/skills/getvideo"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

installed=()
skipped=()
failed=()

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*) OS="macos" ;;
        Linux*)  OS="linux" ;;
        *)       error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    info "Detected OS: $OS"
}

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# Ask for confirmation
confirm() {
    local prompt="$1"
    echo -en "${YELLOW}$prompt [y/N]:${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Install Homebrew (macOS only)
install_brew() {
    if [[ "$OS" != "macos" ]]; then return; fi
    if has brew; then
        skipped+=("Homebrew (already installed)")
        return
    fi
    info "Homebrew is required on macOS for installing dependencies."
    if confirm "Install Homebrew?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        installed+=("Homebrew")
    else
        warn "Skipping Homebrew. You may need to install dependencies manually."
        failed+=("Homebrew (skipped by user)")
    fi
}

# Install yt-dlp
install_ytdlp() {
    if has yt-dlp; then
        skipped+=("yt-dlp $(yt-dlp --version 2>/dev/null || echo '')")
        return
    fi
    info "yt-dlp is required for downloading videos."
    if confirm "Install yt-dlp?"; then
        if [[ "$OS" == "macos" ]] && has brew; then
            brew install yt-dlp
        elif has pip3; then
            pip3 install yt-dlp
        elif has pip; then
            pip install yt-dlp
        else
            error "No package manager available. Install yt-dlp manually: https://github.com/yt-dlp/yt-dlp"
            failed+=("yt-dlp")
            return
        fi
        installed+=("yt-dlp")
    else
        failed+=("yt-dlp (skipped by user)")
    fi
}

# Install ffmpeg
install_ffmpeg() {
    if has ffmpeg; then
        skipped+=("ffmpeg")
        return
    fi
    info "ffmpeg is required for audio extraction."
    if confirm "Install ffmpeg?"; then
        if [[ "$OS" == "macos" ]] && has brew; then
            brew install ffmpeg
        elif [[ "$OS" == "linux" ]]; then
            if has apt; then
                sudo apt update && sudo apt install -y ffmpeg
            elif has dnf; then
                sudo dnf install -y ffmpeg
            elif has pacman; then
                sudo pacman -S --noconfirm ffmpeg
            else
                error "No supported package manager found. Install ffmpeg manually."
                failed+=("ffmpeg")
                return
            fi
        fi
        installed+=("ffmpeg")
    else
        failed+=("ffmpeg (skipped by user)")
    fi
}

# Install Python 3
install_python() {
    if has python3; then
        skipped+=("Python $(python3 --version 2>/dev/null | awk '{print $2}')")
        return
    fi
    info "Python 3 is required for whisper transcription."
    if confirm "Install Python 3?"; then
        if [[ "$OS" == "macos" ]] && has brew; then
            brew install python@3.12
        elif [[ "$OS" == "linux" ]]; then
            if has apt; then
                sudo apt update && sudo apt install -y python3 python3-pip
            elif has dnf; then
                sudo dnf install -y python3 python3-pip
            fi
        fi
        installed+=("Python 3")
    else
        failed+=("Python 3 (skipped by user)")
    fi
}

# Install whisper
install_whisper() {
    if has whisper; then
        skipped+=("whisper")
        return
    fi
    info "OpenAI Whisper is required for speech-to-text transcription."
    info "Note: whisper models range from ~145MB (base) to ~1.5GB (medium)."
    if confirm "Install openai-whisper?"; then
        pip3 install openai-whisper
        installed+=("whisper")
    else
        warn "Whisper is optional — you can still download videos without transcription."
        failed+=("whisper (skipped by user)")
    fi
}

# Fix SSL certificates on macOS (needed for whisper model downloads)
fix_ssl_macos() {
    if [[ "$OS" != "macos" ]]; then return; fi
    if ! has whisper; then return; fi

    # Check if SSL certificates work
    if python3 -c "import urllib.request; urllib.request.urlopen('https://openaipublic.azureedge.net')" &>/dev/null; then
        return
    fi

    warn "SSL certificates may not be configured for Python on macOS."
    info "This is required for whisper to download models."

    # Try Install Certificates.command
    local python_dir
    python_dir="$(python3 -c 'import sys; print(sys.prefix)')"
    local cert_script="$python_dir/../../Install Certificates.command"

    if [[ -f "$cert_script" ]]; then
        if confirm "Run 'Install Certificates.command' to fix SSL?"; then
            bash "$cert_script"
            success "SSL certificates installed."
        fi
    else
        info "Alternative fix: pip3 install certifi"
        if confirm "Install certifi and configure SSL?"; then
            pip3 install certifi
            local cert_path
            cert_path="$(python3 -c 'import certifi; print(certifi.where())')"
            echo "export SSL_CERT_FILE=$cert_path" >> "$HOME/.zshrc" 2>/dev/null || \
            echo "export SSL_CERT_FILE=$cert_path" >> "$HOME/.bashrc" 2>/dev/null
            export SSL_CERT_FILE="$cert_path"
            success "SSL configured via certifi."
        fi
    fi
}

# Set up skill symlink
setup_symlink() {
    info "Setting up skill symlink..."

    mkdir -p "$HOME/.claude/skills"

    if [[ -L "$SKILL_TARGET" ]]; then
        local current_target
        current_target="$(readlink "$SKILL_TARGET")"
        if [[ "$current_target" == "$SKILL_SOURCE" ]]; then
            skipped+=("Symlink (already correct)")
            return
        fi
        warn "Existing symlink points to: $current_target"
        if confirm "Update symlink to point to this repo?"; then
            rm "$SKILL_TARGET"
            ln -s "$SKILL_SOURCE" "$SKILL_TARGET"
            installed+=("Symlink updated")
        fi
    elif [[ -d "$SKILL_TARGET" ]]; then
        warn "Directory exists at $SKILL_TARGET (not a symlink)"
        if confirm "Replace with symlink to this repo?"; then
            rm -rf "$SKILL_TARGET"
            ln -s "$SKILL_SOURCE" "$SKILL_TARGET"
            installed+=("Symlink (replaced directory)")
        fi
    else
        ln -s "$SKILL_SOURCE" "$SKILL_TARGET"
        installed+=("Symlink created")
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "============================================================"
    echo "  claude-skill-getvideo — Setup Summary"
    echo "============================================================"

    if [[ ${#installed[@]} -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}Installed:${NC}"
        for item in "${installed[@]}"; do
            echo "  + $item"
        done
    fi

    if [[ ${#skipped[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}Already installed:${NC}"
        for item in "${skipped[@]}"; do
            echo "  - $item"
        done
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Skipped/Failed:${NC}"
        for item in "${failed[@]}"; do
            echo "  ! $item"
        done
    fi

    echo ""
    echo "------------------------------------------------------------"

    # Verification
    local all_ok=true
    echo ""
    echo "Verification:"
    if has yt-dlp; then
        echo -e "  ${GREEN}✓${NC} yt-dlp $(yt-dlp --version 2>/dev/null)"
    else
        echo -e "  ${RED}✗${NC} yt-dlp not found"
        all_ok=false
    fi
    if has ffmpeg; then
        echo -e "  ${GREEN}✓${NC} ffmpeg installed"
    else
        echo -e "  ${RED}✗${NC} ffmpeg not found"
        all_ok=false
    fi
    if has whisper; then
        echo -e "  ${GREEN}✓${NC} whisper installed"
    else
        echo -e "  ${YELLOW}~${NC} whisper not installed (optional, needed for transcription)"
    fi
    if [[ -L "$SKILL_TARGET" ]]; then
        echo -e "  ${GREEN}✓${NC} Skill symlink: $(readlink "$SKILL_TARGET")"
    else
        echo -e "  ${RED}✗${NC} Skill symlink not set up"
        all_ok=false
    fi

    echo ""
    if $all_ok; then
        echo -e "${GREEN}Setup complete! Use /getvideo <URL> in Claude Code.${NC}"
    else
        echo -e "${YELLOW}Some components are missing. Check the output above.${NC}"
    fi
    echo "============================================================"
}

# Main
main() {
    echo ""
    echo "============================================================"
    echo "  claude-skill-getvideo — Setup"
    echo "============================================================"
    echo ""

    detect_os
    echo ""

    install_brew
    install_ytdlp
    install_ffmpeg
    install_python
    install_whisper
    fix_ssl_macos
    setup_symlink
    print_summary
}

main
