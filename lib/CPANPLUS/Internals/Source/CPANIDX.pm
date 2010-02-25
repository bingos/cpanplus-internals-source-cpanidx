package CPANPLUS::Internals::Source::CPANIDX;

use strict;
use warnings;

use base 'CPANPLUS::Internals::Source';

use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;
use CPANPLUS::Internals::Source::CPANIDX::Tie;

use Data::Dumper;

use Params::Check               qw[allow check];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

use constant TXN_COMMIT => 1000;
use constant CPANIDX => 'http://cpanidx.bingosnet.co.uk/cpandb/';

=head1 NAME 

CPANPLUS::Internals::Source::CPANIDX - CPANIDX implementation

=cut

{
    sub _init_trees {
        my $self = shift;
        my $conf = $self->configure_object;
        my %hash = @_;
    
        my($path,$uptodate,$verbose,$use_stored);
        my $tmpl = {
            path        => { default => $conf->get_conf('base'), store => \$path },
            verbose     => { default => $conf->get_conf('verbose'), store => \$verbose },
            uptodate    => { required => 1, store => \$uptodate },
            use_stored  => { default  => 1, store => \$use_stored },
        };
    
        check( $tmpl, \%hash ) or return;

        ### set up the author tree
        {   my %at;
            tie %at, 'CPANPLUS::Internals::Source::CPANIDX::Tie',
                idx => CPANIDX, table => 'author', 
                key => 'cpanid',            cb => $self;
                
            $self->_atree( \%at  );
        }

        ### set up the author tree
        {   my %mt;
            tie %mt, 'CPANPLUS::Internals::Source::CPANIDX::Tie',
                idx => CPANIDX, table => 'module', 
                key => 'module',            cb => $self;

            $self->_mtree( \%mt  );
        }
        
        return 1;        
        
    }
    
    sub _standard_trees_completed   { return 1 }
    sub _custom_trees_completed     { return }
    ### finish transaction
    sub _finalize_trees             { return 1 }

    ### saves current memory state, but not implemented in sqlite
    sub _save_state                 { 
        error(loc("%1 has not implemented writing state to disk", __PACKAGE__)); 
        return;
    }

    sub _add_author_object {
        return 1;
     }

    sub _add_module_object {
        return 1;
    }

{   my %map = (
        _source_search_module_tree  
            => [ module => module => 'CPANPLUS::Module' ],
        _source_search_author_tree  
            => [ author => cpanid => 'CPANPLUS::Module::Author' ],
    );        

    while( my($sub, $aref) = each %map ) {
        no strict 'refs';
        
        my($table, $key, $class) = @$aref;
        *$sub = sub {
            my $self = shift;
            my %hash = @_;
            my $dbh  = $self->__sqlite_dbh;
            
            my($list,$type);
            my $tmpl = {
                allow   => { required   => 1, default   => [ ], strict_type => 1,
                             store      => \$list },
                type    => { required   => 1, allow => [$class->accessors()],
                             store      => \$type },
            };
        
            check( $tmpl, \%hash ) or return;
        
        
            ### we aliased 'module' to 'name', so change that here too
            $type = 'module' if $type eq 'name';
        
            my $res = $dbh->query( "SELECT * from $table" );
            
            my $meth = $table .'_tree';
            my @rv = map  { $self->$meth( $_->{$key} ) } 
                     grep { allow( $_->{$type} => $list ) } $res->hashes;
        
            return @rv;
        }
    }
}

1;
