use strict;
use warnings;
use File::Fetch;
use Parse::CPAN::Meta;

use constant URL => 'http://cpanidx.bingosnet.co.uk/cpandb/';

my $mod = shift or die;

my $ff = File::Fetch->new( uri => URL . 'yaml/mod/' . $mod );
die unless $ff;

my $str;
die unless $ff->fetch( to => \$str );

my $data;

eval { $data = Parse::CPAN::Meta::Load( $str ); };

use Data::Dumper;
$Data::Dumper::Indent=1;

print Dumper( $data );
