echo "Installing perl module\n"
echo "installing DBI::DBD (perl)\n"
perl -MCPAN -e 'install DBI::DBD'
echo "installing DBD::SQLite (perl)\n"
perl -MCPAN -e 'install DBD::SQLite'

echo "\nchanging ./dat permission to 777\n"
chmod -R 777 ./dat
chmod 644 ./dat/.htaccess
echo "\nchanging ./files permission to 777\n"
chmod -R 777 ./files
chmod 644 ./files/.htaccess

echo "\nPlease install sqlite3 if not installed"
