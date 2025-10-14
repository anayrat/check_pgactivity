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
use Test::More tests => 5;

my $node = pgNode->get_new_node('prod');

$node->init(data_checksums => 1);
$node->start;

### Beginning of tests ###

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

my $datadir=$node->data_dir();

### End of tests ###

# stop immediate to kill any remaining backends
$node->stop( 'immediate' );

