package CPANPLUS::Internals::Source::CPANIDX::Tie;

use strict;
use warnings;

use CPANPLUS::Error;
use CPANPLUS::Module;
use CPANPLUS::Module::Fake;
use CPANPLUS::Module::Author::Fake;
use CPANPLUS::Internals::Constants;


use Params::Check               qw[check];
use Module::Load::Conditional   qw[can_load];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

use File::Fetch;
use Parse::CPAN::Meta;

use Data::Dumper;
$Data::Dumper::Indent = 1;

require Tie::Hash;
use vars qw[@ISA];
push @ISA, 'Tie::StdHash';

sub TIEHASH {
    my $class = shift;
    my %hash  = @_;
    
    my $tmpl = {
        idx     => { required => 1 },
        table   => { required => 1 },
        key     => { required => 1 },
        cb      => { required => 1 },
        offset  => { default  => 0 },
    };
    
    my $args = check( $tmpl, \%hash ) or return;
    my $obj  = bless { %$args, store => {} } , $class;

    return $obj;
}    

=for comment

        CREATE TABLE author (
            id INTEGER PRIMARY KEY AUTOINCREMENT,

            author  varchar(255),
            email   varchar(255),
            cpanid  varchar(255)

  cpan_id: BINGOS
  email: chris@bingosnet.co.uk
  fullname: 'Chris Williams'

        CREATE TABLE module (
            id INTEGER PRIMARY KEY AUTOINCREMENT,

            module      varchar(255),
            version     varchar(255),
            path        varchar(255),
            comment     varchar(255),
            author      varchar(255),
            package     varchar(255),
            description varchar(255),
            dslip       varchar(255),
            mtime       varchar(255)

  cpan_id: RCAPUTO
  dist_file: R/RC/RCAPUTO/POE-1.287.tar.gz
  dist_name: POE
  dist_vers: 1.287
  mod_name: POE
  mod_vers: 1.287

=cut

sub FETCH {
    my $self    = shift;
    my $key     = shift or return;
    my $idx     = $self->{idx};
    my $cb      = $self->{cb};
    my $table   = $self->{table};
    
    my $lkup = $table eq 'module' ? 'mod' : 'auth';
    
    ### did we look this one up before?
    if( my $obj = $self->{store}->{$key} ) {
        return $obj;
    }
    
    my $ff = File::Fetch->new( uri => $self->{idx} . "yaml/$lkup/" . $key );
    return unless $ff;

    my $str;
    return unless $ff->fetch( to => \$str );

    my $res;
    eval { $res = Parse::CPAN::Meta::Load( $str ); };
    return unless $res;

    my $href = $res->[0];
    
    ### no results?
    return unless keys %$href;
    
    ### expand author if needed
    ### XXX no longer generic :(
    if( $table eq 'module' ) {
        $href->{author} = delete $href->{cpan_id};
        $href->{module} = delete $href->{mod_name};
        $href->{version} = delete $href->{mod_vers};
        my ($author, $package) = $href->{dist_file} =~
                m|  (?:[A-Z\d-]/)?
                    (?:[A-Z\d-]{2}/)?
                    ([A-Z\d-]+) (?:/[\S]+)?/
                    ([^/]+)$
                |xsg;

        ### remove file name from the path
        $href->{dist_file} =~ s|/[^/]+$||;
        $href->{path} = join '/', 'authors/id', delete $href->{dist_file};
        $href->{package} = $package;
        $href->{comment} = $href->{description} = $href->{dslip} = $href->{mtime} = '';
        delete $href->{$_} for qw(dist_vers dist_name);
        $href->{author} = $cb->author_tree( $href->{author} ) or return;
    }
    else {
        $href->{author} = delete $href->{fullname};
        $href->{cpanid} = delete $href->{cpan_id};
    }

    my $class = {
        module  => 'CPANPLUS::Module',
        author  => 'CPANPLUS::Module::Author',
    }->{ $table };

    my $obj = $self->{store}->{$key} = $class->new( %$href, _id => $cb->_id );   
    
    return $obj;
}

sub STORE { 
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    
    $self->{store}->{$key} = $val;
}

sub FIRSTKEY {
    my $self = shift;
    my $idx  = $self->{'idx'};
    my $table   = $self->{table};

    my $lkup = $table eq 'module' ? 'mod' : 'auth';

    my $ff = File::Fetch->new( uri => $idx . "yaml/${lkup}keys" );
    return unless $ff;

    my $str;
    return unless $ff->fetch( to => \$str );

    my $res;
    eval { $res = Parse::CPAN::Meta::Load( $str ); };
    return unless $res;

    my $ref = $table eq 'module' ? 'mod_name' : 'cpan_id';
    @{ $self->{keys} } = 
      map { $_->{$ref} } @$res;

    $self->{offset} = 0;

    return $self->{keys}->[0];
}

sub NEXTKEY {
    my $self = shift;
    my $idx  = $self->{'idx'};
    my $table   = $self->{table};

    my $key = $self->{keys}->[ $self->{offset} ];
    
    $self->{offset} +=1;

    if ( wantarray ) {
      ### use each() semantics
      my $val = $self->FETCH( $key );
      return ( $key, $val );
    }
    return $key;
}

1;

sub EXISTS   { !!$_[0]->FETCH( $_[1] ) }

### intentionally left blank
sub DELETE   {  }
sub CLEAR    {  }

