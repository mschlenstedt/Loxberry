package Embed::Persistent;

use strict;
use FileHandle ();
use Carp 'croak';
use vars qw($VERSION);
$VERSION = (qw$Revision: 1.10 $)[1];

sub valid_package_name {
    my($self, $string) = @_;

    # Escape everything into valid perl identifiers
    $string =~ s/([^A-Za-z0-9\/])/sprintf("_%2x",unpack("C",$1))/eg;

    # second pass cares for slashes and words starting with a digit
    $string =~ s{
			  (/)        # directory
			  (\d?)      # package's first character
			 }[
			   "::" . ($2 ? sprintf("_%2x",unpack("C",$2)) : "")
			  ]egx;

    return "Embed" . $string;
}

sub cached {
    my($self, $filename, $package, $mtime) = @_;
    $$mtime = -M $filename;
    if(defined $self->{FileCache}{$package}{mtime}
       &&
       $self->{FileCache}{$package}{mtime} <= $$mtime) {
	return 1;
    }
    return 0;
}

sub cache {
    my($self, $package, $mtime) = @_;
    $self->{FileCache}{$package}{mtime} = $mtime;
}

sub uncache {
    my($self, $package) = @_;
    delete $self->{FileCache}{$package};
}

sub new {
    my $class = shift;
    return bless {
	FileCache => {
	},
	@_,
    } => $class;
}

sub prepare {
    my($self, $filename, $package) = @_;
    my $fh = FileHandle->new($filename) or die "open '$filename' $!";
    local($/) = undef;
    my $sub = <$fh>;
    $fh->close;
    #new object, same class
    return bless {
	CODE => $sub,
	FILENAME => $filename,
	PACKAGE => $package,
    }, ref($self) || $self;
}

sub compile {
    my($self) = @_;
    my $code = $self->{CODE};
    my $package = $self->{PACKAGE};
    my $eval = qq{package $package; sub handler { $code; }};
    {
	# hide our variables within this block
	my($package,$code);
	eval $eval;
    }
    croak $@ if $@;
}

sub run {
    my($self) = @_;
    eval {$self->{PACKAGE}->handler;};
    croak $@ if $@;
}

#borrowed from Safe.pm
sub delete {
    my($self) = @_;
    my $pkg = $self->{PACKAGE};
    $self->uncache($pkg);
    my ($stem, $leaf);

    no strict 'refs';
    $pkg = "main::$pkg\::";	# expand to full symbol table name
    ($stem, $leaf) = $pkg =~ m/(.*::)(\w+::)$/;

    my $stem_symtab = *{$stem}{HASH};

    delete $stem_symtab->{$leaf};
}

sub eval_file {
    my($self, $filename, $delete) = @_;
    my $package = $self->valid_package_name($filename);
    my $mtime;
    if($self->cached($filename, $package, \$mtime)) 
    {
	# we have compiled this subroutine already, 
	# it has not been updated on disk, nothing left to do
  	print STDERR "already compiled $package->handler\n" if $self->{DEBUG};
    }
    else {
	my $code = $self->prepare($filename, $package); 
	#wrap the code into a subroutine inside our unique package
	$code->compile;
	#cache it unless we're cleaning out each time
	$self->cache($package, $mtime) unless $delete;
	$code->run;
	$code->delete if $delete;
    }
    #take a look if you want
    #print Devel::Symdump->rnew($package)->as_string, $/;
}

1;

__END__




