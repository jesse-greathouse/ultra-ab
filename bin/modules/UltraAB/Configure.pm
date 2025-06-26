#!/usr/bin/env perl

package UltraAB::Configure;

use strict;
use warnings;
use Exporter 'import';
use File::Basename;
use File::Copy;
use Cwd qw(abs_path);
use Term::Prompt qw(prompt termwrap);
use Term::ANSIScreen qw(cls);
use lib(dirname(abs_path(__FILE__)) . "/../modules");
use UltraAB::Config qw(get_configuration save_configuration write_config_file);
use UltraAB::Utility qw(
    splash generate_rand_str validate_required_fields wordpress_composer_install
);
use UltraAB::Db qw(is_migrated is_docker_migrated);
use UltraAB::System qw(docker_db_up docker_db_down);
use UltraAB::RefreshKeysAndSalts qw(refresh_keys_and_salts);

our @EXPORT_OK = qw(configure configure_help);

warn $@ if $@;

# ------------------------
# Define Application Paths
# ------------------------

my $binDir          = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($binDir));
my $etcDir          = "$applicationRoot/etc";
my $optDir          = "$applicationRoot/opt";
my $varDir          = "$applicationRoot/var";
my $webDir          = "$applicationRoot/web";
my $srcDir          = "$applicationRoot/src";
my $tmpDir          = "$applicationRoot/tmp";
my $logDir          = "$varDir/log";
my $cacheDir        = "$varDir/cache";

my $secret = generate_rand_str();
my $applicationSecret = generate_rand_str();

# Files
my $sslCertificate  = "$etcDir/ssl/certs/ultra-ab.cert";
my $sslKey          = "$etcDir/ssl/private/ultra-ab.key";
my $errorLog        = "$logDir/error.log";
my $keysAndSalts    = "$varDir/keys/wordpress-keys-and-salts.php";

# ------------------------
# Load and Define Config
# ------------------------

my %cfg = get_configuration();

# List of configuration files to be written
my %config_files = (
    php_ini => [
      "$etcDir/php/php.dist.ini",
      "$etcDir/php/php.ini",
      "wordpress"
    ],
    php_fpm => [
      "$etcDir/php-fpm.d/php-fpm.dist.conf",
      "$etcDir/php-fpm.d/php-fpm.conf",
      "wordpress"
    ],
    force_ssl => [
      "$etcDir/nginx/force-ssl.dist.conf",
      "$etcDir/nginx/force-ssl.conf",
      "nginx"
    ],
    ssl_params => [
      "$etcDir/nginx/ssl-params.dist.conf",
      "$etcDir/nginx/ssl-params.conf",
      "nginx"
    ],
    nginx => [
      "$etcDir/nginx/nginx.dist.conf",
      "$etcDir/nginx/nginx.conf",
      "nginx"
    ],
    wordpress_cfg => [
      "$etcDir/wordpress/wp-config.php",
      "$webDir/wp-config.php",
      "wordpress"
    ],
    wordpress_env => [
      "$etcDir/wordpress/env.php",
      "$webDir/env.php",
      "wordpress"
    ],
    supervisord  => [
      "$etcDir/supervisor/conf.d/supervisord.conf.dist",
      "$etcDir/supervisor/conf.d/supervisord.conf",
      "supervisord"
    ],
);

# Default values
my %defaults = (
  nginx => {
    PORT         => '8686',
    SSL_CERT     => $sslCertificate,
    SSL_KEY      => $sslKey,
    IS_SSL       => 'false',
    HOST_NAMES   => '127.0.0.1 localhost',
  },
  wordpress => {
      SITE_TITLE     => 'Ultra A/B',
      SITE_URL       => 'http://localhost:8686',
      DB_HOST        => '127.0.0.1',
      DB_PORT        => '3306',
      DEBUG          => 'true',
      REDIS_DB       => '0',
      REDIS_HOST     => '127.0.0.1',
      REDIS_PASSWORD => 'null',
      REDIS_PORT     => '6379',
  },
  supervisord => {
      SUPERVISORCTL_USER => $ENV{"LOGNAME"},
  },
);

