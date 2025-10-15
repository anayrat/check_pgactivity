#!/usr/bin/perl
# This program is open source, licensed under the PostgreSQL License.
# For license terms, see the LICENSE file.
#
# Copyright (C) 2012-2025: Open PostgreSQL Monitoring Development Group

use strict;
use warnings;

use lib 't/lib';
use pgNode;
use pgSession;
use Time::HiRes qw(usleep gettimeofday tv_interval);
use Test::More tests => 11;

my $node = pgNode->get_new_node('prod');

$node->init(data_checksums => 1);
$node->start;

### Beginning of tests ###

$node->psql('postgres', 'CREATE TABLE corruptme (x text);');
$node->psql('postgres', 'INSERT INTO corruptme (x) SELECT md5(i::text) FROM generate_series(1, 10000) i;');
my $file = $node->safe_psql('postgres', 'SELECT pg_relation_filepath(\'corruptme\')');
print "==> Corrupted file : $file\n";

# basic check => Returns OK
$node->command_checks_all( [
        './check_pgactivity', '--service'  => 'checksum_errors',
                              '--username' => $ENV{'USER'} || 'postgres',
                              '--format'   => 'human',
        ],
        0,
        [ qr/^Service  *: POSTGRES_CHECKSUM_ERRORS$/m,
          qr/^Message  *: 4 database\(s\) checked$/m,
          qr/^Returns  *: 0 \(OK\)$/m,
        ],
        [ qr/^$/ ],
        'basic check'
);

# Make sure the data is written on disk before Postgres is stopped
# If this checkpoint is skipped, PG will overwrite the corrupted page after
# starting WAL replay at startup.
$node->psql('postgres', 'CHECKPOINT;');
$node->stop( 'immediate' );

# Corrupt silently checksum of first page of table corruptme
# Postgres is stopped to avoid any caching
$node->corrupt_page_checksum($file, 0);

$node->start;

# Some debug output
$node->psql('postgres', "VACUUM corruptme");
#my $atari_count = $node->safe_psql('postgres', "SELECT count(*) FROM corruptme WHERE x = 'atari'");
#print "==> Count: $atari_count\n";
my $chksum_enabled = $node->safe_psql('postgres', "SELECT setting FROM pg_settings WHERE name = 'data_checksums'");
print "==> Checksums: $chksum_enabled\n";
my $chksum_failures = $node->safe_psql('postgres', "SELECT checksum_failures FROM pg_stat_database WHERE datname = current_database()");
print "==> Failures: $chksum_failures\n";


# corruption check => Returns CRITICAL
$node->command_checks_all( [
        './check_pgactivity', '--service'  => 'checksum_errors',
                              '--username' => $ENV{'USER'} || 'postgres',
                              '--format'   => 'human',
        ],
        2,
        [ qr/^Service  *: POSTGRES_CHECKSUM_ERRORS$/m,
          qr/^Message  *: postgres: 1 error\(s\)$/m,
          qr/^Perfdata *: postgres=1 warn=1 crit=1$/m,
          qr/^Returns  *: 2 \(CRITICAL\)$/m,
        ],
        [ qr/^$/ ],
        'basic check'
);

#                   'Service        : POSTGRES_CHECKSUM_ERRORS
# Returns        : 2 (CRITICAL)
# Message        : postgres: 1 error(s)
# Perfdata       : <shared objects>=0 warn=1 crit=1
# Perfdata       : postgres=1 warn=1 crit=1
# Perfdata       : template1=0 warn=1 crit=1
# Perfdata       : template0=0 warn=1 crit=1


### End of tests ###

# stop immediate to kill any remaining backends
$node->stop( 'immediate' );

