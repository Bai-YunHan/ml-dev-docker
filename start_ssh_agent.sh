#!/usr/bin/env bash
# Usage: source ./start_ssh_agent.sh
# Must be sourced (not executed) so SSH_AUTH_SOCK is exported to your current shell.

# Prompt the user for private key path, the default path is ~/.ssh/serverh200, enter to use default.
read -p "Enter private key path (Press enter to use default: ~/.ssh/serverh200): " private_key_path
private_key_path=${private_key_path:-~/.ssh/serverh200}

if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l &>/dev/null; then
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "${private_key_path}"
    echo "SSH agent started and key loaded."
else
    echo "SSH agent already running ($(ssh-add -l | wc -l) key(s) loaded)."
fi