our @fields = (
    ['meta',        'SITE_NAME',          'Site Label'],
    ['nginx',       'HOST_NAMES',         'Server Host Names (nginx server_name)'],
    ['nginx',       'IS_SSL',             'Enable SSL (HTTPS)'],
    ['nginx',       'SSL_CERT',           'SSL Certificate Path (if using HTTPS)'],
    ['nginx',       'SSL_KEY',            'SSL Key Path (if using HTTPS)'],
    ['nginx',       'PORT',               'Web Server Port'],
    ['supervisord', 'SUPERVISORCTL_PORT', 'Supervisor Control Port'],
    ['wordpress',   'ADMIN_EMAIL',        'Admin Email Address'],
    ['wordpress',   'SITE_TITLE',         'Site Title'],
    ['wordpress',   'SITE_URL',           'Site URL (WordPress siteurl)'],
    ['wordpress',   'DEBUG',              'Enable Debugging'],
    ['wordpress',   'DB_HOST',            'Database Host'],
    ['wordpress',   'DB_NAME',            'Database Name'],
    ['wordpress',   'DB_USER',            'Database Username'],
    ['wordpress',   'DB_PASSWORD',        'Database Password'],
    ['wordpress',   'DB_PORT',            'Database Port'],
    ['wordpress',   'REDIS_HOST',         'Redis Host'],
    ['wordpress',   'REDIS_PORT',         'Redis Port'],
    ['wordpress',   'REDIS_PASSWORD',     'Redis Password (or null)'],
    ['wordpress',   'REDIS_DB',           'Redis DB Index'],
);

our @dockerFields = (
    ['wordpress',   'ADMIN_EMAIL',        'Admin Email Address'],
    ['nginx',       'HOST_NAMES',         'Server Host Names (nginx server_name)'],
    ['nginx',       'PORT',               'Web Server Port'],
    ['wordpress',   'SITE_TITLE',         'Site Title'],
    ['wordpress',   'SITE_URL',           'Site URL (WordPress siteurl)'],
    ['wordpress',   'DEBUG',              'Enable Debugging'],
);

my @required_fields = (
    ['meta',      'SITE_NAME'],
    ['wordpress', 'ADMIN_EMAIL'],
    ['wordpress', 'DB_NAME'],
    ['wordpress', 'DB_USER'],
    ['wordpress', 'DB_PASSWORD'],
);

# ================================
#       PUBLIC ENTRYPOINTS
# ================================

sub configure_help {
    print <<'EOF';
Usage: configure [--option]

Sets up the ultra-ab configuration system. By default, the script runs in interactive mode.

Examples:
  configure                   # Run interactive configuration
  configure --non-interactive # Use default or pre-defined values

Available options:
  --non-interactive   Skip all interactive prompts
  help                Show this help message
EOF
}

