use strict;
use warnings;
use CPANPLUS::Backend;
use CPANPLUS::Internals::Source::CPANIDX::Tie;

$|=1;

use constant CPANIDX => 'http://cpanidx.bingosnet.co.uk/cpandb/';

my $self = CPANPLUS::Backend->new();

my %at;
tie %at, 'CPANPLUS::Internals::Source::CPANIDX::Tie',
 idx => CPANIDX, table => 'author', 
 key => 'cpanid',            cb => $self;
                
        

my %mt;
tie %mt, 'CPANPLUS::Internals::Source::CPANIDX::Tie',
 idx => CPANIDX, table => 'module', 
 key => 'module',            cb => $self;

my $mod = $mt{'POE'};

use Data::Dumper;
$Data::Dumper::Indent=1;

print Dumper( $mod );

print $_, "\n" for keys %mt;
