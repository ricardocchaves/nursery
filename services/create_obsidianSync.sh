#!/bin/bash
# Regularly sync Obsidian vault with git repository
# Steps to create the service
sudo bash -c 'cat > /usr/local/bin/obsidianSync.sh << EOL
#!/bin/bash
pushd /home/rcc/Documents/ObsidianVault || return

# Stage all changes (including new and deleted files)
git add .

# Check for any differences
if ! git diff-index --cached --quiet HEAD --; then
    git commit -m "obsidian: sync notes"
    git push
fi

popd || return

exit 0
EOL'
sudo chmod +x /usr/local/bin/obsidianSync.sh

(crontab -l ; echo "*/30 * * * * /usr/local/bin/obsidianSync.sh") | crontab -