sub configure {
    my ($interactive) = @_;
    $interactive = 1 unless defined $interactive;

    if ($interactive) {
        cls();
        splash();
        print "\n=================================================================\n";
        print " This will configure your Ultra A/B Application Environment\n";
        print "=================================================================\n\n";
        merge_defaults();
        prompt_user_input();

        # Stop here if required fields were not submitted.
        validate_required_fields(\@required_fields, \%cfg);
    }

    assign_dynamic_config();
    save_configuration(%cfg);

    # Refreshes the cfg variable with exactly what was just written to the file.
    my %liveCfg = get_configuration();

    # Write configuration files
    foreach my $key (keys %config_files) {
      write_config(@{$config_files{$key}}, \%liveCfg);
    }

    # If Docker mode is enabled, generate docker-compose.yml from template
    if ($liveCfg{'meta'}{'IS_DOCKER'} eq 'true') {
        my $make_compose = "$binDir/make-docker-compose";
        system($make_compose) == 0
            or die "❌ Failed to generate docker-compose.yml using: $make_compose\n";
    }

    do_dhp() if $liveCfg{meta}{IS_DOCKER} eq 'true';

    if ($interactive) {
        prompt_wp_install();
        wp_skeleton_install();
        prompt_refresh_keys_and_salts();

        # Start DB container for Docker deployments
        if ($liveCfg{'meta'}{'IS_DOCKER'} eq 'true') {
            docker_db_up();
        }

        prompt_db_install();
        do_db_backup();
        prompt_run_migrations();
        prompt_wp_application_password();
        prompt_admin_password();

        if ($liveCfg{'meta'}{'IS_DOCKER'} eq 'true') {
            docker_db_down();
        }
        prompt_composer_installs();
        prompt_build_microfrontends();

        if ($liveCfg{'meta'}{'IS_DOCKER'} eq 'true') {
            prompt_finalize_docker();
        } else {
            prompt_finalize();
        }
    } else {
        # run keys and salts if it doesn't exist:
        -e $keysAndSalts or refresh_keys_and_salts();
        wordpress_composer_install(1);

        if ($liveCfg{'meta'}{'IS_DOCKER'} eq 'true') {
            docker_db_up();
        }

        prompt_wp_application_password(1);

        if ($liveCfg{'meta'}{'IS_DOCKER'} eq 'true') {
            docker_db_down();
        }

        print "\nConfiguration completed in non-interactive mode.\n";
        print "Note: If this is a fresh install, be sure to manually run the following commands as needed:\n\n";
        print "  bin/install-wordpress           # Install or update WordPress core files\n";
        print "  bin/install-wp-skeleton         # Install or update site code, plugins, and themes\n";
        print "  bin/install-wp-db               # Install the WordPress database tables\n";
        print "  bin/db-backup                   # Install the WordPress database tables\n";
        print "  bin/migrate                     # Runs any new migrations in src/sql/migrations\n";
        print "  bin/refresh-wp-keys-and-salts   # Refresh security keys and invalidate existing sessions\n";
        print "  bin/wordpress-composer-install  # 'composer install' for each plugin and theme\n";
        print "  bin/build                       # Builds micro-frontend frameworks (next.js, vue)\n\n";
    }
}

# ================================
#        SUBROUTINES
# ================================

# Writes a configuration file from its template.
sub write_config {
    my ($distFile, $outFile, $domain, $config_ref) = @_;
    return unless -e $distFile;
    write_config_file($distFile, $outFile, $domain, %$config_ref);
}

sub merge_defaults {
    foreach my $domain (keys %defaults) {
        foreach my $key (keys %{$defaults{$domain}}) {
            $cfg{$domain}{$key} //= $defaults{$domain}{$key};
        }
    }
}

sub is_required {
    my ($d, $k) = @_;
    return grep { $_->[0] eq $d && $_->[1] eq $k } @required_fields;
}

sub assign_dynamic_config {
    assign_meta_config();
    assign_wordpress_config();
    assign_nginx_config();
    assign_supervisord_config();
}

sub assign_meta_config {
    # Assign essential directory paths
    $cfg{meta}{USER}         //= $ENV{"LOGNAME"};
    $cfg{meta}{DIR}          //= $applicationRoot;
    $cfg{meta}{WEB}          //= $webDir;
    $cfg{meta}{VAR}          //= $varDir;
    $cfg{meta}{ETC}          //= $etcDir;
    $cfg{meta}{OPT}          //= $optDir;
    $cfg{meta}{SRC}          //= $srcDir;
    $cfg{meta}{TMP}          //= $tmpDir;
    $cfg{meta}{BIN}          //= $binDir;
    $cfg{meta}{CACHE_DIR}    //= $cacheDir;
    $cfg{meta}{LOG_DIR}      //= $logDir;
    $cfg{meta}{LOG}          //= $errorLog;
}

