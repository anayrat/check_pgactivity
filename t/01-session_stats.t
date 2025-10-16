#!/usr/bin/perl
# This program is open source, licensed under the PostgreSQL License.
# For license terms, see the LICENSE file.
#
# Copyright (C) 2012-2025: Open PostgreSQL Monitoring Development Group

use strict;
use warnings;

use lib 't/lib';
use pgNode;
use TestLib ();
use Test::More tests => 17;

my $node = pgNode->get_new_node('prod');
my $pga_data = "$TestLib::tmp_check/pga.data";

$node->init;
$node->start;

### Beginning of tests ###

# TODO: does not work on PG13 and less.
#
# First check. Returns no perfdata
$node->command_checks_all( [
    './check_pgactivity', '--service'     => 'session_stats',
                          '--username'    => $ENV{'USER'} || 'postgres',
                          '--format'      => 'human',
                          '--status-file' => $pga_data,
    ],
    0,
    [
      qr/^Service  *: POSTGRES_SESSION_STATS$/m,
      qr/^Returns  *: 0 \(OK\)$/m,
      qr/^Message  *: First call$/m,
    ],
    [ qr/^$/ ],
    'first basic check'
);

# Second check. Returns OK and perfdata
$node->command_checks_all( [
    './check_pgactivity', '--service'     => 'session_stats',
                          '--username'    => $ENV{'USER'} || 'postgres',
                          '--format'      => 'human',
                          '--status-file' => $pga_data,
    ],
    0,
    [
      qr/^Service  *: POSTGRES_SESSION_STATS$/m,
      qr/^Returns  *: 0 \(OK\)$/m,
      qr/^Message  *: Number of sessions per second for all databases: [0-9][.0-9]*$/m,
      qr/^Perfdata *: template1_session_rate=0 sessions\/s$/m,
      qr/^Perfdata *: template1_session_time=0ms$/m,
      qr/^Perfdata *: template1_active_time=0ms$/m,
      qr/^Perfdata *: template1_idle_in_transaction_time=0ms$/m,
      qr/^Perfdata *: template1_sessions_killed=0$/m,
      qr/^Perfdata *: template1_sessions_abandoned=0$/m,
      qr/^Perfdata *: template1_sessions_fatal=0$/m,
    ],
    [ qr/^$/ ],
    'second basic check'
);

### End of tests ###

# stop immediate to kill any remaining backends
$node->stop('immediate');
