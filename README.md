# Install packages

Starting on my dotfiles journey.
This is a excellent blog if you also want to get [started](https://writingco.de/blog/how-i-manage-my-dotfiles-using-gnu-stow/)

Then I add some ansible sprinkle on top.

## submodules

git submodule update --init --recursive

## Install

### Fedora

```bash
sudo dnf install ansible

# Needed to refresh flathub repo
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# Needed for flatpack config
ansible-galaxy collection install community.general

```

### Arche

```bash
sudo pacman -S ansible
```

### sudoers

sudo sh -c "echo \"$USER ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"

### Run playbook

```shell
ansible-playbook playbook.yml
```

The ansible script will install lots of good tools.
It will also set ZSH as your default shell. Remember to login and out.

### zsh

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

### run the script

Run code before starting the script. Else we will get intresting linking stuff.

```bash
# Remove the .bashrc so we can stow it.
sudo rm .bashrc
sudo setup.sh
rm .bashrc .zshrc
setup.sh
```

## Manual tasks

Some tasks was a pain to do with ansible...

## Gnome settings

### Disable gnome tabs

```bash
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Super>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['<Shift><Alt>Tab']"
gsettings set org.gnome.shell.window-switcher current-workspace-only "false"
```

### Disable revert mouse

```bash
gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
```

### Fix shortcut

```bash
name="termite"
binding="<CTRL><ALT>t"
action="ghostty"

media_keys=org.gnome.settings-daemon.plugins.media-keys
custom_kbd=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
kbd_path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$name/
new_bindings=`gsettings get $media_keys custom-keybindings | sed -e"s>'\]>','$kbd_path']>"| sed -e"s>@as \[\]>['$kbd_path']>"`
gsettings set $media_keys custom-keybindings "$new_bindings"
gsettings set $custom_kbd:$kbd_path name $name
gsettings set $custom_kbd:$kbd_path binding $binding
gsettings set $custom_kbd:$kbd_path command $action
```

### Disable hot corners

gsettings set org.gnome.desktop.interface enable-hot-corners false

### Enable middle mouse paste

```bash
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true
```

## Brave browser

```bash
sudo dnf install dnf-plugins-core
sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
sudo dnf install brave-browser
```

## TODO

- Turn stuff in to ansible when reasonable
- Auto install vscode extensions

### VScode

There is today no easy way to manage extensions using git but there is a sync-option that is in preview but i don't want to use it...
Instead my plan is to write a simple script that I will run from time to time to keep my extensions updated.

```bash
# Create the backup
code --list-extensions > vscode-extensions.list
# To install on a new client
cat vscode-extensions.list | xargs -L 1 code --install-extension
# It might have to say code or codium depending on os.
```

### Applications

- manage all your favorite cli:s...
  - kubectl
  - etc

I have created a repo to automatically download the latest releases of binaries from github called [gitHubBinDl](https://github.com/NissesSenap/gitHubBinDl/).
I haven't updated in a long time so these commands probably is correct.

```shell
cd ~/.local/bin
wget https://github.com/NissesSenap/gitHubBinDl/releases/download/v0.2.0/githubbindl_linux_amd64
mv githubbindl_linux_amd64 githubbindl
chmod 755 githubbindl
# From the dotfiles folder
```

## Firmware updates

Remember to update firmware from time to time. Check out if you have access to use this.

[fwupd devices](https://fwupd.org/lvfs/devices/)

```shell
sudo fwupdmgr refresh
fwupdmgr get-devices
fwupdmgr get-updates
sudo fwupdmgr update
```

## Commands

### Random command

Commands I never use and need to remember...

```shell
git submodule add https://github.com/zsh-users/zsh-syntax-highlighting.git zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

## Shell

I personally use [material shell](https://material-shell.com/) which is a gnome [extension](https://extensions.gnome.org/extension/3357/material-shell/).

Install the gnome extensions package to easily configure the material shell.

### Future

A future option might be: [https://regolith-desktop.com/](https://github.com/paperwm/PaperWM) or [https://github.com/paperwm/PaperWM](https://github.com/paperwm/PaperWM).

## Kind

To run kind on podman:

```shell
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster
```