sub assign_wordpress_config {
    my $wpUser = $ENV{"LOGNAME"};
    my $wpApplicationRoot     = $applicationRoot;
    my $wpEtcDir              = $etcDir;
    my $wpVarDir              = $varDir;
    my $wpTmpDir              = $tmpDir;
    my $wpWebDir              = $webDir;

    if ($cfg{'meta'}{'IS_DOCKER'} eq 'true') {
      $wpApplicationRoot = "/var/www";
      $wpEtcDir = "/usr/local/etc";
      $wpTmpDir = "/tmp";
      $wpWebDir = "/var/www/html";
      $wpVarDir = "$wpApplicationRoot/var";
      $wpUser = "www-data";
    }

    my $wpBinDir          = "$wpApplicationRoot/bin";
    my $wpOptDir          = "$wpApplicationRoot/opt";
    my $wpSrcDir          = "$wpApplicationRoot/src";
    my $wpLogDir          = "$wpVarDir/log";
    my $wpCacheDir        = "$wpVarDir/cache";
    my $wpErrorLog        = "$wpLogDir/error.log";

    # Assign essential directory paths
    $cfg{wordpress}{USER}         //= $wpUser;
    $cfg{wordpress}{DIR}          //= $wpApplicationRoot;
    $cfg{wordpress}{WEB}          //= $wpWebDir;
    $cfg{wordpress}{VAR}          //= $wpVarDir;
    $cfg{wordpress}{ETC}          //= $wpEtcDir;
    $cfg{wordpress}{OPT}          //= $wpOptDir;
    $cfg{wordpress}{SRC}          //= $wpSrcDir;
    $cfg{wordpress}{TMP}          //= $wpTmpDir;
    $cfg{wordpress}{BIN}          //= $wpBinDir;
    $cfg{wordpress}{CACHE_DIR}    //= $wpCacheDir;
    $cfg{wordpress}{LOG_DIR}      //= $wpLogDir;
    $cfg{wordpress}{LOG}          //= $wpErrorLog;
    $cfg{wordpress}{PORT}         //= $cfg{nginx}{PORT};
    $cfg{wordpress}{SITE_NAME}    //= $cfg{meta}{SITE_NAME};
}

sub assign_nginx_config {
    my $nginxUser            = $ENV{"LOGNAME"};
    my $nginxApplicationRoot = $applicationRoot;
    my $nginxEtcDir          = $etcDir;
    my $nginxSrcDir          = $srcDir;
    my $nginxVarDir          = $varDir;
    my $nginxWebDir          = $webDir;
    my $nginxTmpDir          = $tmpDir;

    if ($cfg{'meta'}{'IS_DOCKER'} eq 'true') {
        $nginxApplicationRoot = "/var/www";
        $nginxEtcDir          = "/usr/local/openresty/nginx/conf";
        $nginxSrcDir          = "/usr/src";
        $nginxWebDir          = "/var/www/html";
        $nginxVarDir          = "$nginxApplicationRoot/var";
        $nginxTmpDir          = "/tmp";
        $nginxUser            = "www-data";
    }

    my $nginxBinDir   = "$nginxApplicationRoot/bin";
    my $nginxOptDir   = "$nginxApplicationRoot/opt";
    my $nginxLogDir   = "$nginxVarDir/log";
    my $nginxCacheDir = "$nginxVarDir/cache";

    $cfg{nginx}{USER}       //= $nginxUser;
    $cfg{nginx}{DIR}        //= $nginxApplicationRoot;
    $cfg{nginx}{WEB}        //= $nginxWebDir;
    $cfg{nginx}{VAR}        //= $nginxVarDir;
    $cfg{nginx}{ETC}        //= $nginxEtcDir;
    $cfg{nginx}{SRC}        //= $nginxSrcDir;
    $cfg{nginx}{OPT}        //= $nginxOptDir;
    $cfg{nginx}{BIN}        //= $nginxBinDir;
    $cfg{nginx}{TMP}        //= $nginxTmpDir;
    $cfg{nginx}{CACHE_DIR}  //= $nginxCacheDir;
    $cfg{nginx}{LOG_DIR}    //= $nginxLogDir;
    $cfg{nginx}{LOG}        //= "$nginxLogDir/error.log";

    $cfg{nginx}{REDIS_HOST}     //= $cfg{wordpress}{REDIS_HOST};
    $cfg{nginx}{REDIS_DB}       //= $cfg{wordpress}{REDIS_DB};
    $cfg{nginx}{REDIS_PORT}     //= $cfg{wordpress}{REDIS_PORT};
    $cfg{nginx}{REDIS_PASSWORD} //= $cfg{wordpress}{REDIS_PASSWORD};

    $cfg{nginx}{DB_NAME}        //= $cfg{wordpress}{DB_NAME};
    $cfg{nginx}{DB_USER}        //= $cfg{wordpress}{DB_USER};
    $cfg{nginx}{DB_PASSWORD}    //= $cfg{wordpress}{DB_PASSWORD};
    $cfg{nginx}{DB_HOST}        //= $cfg{wordpress}{DB_HOST};
    $cfg{nginx}{DB_PORT}        //= $cfg{wordpress}{DB_PORT};

    $cfg{nginx}{SESSION_SECRET} //= $secret;
    $cfg{nginx}{APPLICATION_SECRET} //= $applicationSecret;

    if ($cfg{nginx}{IS_SSL} eq 'true') {
        $cfg{nginx}{SSL_CERT_LINE} = "ssl_certificate $cfg{nginx}{SSL_CERT};";
        $cfg{nginx}{SSL_KEY_LINE}  = "ssl_certificate_key $cfg{nginx}{SSL_KEY};";
        $cfg{nginx}{INCLUDE_FORCE_SSL} = "include $etcDir/nginx/force-ssl.conf;";
        $cfg{nginx}{SSL} = "ssl";
    } else {
        $cfg{nginx}{SSL_CERT_LINE} = "";
        $cfg{nginx}{SSL_KEY_LINE}  = "";
        $cfg{nginx}{INCLUDE_FORCE_SSL} = "";
        $cfg{nginx}{SSL} = "";
    }
}

