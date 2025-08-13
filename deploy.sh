#!/bin/bash

# Variables
REPOSITORY_PATH="/var/www/html/Walkin_Admin/"
BRANCH="uat"
REMOTE_REPO="git@github.com:jittupant/Walkin_Admin.git"
PHP_FPM_SERVICE="php8.0-fpm"  # Change if using a different PHP version

# Navigate to the project directory
cd $REPOSITORY_PATH

# Pull the latest changes from the specified branch
echo "Pulling latest changes from $BRANCH branch..."
git fetch origin $BRANCH
git reset --hard origin/$BRANCH

# Install/update dependencies
echo "Installing dependencies..."
composer install --no-dev --prefer-dist --optimize-autoloader


# Clear caches
echo "Clearing cache..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Set proper permissions
echo "Setting file permissions..."
sudo chown -R www-data:www-data $REPOSITORY_PATH
sudo chmod -R 775 $REPOSITORY_PATH/storage
sudo chmod -R 775 $REPOSITORY_PATH/bootstrap/cache

# Restart PHP-FPM service (if using Nginx)
echo "Restarting PHP-FPM service..."
sudo systemctl reload $PHP_FPM_SERVICE

echo "Deployment completed successfully."
