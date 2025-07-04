#!/usr/bin/env perl

package UltraAB::Install::Ubuntu;

use strict;
use Cwd qw(getcwd abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/modules";
use UltraAB::Utility qw(command_result);
use UltraAB::System qw(how_many_threads_should_i_use);
use Exporter 'import';

our @EXPORT_OK = qw(install_system_dependencies install_php install_bazelisk);

my @systemDependencies = qw(
    supervisor authbind expect openssl build-essential intltool autoconf
    automake gcc-13 g++-13 libstdc++-13-dev curl pkg-config cpanminus
    libncurses-dev libpcre3-dev libcurl4-openssl-dev libmagickwand-dev
    libssl-dev libxslt1-dev libmysqlclient-dev libxml2 libxml2-dev
    libicu-dev libmagick++-dev libzip-dev libonig-dev libsodium-dev
    libglib2.0-dev libwebp-dev mysql-client imagemagick zip
);

# ====================================
# Subroutines
# ====================================

# Installs OS-level system dependencies.
sub install_system_dependencies {
    my $username = getpwuid($<);
    print "Sudo is required for updating and installing system dependencies.\n";
    print "Please enter sudoers password for: $username elevated privileges.\n";

    # Update apt cache
    my @updateCmd = ('sudo', 'apt-get', 'update');
    system(@updateCmd);
    command_result($?, $!, "Updated package index...", \@updateCmd);

    # Filter system dependencies: only keep those that aren't already installed
    my @to_install;
    foreach my $pkg (@systemDependencies) {
        my $check = system("dpkg -s $pkg > /dev/null 2>&1");
        if ($check != 0) {
            push @to_install, $pkg;
        } else {
            print "✓ $pkg already installed, skipping.\n";
        }
    }

    # Install only what’s missing
    if (@to_install) {
        my @installCmd = ('sudo', 'apt-get', 'install', '-y', @to_install);
        system(@installCmd);
        command_result($?, $!, "Installed missing dependencies...", \@installCmd);
    } else {
        print "All system dependencies already installed.\n";
    }
}

# Installs PHP.
sub install_php {
    my ($dir) = @_;
    my $threads = how_many_threads_should_i_use();

    my @configurePhp = (
        './configure',
        '--prefix=' . $dir . '/opt/php',
        '--sysconfdir=' . $dir . '/etc',
        '--with-config-file-path=' . $dir . '/etc/php',
        '--enable-opcache', '--enable-fpm', '--enable-dom', '--enable-exif',
        '--enable-fileinfo', '--enable-mbstring', '--enable-bcmath',
        '--enable-intl', '--enable-ftp', '--enable-pcntl', '--enable-gd',
        '--enable-soap', '--enable-sockets', '--without-sqlite3', '--without-pdo-sqlite',
        '--with-libxml', '--with-xsl', '--with-xmlrpc', '--with-zlib',
        '--with-curl', '--with-webp', '--with-openssl', '--with-zip', '--with-bz2',
        '--with-sodium', '--with-mysqli', '--with-pdo-mysql', '--with-mysql-sock',
        '--with-iconv'
    );

    my $originalDir = getcwd();

    # Unpack PHP Archive
    my ($archive) = glob("$dir/opt/php-*.tar.gz");

    unless ($archive && -e $archive) {
        die "PHP archive not found: $dir/opt/php-*.tar.gz\n";
    }

    system('tar', '-xzf', $archive, '-C', "$dir/opt/");
    command_result($?, $!, 'Unpacked PHP Archive...', ['tar', '-xzf', $archive, '-C', "$dir/opt/"]);

    chdir glob("$dir/opt/php-*/");

    # Configure PHP using GCC 13 if available
    my $gcc13_path = `which gcc-13 2>/dev/null`;
    my $gpp13_path = `which g++-13 2>/dev/null`;

    chomp($gcc13_path);
    chomp($gpp13_path);

    if ($gcc13_path && $gpp13_path) {
        print "✓ Using GCC 13 for PHP compilation.\n";
        local %ENV = (
            %ENV,
            CC  => $gcc13_path,
            CXX => $gpp13_path
        );
        system(@configurePhp);
    } else {
        print "⚠ GCC 13 not found, using system default compiler.\n";
        system(@configurePhp);
    }

    system(@configurePhp);
    command_result($?, $!, 'Configured PHP...', \@configurePhp);

    # Make and Install PHP
    print "\n=================================================================\n";
    print " Compiling PHP...\n";
    print "=================================================================\n\n";
    print "Running make using $threads threads in concurrency.\n\n";

    system('make', "-j$threads");
    command_result($?, $!, 'Made PHP...', 'make');

    system('make', 'install');
    command_result($?, $!, 'Installed PHP...', 'make install');

    chdir $originalDir;
}
1;