sub assign_supervisord_config {
    # Only do the supervisord config if not in the context of a docker deployment.
    return if $cfg{'meta'}{'IS_DOCKER'} eq 'true';

    $cfg{supervisord}{SUPERVISORCTL_USER} //= $ENV{"LOGNAME"};
    $cfg{supervisord}{SUPERVISORCTL_SECRET} //= $secret;
}

sub wp_skeleton_install {
    my $skeleton_script = "$binDir/install-wp-skeleton";

    system($skeleton_script) == 0
        or die "❌ WordPress skeleton installation failed via: $skeleton_script\n";
}

sub prompt_user_input {
    my $default;

    # ------------------------------------------------------
    # Step 0: Prompt for deployment mode if not already set
    # ------------------------------------------------------
    prompt_deployment_mode();

    # Set correct field list depending on Docker mode
    my @field_set = $cfg{'meta'}{'IS_DOCKER'} eq 'true' ? @dockerFields : @fields;

    foreach my $field (@field_set) {
        my ($domain, $key, $label) = @$field;

        if ($domain eq 'supervisord' && $key eq 'SUPERVISORCTL_PORT') {
            $cfg{$domain}{$key} = prompt_supervisor_port();
        }
        elsif ($key =~ /DEBUG|IS_SSL/) {
            $cfg{$domain}{$key} = prompt_boolean($cfg{$domain}{$key}, $label);
        }
        elsif ($key =~ /PORT/) {
            $cfg{$domain}{$key} = prompt_integer($cfg{$domain}{$key}, $label);
        }
        elsif (is_required($domain, $key)) {
            my $default = defined $cfg{$domain}{$key} ? ($cfg{$domain}{$key} || '') : '';
            $cfg{$domain}{$key} = prompt_with_validation($domain, $key, $label, $default);
        }
        else {
            $cfg{$domain}{$key} = prompt('x', "$label:", '', $cfg{$domain}{$key});
        }
    }
}

