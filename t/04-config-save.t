#!/usr/bin/perl

# Saving the configuration form must:
#  - not wipe transport settings when the browser omits them (the transport
#    fieldset is disabled in "Local file" mode, and disabled controls are not
#    submitted), and
#  - write an ORACLE_PLUGIN action log entry describing each real change.

use Modern::Perl;
use Test::More tests => 8;
use CGI;
use Mojo::JSON qw(decode_json);

my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
unshift @INC, $plugin_dir;

use t::lib::TestBuilder;
use Koha::Database;
use Koha::ActionLogs;

use_ok('Koha::Plugin::Com::OpenFifth::Oracle') || print "Bail out!\n";

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;

{
    no warnings qw(redefine once);
    *Koha::Plugin::Com::OpenFifth::Oracle::go_home = sub { };
}

sub save {
    my (%params) = @_;
    my $cgi = CGI->new( join '&', map { "$_=$params{$_}" } sort keys %params );
    $plugin->{cgi} = $cgi;
    $plugin->configure;
}

Koha::ActionLogs->search( { module => 'ORACLE_PLUGIN' } )->delete;
$plugin->store_data(
    {
        transport_server         => '42',
        upload_dir_income        => '/in',
        output                   => 'upload',
        transport_days           => '',
        fund_field_mappings      => '{}',
        vendor_supplier_mappings => '{}',
        vendor_contract_mappings => '{}',
    }
);

# "Local file" save: transport fields are not submitted at all
save( save => 1, output => 'file' );

is( $plugin->retrieve_data('transport_server'),   '42',  'transport_server survives a save that omits it' );
is( $plugin->retrieve_data('upload_dir_income'),  '/in', 'upload dir survives a save that omits it' );
is( $plugin->retrieve_data('output'),             'file', 'submitted field is still saved' );

my $log = Koha::ActionLogs->search( { module => 'ORACLE_PLUGIN' } )->next;
ok( $log, 'change was written to the action log' );
my $info = decode_json( $log->info );
is_deeply( [ sort keys %$info ], ['output'], 'only the changed key is logged' );

# Deliberate clear (select posted with empty value) is honoured and logged
save( save => 1, output => 'file', transport_server => '' );
is( $plugin->retrieve_data('transport_server'), '', 'explicitly cleared transport_server is saved' );

# No change at all -> no new log entry
my $count = Koha::ActionLogs->search( { module => 'ORACLE_PLUGIN' } )->count;
save( save => 1, output => 'file', transport_server => '' );
is( Koha::ActionLogs->search( { module => 'ORACLE_PLUGIN' } )->count, $count, 'unchanged save is not logged' );

$schema->storage->txn_rollback;
