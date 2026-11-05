#!/usr/bin/perl

# cronjob_nightly must:
#  - record *why* a run failed (transport error text) in plugin_oracle_cron_runs.message
#  - record a failed run when the configured transport is missing
#  - reach back to the last successful run so failed runs are retried
#  - leave the run log clean (no message) on success

use Modern::Perl;
use Test::More tests => 9;
use Test::MockModule;

my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
unshift @INC, $plugin_dir;

use C4::Context;
use Koha::Database;
use Koha::DateUtils qw(dt_from_string);

use_ok('Koha::Plugin::Com::OpenFifth::Oracle') || print "Bail out!\n";

my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;

# DDL implicitly commits, so do it before opening the transaction.
$plugin->install;
my $dbh = C4::Context->dbh;
ok( $dbh->selectrow_arrayref(q{SHOW COLUMNS FROM plugin_oracle_cron_runs LIKE 'message'}), 'cron run table has a message column' );

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

# --- fakes ---------------------------------------------------------------
{

    package FakeMessage;
    sub new     { my ( $c, %a ) = @_; bless {%a}, $c }
    sub type    { $_[0]{type} }
    sub payload { $_[0]{payload} }
    sub message { $_[0]{message} }

    package FakeTransport;
    sub new            { bless { connect => $_[1] }, $_[0] }
    sub connect        { $_[0]{connect} }
    sub change_directory { 1 }
    sub upload_file    { 1 }
    sub status         { undef }
    sub object_messages {
        [ FakeMessage->new( type => 'error', payload => { error => 'Authentication failed' }, message => 'connect' ) ];
    }
}

my $transport;
my $mock_transports = Test::MockModule->new('Koha::File::Transports');
$mock_transports->mock( find => sub { $transport } );

my @windows;
my $mock_plugin = Test::MockModule->new('Koha::Plugin::Com::OpenFifth::Oracle');
$mock_plugin->mock(
    _generate_report => sub {
        my ( $self, $start, $end, $type ) = @_;
        push @windows, [ $start->ymd, $end->ymd, $type ];
        return $type eq 'invoices' ? "report-$type\n" : undef;
    }
);
$mock_plugin->mock( _mark_invoices_submitted => sub { } );
$mock_plugin->mock( _mark_cashups_submitted  => sub { } );

sub last_run {
    return $dbh->selectrow_hashref('SELECT * FROM plugin_oracle_cron_runs ORDER BY id DESC LIMIT 1');
}

$dbh->do('DELETE FROM plugin_oracle_cron_runs');
$plugin->store_data(
    {
        transport_days  => '0,1,2,3,4,5,6',
        output          => 'upload',
        transport_server => '7',
        last_cron_run   => '',
    }
);

# --- failed connect is explained ------------------------------------------
$transport = FakeTransport->new(0);
{
    local $SIG{__WARN__} = sub { };
    ok( !$plugin->cronjob_nightly, 'run reports failure when connect fails' );
}
my $run = last_run();
is( $run->{status}, 'failed', 'failed run logged' );
like( $run->{message}, qr/invoices: connect failed: Authentication failed/, 'failure reason recorded' );

# --- missing transport is logged, not silent -------------------------------
$transport = undef;
$plugin->cronjob_nightly;
$run = last_run();
like( $run->{message}, qr/no longer exists/, 'missing transport recorded as a failed run' );

# --- retry reaches back to last successful run -----------------------------
my $ten_days_ago = dt_from_string()->subtract( days => 10 );
$plugin->store_data( { last_cron_run => $ten_days_ago->strftime('%Y-%m-%d 02:00:00') } );
$transport = FakeTransport->new(1);
@windows = ();
ok( $plugin->cronjob_nightly, 'run succeeds with a working transport' );
is( $windows[0][0], $ten_days_ago->ymd, 'window starts at the last successful run' );

# --- but never further than 30 days ---------------------------------------
$plugin->store_data( { last_cron_run => dt_from_string()->subtract( days => 90 )->strftime('%Y-%m-%d 02:00:00') } );
@windows = ();
$plugin->cronjob_nightly;
is( $windows[0][0], dt_from_string()->subtract( days => 30 )->ymd, 'window is capped at 30 days' );

$schema->storage->txn_rollback;