sub prompt_deployment_mode {
    return if exists $cfg{'meta'}{'IS_DOCKER'};

    my @menu_labels = (
        'Docker Compose (Oh yes! ...so easy. Me gusta!)',
        'System installation (Bare Metal Baby! I live my life on hard mode!)',
    );

    my %deployment_modes = (
        $menu_labels[0] => 'true',
        $menu_labels[1] => 'false',
    );

    my $selection_index = prompt(
        'm',
        {
            prompt       => "\nSelect deployment mode: ",
            title        => 'Deployment Mode',
            items        => \@menu_labels,
            order        => 'down',
            rows         => 2,
            cols         => 1,
            display_base => 1,
            return_base  => 0,
        },
        '',  # No help string
        1    # Default selection = index 0 (Docker Compose)
    );

    my $selected_label = $menu_labels[$selection_index];
    $cfg{'meta'}{'IS_DOCKER'} = $deployment_modes{$selected_label};

    if ($cfg{'meta'}{'IS_DOCKER'} eq 'true') {
        my $docker_cfg_file = "$applicationRoot/.ultra-ab-cfg.yml";
        my $docker_cfg_dist = "$etcDir/.ultra-ab-cfg.dist.yml";

        File::Copy::copy($docker_cfg_dist, $docker_cfg_file)
            or die "❌ Failed to copy Docker config scaffold: $docker_cfg_dist → $docker_cfg_file: $!\n";

        %cfg = get_configuration();
        merge_defaults();

        print "✅ Loaded Docker-specific config defaults.\n\n";
    }
}

sub prompt_supervisor_port {
    my $current = $cfg{supervisord}{SUPERVISORCTL_PORT};
    my $default;

    if (defined($current) && $current =~ /^\d+$/) {
        $default = $current;
    } else {
        srand();
        $default = int(40000 + rand(20000));
    }

    return prompt_integer($default, 'Supervisor Control Port');
}

sub prompt_boolean {
    my ($default, $label) = @_;
    $default //= 'false';
    my $prompt_val = ($default eq 'true') ? 'y' : 'n';
    return prompt('y', "$label", '', $prompt_val) ? 'true' : 'false';
}

sub prompt_integer {
    my ($default, $label) = @_;
    while (1) {
        my $val = prompt('x', "$label (integer):", '', $default);
        return $val if $val =~ /^\d+$/;
        print "Invalid input. Please enter an integer.\n";
    }
}

sub prompt_with_validation {
    my ($domain, $key, $label, $default) = @_;
    my $help = '';
    $help = 'value required' if $default eq '';

    my $value = prompt(
        's',               # 's' = code ref validation
        "$label:",         # prompt message
        $help,             # help text
        $default,          # default
        sub { 1; }
    );

    return $value;
}

sub prompt_build_microfrontends {
    my $vue_path  = "$srcDir/vue";
    my $next_path = "$srcDir/next-js";

    my $vue_modules  = "$vue_path/node_modules";
    my $next_modules = "$next_path/node_modules";

    my $vue_missing  = !-d $vue_modules;
    my $next_missing = !-d $next_modules;

    # If both are missing, just run the build automatically
    if ($vue_missing || $next_missing) {
        print "\n=================================================================\n";
        print " Building Micro‑Frontends (First‑Time Setup)\n";
        print "=================================================================\n\n";
        print "Both frontend builds are missing. Bootstrapping now…\n";

        system("$binDir/build") == 0
            or die "❌ Failed to build micro‑frontends via: $binDir/build\n";

        return;
    }

    print "\n=================================================================\n";
    print " Build Micro‑Frontends\n";
    print "=================================================================\n\n";

    print "Would you like to run 'bin/build' to rebuild the micro-frontend projects?\n\n";

    my $answer = prompt('y', "⚙️  Build micro-frontends now?", '', 'n');
    if ($answer) {
        system("$binDir/build") == 0
            or die "❌ Failed to build micro‑frontends via: $binDir/build\n";
    }
}

sub prompt_wp_install {
    require UltraAB::Utility;
    UltraAB::Utility->import(qw(get_wordpress_version));

    print "\n=================================================================\n";
    print " WordPress Codebase Check\n";
    print "=================================================================\n\n";

    my $version;
    eval {
        $version = get_wordpress_version();
    };

    if (!$@ && defined $version && $version ne '') {
        print "✅ WordPress is already installed.\n";
        print "→ Version: $version\n\n";
        return;
    }

    print "WordPress does not appear to be installed. Bootstrapping...\n\n";

    my $install_script = "$binDir/install-wordpress";

    unless (-x $install_script) {
        die "❌ Unable to locate or execute: $install_script\n";
    }

    system($install_script) == 0
        or die "❌ WordPress installation failed via: $install_script\n";
}

