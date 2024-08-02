#!/bin/bash
# Set all cores to performance on boot
# Steps to create the service
sudo bash -c 'cat > /usr/local/bin/setgov.sh << EOL
#!/bin/bash
setgov() {
echo "\$1" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
}

setgov performance
EOL'
sudo chmod +x /usr/local/bin/setgov.sh

sudo bash -c 'cat > /etc/systemd/system/setgov.service << EOL
[Unit]
Description=Set CPU governor to performance
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setgov.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOL'

sudo systemctl daemon-reload
sudo systemctl enable setgov.service
sudo systemctl start setgov.service
