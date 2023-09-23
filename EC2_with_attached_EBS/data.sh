#!/bin/bash
while [ ! -e /dev/xvdf ]; do sleep 1; done
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2.service
echo "Hello GR World" | sudo tee /var/www/html/index.html
sudo mkfs.ext4 /dev/xvdf
sudo mount /dev/xvdf /var/www/html
echo "/dev/xvdf /var/www/html ext4 defaults 0 0" >> /etc/fstab


    
