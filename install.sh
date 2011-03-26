printf "Installing perl module\n"
printf "installing Digest::Perl::MD5 (perl)\n"
perl -MCPAN -e 'install Digest::Perl::MD5'
printf "installing XML::Simple (perl)\n"
perl -MCPAN -e 'install XML::Simple'

printf "\nchanging ./dat permission to 777\n"
chmod -R 777 ./dat
chmod 644 ./dat/.htaccess
printf "\nchanging ./files permission to 777\n"
chmod -R 777 ./files
chmod 644 ./files/.htaccess

printf "\ngit init dat/page\n"
git init dat/page

