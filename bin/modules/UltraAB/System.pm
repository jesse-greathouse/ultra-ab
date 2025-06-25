#!/usr/bin/env perl

package UltraAB::System;

use strict;
use warnings;
use POSIX qw(ceil);
use Cwd qw(getcwd abs_path);
use Exporter 'import';
use IPC::Open3;
use Symbol qw(gensym);
use Sys::Info;
use Sys::Info::Constants qw(:device_cpu);
use Carp;

our @EXPORT_OK = qw(
    how_many_threads_should_i_use
    docker_is_available
    docker_db_up
    docker_db_down
    wait_for_db_healthy
    wait_for_db_stopped
);

# ====================================
# Subroutines
# ====================================

sub how_many_threads_should_i_use {
    my $info = Sys::Info->new;
    my $cpu  = $info->device('CPU');

    my $load      = $cpu->load(DCPU_LOAD_LAST_01);
    my $cpu_count = $cpu->count;

    if (defined $load && $load =~ /^\d+(\.\d+)?$/) {
        my $available_capacity = 1 - ($load / $cpu_count);
        $available_capacity = 0 if $available_capacity < 0;
        $available_capacity = 1 if $available_capacity > 1;

        my $max_threads = ceil($available_capacity * $cpu_count);
        $max_threads = 1           if $max_threads < 1;
        $max_threads = $cpu_count if $max_threads > $cpu_count;

        return $max_threads;
    } else {
        return $cpu_count;
    }
}

sub docker_is_available {
    my $status = system('docker', '--version');
    return $status == 0;
}

sub docker_db_up {
    # --- Ensure shared directories are writable for Docker containers ---
    for my $dir (qw(tmp var)) {
        if (-d $dir) {
            chmod 0777, $dir or warn "⚠️  Failed to chmod $dir to 777: $!";
        } else {
            warn "⚠️  Directory $dir does not exist; skipping chmod.";
        }
    }

    unless (docker_is_available()) {
        croak "❌ Docker is not available or not installed. Aborting.\n";
    }

    print "🚀 Starting Docker database service (ultraab_db)...\n";

    my $err = gensym;
    my $pid = open3(undef, \*CHLD_OUT, $err, 'docker', 'compose', 'up', '-d', 'db');

    waitpid($pid, 0);
    my $output = do { local $/; <CHLD_OUT> };
    my $error  = do { local $/; <$err> };

    chomp($error) if defined $error;

    if ($? != 0) {
        die "❌ Failed to start database service: $error\n";
    }

    print "⏳ Waiting for database container to become healthy...\n";
    wait_for_db_healthy();
}

sub docker_db_down {
    unless (docker_is_available()) {
        croak "❌ Docker is not available or not installed. Aborting.\n";
    }

    print "🛑 Stopping Docker database service (ultraab_db)...\n";

    my $err = gensym;
    my $pid = open3(undef, \*CHLD_OUT, $err, 'docker', 'compose', 'stop', 'db');

    waitpid($pid, 0);
    my $output = do { local $/; <CHLD_OUT> };
    my $error  = do { local $/; <$err> };

    chomp($error) if defined $error;

    if ($? != 0) {
        warn "❌ Failed to stop database service: $error\n";
        return;
    }

    print "⏳ Waiting for database container to stop...\n";
    wait_for_db_stopped();
}


sub wait_for_db_healthy {
    my $max_attempts = 15;
    my $attempt = 0;

    while ($attempt++ < $max_attempts) {
        my $status = `docker inspect --format='{{.State.Health.Status}}' ultraab_db 2>/dev/null`;
        chomp($status);
        if ($status eq 'healthy') {
            print "✅ Database container is healthy.\n";
            return 1;
        }
        print "⏳ Waiting for DB to become healthy... ($attempt)\n";
        sleep 2;
    }

    die "❌ Database did not become healthy in time.\n";
}

sub wait_for_db_stopped {
    my $max_attempts = 15;
    my $attempt = 0;

    while ($attempt++ < $max_attempts) {
        my $state = `docker inspect --format='{{.State.Status}}' ultraab_db 2>/dev/null`;
        chomp($state);

        # Docker reports "exited" or "dead" when stopped; or it fails to inspect if the container is gone
        if ($state eq 'exited' || $state eq 'dead' || $state eq '') {
            print "✅ Database container is stopped.\n";
            return 1;
        }

        print "⏳ Waiting for DB container to stop... ($attempt)\n";
        sleep 2;
    }

    die "❌ Database container did not stop in time.\n";
}

sub docker_cli_up {
    unless (docker_is_available()) {
        croak "❌ Docker is not available or not installed. Aborting.\n";
    }

    print "🚀 Starting Docker WP CLI container (ultraab_wpcli)...\n";

    my $err = gensym;
    my $pid = open3(undef, \*CHLD_OUT, $err, 'docker', 'compose', 'up', '-d', 'wpcli');

    waitpid($pid, 0);
    my $output = do { local $/; <CHLD_OUT> };
    my $error  = do { local $/; <$err> };

    chomp($error) if defined $error;

    if ($? != 0) {
        die "❌ Failed to start WP CLI container: $error\n";
    }

    print "⏳ Waiting for WP CLI container to be ready...\n";
    wait_for_cli_healthy();
}

sub wait_for_cli_healthy {
    my $max_attempts = 10;
    my $attempt = 0;

    while ($attempt++ < $max_attempts) {
        my $state = `docker inspect --format='{{.State.Status}}' ultraab_wpcli 2>/dev/null`;
        chomp($state);
        return 1 if $state eq 'running';

        print "⏳ Waiting for WP CLI container to start... ($attempt)\n";
        sleep 1;
    }

    die "❌ WP CLI container did not start in time.\n";
}

1;
