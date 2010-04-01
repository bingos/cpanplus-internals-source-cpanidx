use strict;
use warnings;
use Term::UI;
use Term::ReadLine;
use ExtUtils::Installed;
use File::Spec;
use File::Spec::Unix;
use File::Fetch;
use IO::Zlib;
use version;
use Module::Load::Conditional qw[check_install];
use CPANPLUS::Backend;

$ENV{PERL_MM_USE_DEFAULT} = 1; # despite verbose setting
$ENV{PERL_EXTUTILS_AUTOINSTALL} = '--defaultdeps';

my %installed;
my %cpan;
my $conf = CPANPLUS::Configure->new();
my $hosts = $conf->get_conf( 'hosts' );

foreach my $module ( sort ExtUtils::Installed->new->modules() ) {
  my $href = check_install( module => $module );
  next unless $href;
  $installed{ $module } = defined $href->{version} ? $href->{version} : 'undef';
}

my $loc = fetch_indexes('.',$hosts) or die;
populate_cpan( $loc );
foreach my $module ( sort keys %installed ) {
  # Eliminate core modules
  if ( supplied_with_core( $module ) and !$cpan{ $module } ) { 
    delete $installed{ $module };
    next;
  }
  if ( $installed{ $module } eq 'undef' and $cpan{ $module } eq 'undef' ) {
    delete $installed{ $module };
    next;
  }
  unless ( _vcmp( $cpan{ $module }, $installed{ $module} ) > 0 ) {
    delete $installed{ $module };
    next;
  }
}

# Further eliminate choices.

my $term = Term::ReadLine->new('brand');

foreach my $module ( sort keys %installed ) {
  delete $installed{ $module }
    unless $term->ask_yn(
               prompt => "Update module '$module' ?",
               default => 'y',
  );
}

$conf->set_conf( no_update => '1' );
$conf->set_conf( source_engine => 'CPANPLUS::Internals::Source::CPANIDX' );
$conf->set_conf( 'prereqs' => 1 );
my $cb = CPANPLUS::Backend->new($conf);
foreach my $mod ( sort keys %installed ) {
  my $module = $cb->module_tree($mod);
  next unless $module;
  $module->install();
}
exit 0;

sub supplied_with_core {
  my $name = shift;
  my $ver = shift || $];
  require Module::CoreList;
  return $Module::CoreList::version{ 0+$ver }->{ $name };
}

sub _vcmp {
  my ($x, $y) = @_;
  s/_//g foreach $x, $y;
  return version->parse($x) <=> version->parse($y);
}

sub populate_cpan {
  my $pfile = shift;
  my $fh = IO::Zlib->new( $pfile, "rb" ) or die "$!\n";
  my %dists;

  while (<$fh>) {
    last if /^\s*$/;
  }
  while (<$fh>) {
    chomp;
    my ($module,$version,$package_path) = split ' ', $_;
    $cpan{ $module } = $version;
  }
  return 1;
}

sub fetch_indexes {
  my ($location,$mirrors) = @_;
  foreach my $mirror ( @$mirrors ) {
    my $url = $mirror->{scheme} . '://' . 
      File::Spec::Unix->catdir( $mirror->{host}, $mirror->{path}, 'modules', '02packages.details.txt.gz' );
    my $ff = File::Fetch->new( uri => $url );
    my $stat = $ff->fetch( to => $location );
    next unless $stat;
    print "Downloaded '$url' to '$stat'\n";
    return $stat;
  }
  return;
}