sub prompt_db_install {
    require UltraAB::Utility;
    UltraAB::Utility->import(qw(
        is_wordpress_db_installed
        prompt_user_password
        install_wordpress_database
    ));

    # Skip if already installed
    if (is_wordpress_db_installed()) {
        return;
    }

    print "\n=================================================================\n";
    print " WordPress Database Installation\n";
    print "=================================================================\n\n";

    print "The WordPress database is not yet installed.\n";
    print "This will run 'wp core install' to bootstrap the database.\n\n";

    my $admin_user     = prompt('x', "Enter admin username:", '', 'admin');
    my $admin_password = prompt_user_password();

    my $url         = $cfg{wordpress}{SITE_URL};
    my $site_title  = $cfg{wordpress}{SITE_TITLE}  || 'Just Another WordPress Site';
    my $admin_email = $cfg{wordpress}{ADMIN_EMAIL} || '';

    unless ($admin_email) {
        die "❌ Admin email is not configured. Please set ADMIN_EMAIL in configuration.\n";
    }

    install_wordpress_database($url, $site_title, $admin_user, $admin_email, $admin_password);
}

# Displays a prompt to refresh WordPress Keys and Salts file.
sub prompt_refresh_keys_and_salts {

    if (!-e $keysAndSalts) {
        refresh_keys_and_salts();
        return;
    }

    print "\n=================================================================\n";
    print " Refresh WordPress Keys and Salts\n";
    print "=================================================================\n\n";

    print "Refresh WordPress Keys and Salts?\n";
    print "This will cancel all existing/active users sessions.\n\n";
    print "You can also run this manually later using: bin/refresh-wp-keys-and-salts\n\n";

    my $answer = prompt('y', "Refresh WordPress Keys and Salts?", '', "n");

    if ($answer eq 1) {
        refresh_keys_and_salts();
    } else {
        print "\n";
    }
}

sub prompt_wp_application_password {
    my ($nonInteractive) = @_;
    $nonInteractive //= 0;

    print "\n=================================================================\n";
    print " WordPress Application Password\n";
    print "=================================================================\n\n";
    print "UltraAB will now check for the presence of an application password used for API integration.\n";
    print "You can rotate or create a new one here.\n\n";

    my $cmd = "$binDir/wp-application-password";
    $cmd .= " --non-interactive" if $nonInteractive;
    system($cmd) == 0 or die "❌ Failed to set/check application password via: $cmd\n";
}

# Optionally prompt to set the admin password post-configuration
sub prompt_admin_password {
    print "\n=================================================================\n";
    print " Admin User Password Change\n";
    print "=================================================================\n\n";

    print "Change the WordPress admin account password on demand.\n";
    print "You can provide it or skip this step.\n\n";

    my $answer = prompt('y', "Set the admin password now?", '', 'n');

    if ($answer eq 'y') {
      require UltraAB::Utility;
      UltraAB::Utility->import(qw(prompt_user_password update_wordpress_user_password));

      my $email = $cfg{wordpress}{ADMIN_EMAIL} // '';
      unless ($email) {
          print "❌ Admin email is not configured. Cannot proceed with password update.\n";
          return;
      }

      print "\nEnter a new password for the admin user ($email):\n";
      my $password = prompt_user_password();

      update_wordpress_user_password($email, $password);
  }
}

sub prompt_run_migrations {
    my $is_docker = $cfg{meta}{IS_DOCKER} // 0;
    my $already_migrated = $is_docker
        ? is_docker_migrated(\%cfg)
        : is_migrated(\%cfg);

    if (!$already_migrated) {
        print "\n=================================================================\n";
        print " Database Migrations\n";
        print "=================================================================\n\n";
        print "It looks like the required migrations have not been applied yet.\n";
        print "Running database migrations now...\n\n";
        system("$binDir/migrate") == 0
            or die "❌ Failed to run database migrations via: $binDir/migrate\n";
        return;
    }

    print "\n=================================================================\n";
    print " Database Migrations\n";
    print "=================================================================\n\n";
    print "Migrations have already been applied.\n";
    print "Would you like to run migrations again? (for new or pending changes)\n\n";

    my $answer = prompt('y', "Run migrations now?", '', 'n');
    if ($answer) {
        system("$binDir/migrate") == 0
            or die "❌ Failed to run database migrations via: $binDir/migrate\n";
    } else {
        print "Skipping migrations.\n";
    }
}


