#!/usr/bin/env perl

package UltraAB::Db;
use strict;
use warnings;
use Exporter 'import';
use DBI;

our @EXPORT_OK = qw(
    run_in_docker
    run_with_perl_dbi
    run_sql_in_docker
    run_sql_with_perl_dbi
    fetch_in_docker
    fetch_with_perl_dbi
    is_docker_migrated
    is_migrated
);

sub _db_params {
    my ($cfg) = @_;
    my $nginx = $cfg->{nginx} or die "No 'nginx' section in config\n";

    my $user     = $nginx->{DB_USER}     // die "No nginx.DB_USER in config\n";
    my $password = $nginx->{DB_PASSWORD} // '';
    my $database = $nginx->{DB_NAME}     // die "No nginx.DB_NAME in config\n";
    my $host     = $nginx->{DB_HOST}     // 'localhost';
    my $port     = $nginx->{DB_PORT}     // 3306;

    return (
        user     => $user,
        password => $password,
        database => $database,
        host     => $host,
        port     => $port,
    );
}

sub run_in_docker {
    my ($cfg, $sqlfile) = @_;

    my %db = _db_params($cfg);

    # password via env, not in process list
    my $cmd = qq{
        docker exec -i ultraab_db mariadb
          -u$db{user}
          -h$db{host}
          -D$db{database}
          -P$db{port}
          -p"\$MYSQL_PWD"
    };
    $cmd =~ s/\n/ /g;
    local $ENV{MYSQL_PWD} = $db{password};
    open my $fh, '<', $sqlfile or die "Can't read $sqlfile: $!\n";
    open my $pipe, '|-', $cmd or die "Failed to exec mariadb: $!\n";
    print $pipe $_ while <$fh>;
    close $pipe or die "mariadb failed: $?\n";
}

sub run_with_perl_dbi {
    my ($cfg, $sqlfile) = @_;
    die "SQL file not found: $sqlfile\n" unless -f $sqlfile;
    my $sql = do {
        open my $fh, '<', $sqlfile or die "Failed to read $sqlfile: $!\n";
        local $/; <$fh>;
    };

    my %db = _db_params($cfg);

    my $dsn = "DBI:mysql:database=$db{database};host=$db{host};port=$db{port}";

    my $dbh = DBI->connect($dsn, $db{user}, $db{password}, { RaiseError => 1, PrintError => 0, AutoCommit => 1 })
      or die "DBI connect failed\n";

    for my $stmt (split /;\s*\n/, $sql) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt);
    }
    $dbh->disconnect;
}

sub fetch_in_docker {
    my ($cfg, $sql) = @_;
    die "Missing SQL string to execute\n" unless defined $sql and length $sql;

    my %db = _db_params($cfg);

    my $cmd = qq{
        docker exec -i ultraab_db mariadb
          -B
          -u$db{user}
          -h$db{host}
          -D$db{database}
          -P$db{port}
          -p"\$MYSQL_PWD"
          -e "$sql"
    };
    $cmd =~ s/\n/ /g;

    local $ENV{MYSQL_PWD} = $db{password};
    open my $out, '-|', $cmd or die "Failed to fetch query output: $!\n";
    my $header = <$out>;
    unless (defined $header && length $header) {
        close $out;
        return ();
    }

    chomp $header;
    my @cols = split /\t/, $header;
    my @rs;
    while (my $line = <$out>) {
        chomp $line;
        my @vals = split /\t/, $line, scalar(@cols);
        my %row;
        @row{@cols} = @vals;
        push @rs, \%row;
    }
    close $out;
    return @rs;
}

sub fetch_with_perl_dbi {
    my ($cfg, $sql) = @_;
    die "Missing SQL string to execute\n" unless defined $sql and length $sql;

    my %db = _db_params($cfg);
    my $dsn = "DBI:mysql:database=$db{database};host=$db{host};port=$db{port}";

    my $dbh = DBI->connect($dsn, $db{user}, $db{password}, { RaiseError => 1, PrintError => 0, AutoCommit => 1 })
      or die "DBI connect failed\n";

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @rs;
    while (my $row = $sth->fetchrow_hashref) {
        push @rs, { %$row };
    }
    $sth->finish;
    $dbh->disconnect;
    return @rs;
}

sub run_sql_in_docker {
    my ($cfg, $sql) = @_;
    my %db = _db_params($cfg);

    my $cmd = qq{
        docker exec -i ultraab_db mariadb
          -u$db{user}
          -h$db{host}
          -D$db{database}
          -P$db{port}
          -p"\$MYSQL_PWD"
          -e "$sql"
    };
    $cmd =~ s/\n/ /g;
    local $ENV{MYSQL_PWD} = $db{password};
    system($cmd) == 0
        or die "Failed to execute SQL in Docker: $sql\n";
}

sub run_sql_with_perl_dbi {
    my ($cfg, $sql) = @_;
    my %db = _db_params($cfg);

    my $dsn = "DBI:mysql:database=$db{database};host=$db{host};port=$db{port}";
    my $dbh = DBI->connect($dsn, $db{user}, $db{password}, { RaiseError => 1, PrintError => 0, AutoCommit => 1 })
        or die "DBI connect failed\n";
    $dbh->do($sql);
    $dbh->disconnect;
}

sub is_docker_migrated {
    my ($cfg) = @_;
    my $sql = "SELECT * FROM migrations LIMIT 1";
    my @rs = fetch_in_docker($cfg, $sql);
    return @rs ? 1 : 0;
}

sub is_migrated {
    my ($cfg) = @_;
    my $sql = "SELECT * FROM migrations LIMIT 1";
    my @rs = fetch_with_perl_dbi($cfg, $sql);
    return @rs ? 1 : 0;
}

1;
