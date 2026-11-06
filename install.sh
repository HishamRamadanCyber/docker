#!/bin/bash
# ============================================================
#  Docker installer
#  Supports: Ubuntu, Debian, CentOS, RHEL, Rocky, AlmaLinux, Fedora
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/HishamRamadanCyber/docker/main/install-docker.sh | sudo bash
# ============================================================

set -euo pipefail

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; NC="\e[0m"
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# --- Must run as root ---
[ "$(id -u)" -eq 0 ] || error "Run this script as root (use sudo)."

# --- Detect OS ---
[ -f /etc/os-release ] || error "Cannot detect the operating system."
. /etc/os-release
OS="${ID}"
info "Detected OS: ${PRETTY_NAME}"

# --- Skip install if Docker already exists ---
if command -v docker >/dev/null 2>&1; then
    warn "Docker is already installed: $(docker --version)"
else
    case "$OS" in
        ubuntu|debian)
            info "Removing old Docker packages (if any)..."
            for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
                apt-get remove -y "$pkg" >/dev/null 2>&1 || true
            done

            info "Installing prerequisites..."
            apt-get update -y
            apt-get install -y ca-certificates curl

            info "Adding Docker's official GPG key and repository..."
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/${OS}/gpg" -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc

            CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS} ${CODENAME} stable" \
                > /etc/apt/sources.list.d/docker.list

            info "Installing Docker..."
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        centos|rhel|rocky|almalinux|fedora)
            case "$OS" in
                fedora) REPO="https://download.docker.com/linux/fedora/docker-ce.repo" ;;
                rhel)   REPO="https://download.docker.com/linux/rhel/docker-ce.repo" ;;
                *)      REPO="https://download.docker.com/linux/centos/docker-ce.repo" ;;
            esac

            info "Removing old Docker packages (if any)..."
            dnf remove -y docker docker-client docker-client-latest docker-common \
                docker-latest docker-latest-logrotate docker-logrotate docker-engine \
                podman runc >/dev/null 2>&1 || true

            info "Adding Docker repository..."
            dnf install -y dnf-plugins-core
            dnf config-manager --add-repo "$REPO" 2>/dev/null \
                || dnf config-manager addrepo --from-repofile="$REPO"

            info "Installing Docker..."
            dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        *)
            error "Unsupported OS: ${OS}"
            ;;
    esac
fi

# --- Start Docker and enable on boot ---
info "Starting Docker and enabling it on boot..."
systemctl enable --now docker

# --- Let the normal user run docker without sudo ---
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    usermod -aG docker "$SUDO_USER"
    info "Added user '${SUDO_USER}' to the docker group (log out and back in to apply)."
fi

# --- Test ---
info "Testing Docker..."
if docker run --rm hello-world >/dev/null 2>&1; then
    info "Docker is working!"
else
    warn "Docker installed, but the test container failed. Check: systemctl status docker"
fi

echo
info "Docker version:  $(docker --version)"
info "Compose version: $(docker compose version 2>/dev/null || echo 'not installed')"
echo -e "${GREEN}Done!${NC}"