sub prompt_composer_installs {
    print "\n=================================================================\n";
    print " Composer Install for Plugins and Themes\n";
    print "=================================================================\n\n";

    print "This will check for composer.json files inside wp-content plugins and themes\n";
    print "and allow you to run 'composer install' for each one interactively.\n";
    print "You can run this step again manually later using: bin/wordpress-composer-install\n\n";

    my $answer = prompt('y', "⚙️  Run composer install for themes/plugins now?", '', 'y');
    return unless $answer;

    wordpress_composer_install(0);
}

sub prompt_finalize {
    print "\n=================================================================\n";
    print " Configuration Complete\n";
    print "=================================================================\n\n";

    print "🎉 ultra-ab has been successfully configured!\n";
    print "Your Ultra A/B instance is now ready to use.\n\n";

    print "🚀 To start your application, run:\n";
    print "    bin/ultra-ab start\n\n";

    print "🛠️ You can manage your application using the following commands:\n";
    print "    bin/ultra-ab start     — Launch web services\n";
    print "    bin/ultra-ab restart   — Restart web services\n";
    print "    bin/ultra-ab stop      — Stop web services\n";
    print "    bin/ultra-ab kill      — Kill supervisor-managed processes\n";
    print "    bin/ultra-ab help      — Show this help message\n\n";

    print "💡 For further updates, backups, or user management,\n";
    print "   refer to the other scripts in the bin/ directory.\n\n";
}

sub prompt_finalize_docker {
    open(my $fh1, '>>', "$logDir/error.log"); close($fh1);
    open(my $fh2, '>>', "$logDir/access.log"); close($fh2);

    my $wp_admin_url = $cfg{wordpress}{SITE_URL} . "/wp-admin/";

    print "\n=================================================================\n";
    print " Configuration Complete (Docker Mode)\n";
    print "=================================================================\n\n";

    print "🎉 ultra-ab has been successfully configured for Docker Compose!\n";
    print "Your containerized Ultra A/B instance is now ready to use.\n\n";

    print "🚀 To start your application, run:\n";
    print "    docker compose up -d\n\n";

    print "🛠️ You can manage your application using the following Docker Compose commands:\n";
    print "    docker compose up -d        — Launch all containers in the background\n";
    print "    docker compose down         — Stop and remove containers\n";
    print "    docker compose ps           — Show running services\n";
    print "    docker compose logs -f      — View live logs from all services\n";
    print "    docker compose restart      — Restart all services\n\n";

    print "📁 The docker-compose.yml file was generated from your configuration.\n";
    print "   You can inspect or edit it manually if needed:\n";
    print "     → $applicationRoot/docker-compose.yml\n\n";

    print "🌐 Once your containers are running, you can access the WordPress admin dashboard at:\n";
    print "    $wp_admin_url\n\n";
    print "   This will allow you to log in and begin managing your content, settings, and plugins.\n\n";
}


sub do_db_backup {
    require UltraAB::Utility;
    UltraAB::Utility->import(qw(is_wordpress_db_installed wordpress_database_backup));

    if (!is_wordpress_db_installed()) {
        return;
    }

    print "\n=================================================================\n";
    print " WordPress Database Backup\n";
    print "=================================================================\n\n";

    print "📀 Creating database snapshot...\n";
    wordpress_database_backup();
}

sub do_dhp {
    my $dhp_script = "$binDir/dhp";

    unless (-x $dhp_script) {
        die "❌ DHP script not found or not executable: $dhp_script\n";
    }

    print "📜 Running Diffie-Hellman param generation script...\n";
    system($dhp_script) == 0
        or die "❌ Failed to execute dhp script: $!\n";
}

1;
