package File::Samba;

use strict;
use warnings;
use Carp qw(cluck croak confess);
use Data::Dump qw(dump);

require Exporter;

our @ISA = qw(Exporter);

#
# We all for several exports
#
our $VERSION = '0.03';
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
#
# Exported Functions by request
#
@EXPORT_OK = qw(
version
keys
value
listShares
deleteShare
createShare
sectionParameter
globalParameter
load
save
);  # symbols to export on request

=head1 Object Methods

=head2 new([config file])

Optionally a file can be specifided in the constructor to load the file
on creation.

Returns a new Samba Object

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{_global} = {};
    $self->{_section} = {};
    $self->{_version} = 2;
    eval 
    { 
			while(<DATA>)
			{
	    	chomp;
      	next if /^#/;
	    	my ($st,$vers,$cmd) = split(/:/);
      	if($cmd && $vers && $st)
      	{
          chomp($cmd);
          $self->{_VALID}->{$st}->{"v$vers"}->{$cmd} = "1";
      	}
      	last if /__END__/;
			}
    };    

    bless ($self, $class);
    if(@_)
    {
        $self->load(shift);        
    }

    return $self;
}

=head2 version([version])

Set or get the version of this smb.conf your want to edit
the load method tries to determine the smb.conf version based on the keys
it find

Params:
	[Optional] the version number
Returns:
	the current version (either 2 or 3)
Example:
	if($obj->version == 3)
	{
		# do Samba 3 options
	}

=cut

sub version
{
    my $self = shift;
    if (@_)
    {
        my $ver = shift;
        croak "Samba version 2 or 3 only " if($ver < 2 || $ver > 3);
        $self->{_version} = $ver;
        # do we strip out bad values? NOPE
    }
    return $self->{_version};
}

=head2 keys(section)

Get a list of key for a given section, use 'global' for the globl section

Params:
	section to list
Returns:
	a sorted list of section keys
Example:
	my @keys = $smb->keys('some section');

=cut

sub keys
{
    my $self = shift;
    my $section = shift;
    if($section eq "global")
    {
        return sort(CORE::keys(%{$self->{_global}}));
    }
    else
    {
        return sort(CORE::keys(%{$self->{_section}->{$section}}));
    }
}

=head2 value(section,key)

Get the value associated with a key in a given section (READ ONLY)

Params:
	section to list
	key to read
Returns:
	the value associated with the key/section combination or undef if the key/section
	does nto exists
Example:
	my $value = $smb->keys('some section','some key');

=cut

sub value
{
    my $self = shift;
    my $section = shift;
    my $key = shift;
    if($section eq "global")
    {
        return $self->{_global}->{$key};
    }
    else
    {
        return $self->{_section}->{$section}->{$key};
    }    
}

=head2 listShares()

Get a list of shares defined in the smb.conf file EXCLUDING the global section

Params:
	none
Returns:
	a sorted list of section names
Example:
	my @list = $smb->listShares;

=cut

sub listShares
{
    my $self = shift;
    my @list = CORE::keys(%{$self->{_section}});
    return sort(@list);
}

=head2 deleteShare(share name)

Delete a given share, this method can't delete the global section

Params:
	the share to delete
Returns:
	none
Example:
	$smb->deleteShare('some share');

=cut


sub deleteShare
{
    my $self = shift;
    my $share = shift;
    delete $self->{_section}->{$share};
}

=head2 createShare(share name)

Create a share with a given name

Params:
	the share to create
Returns:
	none
Example:
	$smb->createShare('some share');
Exceptions:
	If you try to create a share called global, the method will croak

=cut

sub createShare
{
    my $self = shift;
    my $share = shift;
    if($share eq 'global')
    {
	croak("You can't create a share called global");
    }
    $self->{_section}->{$share} = {} unless exists $self->{_section}->{$share};
}

=head2 sectionParameter(section,key,[value])

Get or set a key in a given section, if value is not sepecifed this methods performs
a lookup, otherwise it performs an edit

Params:
	the section you wish to modify/view
	the key to view
	the value to set
Returns:
	the value set or read
Example:
	$smb->sectionParameter('homes','guest ok','yes');
Exceptions:
	The key you pass in for a 'Set' operrtion will be checked against a list of valid
	key names, based on the smb.conf version. Setting an invalid key will result if croak

=cut


sub sectionParameter
{
    my $self = shift;
    my $section = shift;
    my $param = shift;
    if(@_)
    {
        my $value = shift;
        my $version = $self->{_version};
        if($self->{_VALID}->{section}->{"v$version"}->{$param})
        {
            $self->{_section}->{$section}->{$param} = $value;
        }
        else
        {
            croak("Invalid section key \"$param\" for samba version $version");
        }
    }
    return $self->{_section}->{$section}->{$param};
}

=head2 globalParameter(key,[value])

Get or set a key in the global section, if value is not sepecifed this methods performs
a lookup, otherwise it performs an edit

Params:
	the key to view
	the value to set
Returns:
	the value set or read
Example:
	$smb->globalParameter('homes','guest ok','yes');
Exceptions:
	The key you pass in for a 'Set' operrtion will be checked against a list of valid
	key names, based on the smb.conf version. Setting an invalid key will result if croak

=cut

sub globalParameter
{
    my $self = shift;
    my $param = shift;
    if(@_)
    {
        my $value = shift;
        my $version = $self->{_version};
        if($self->{_VALID}->{global}->{"v$version"}->{$param} || $self->{_VALID}->{section}->{"v$version"}->{$param})
        {
            $self->{_global}->{$param} = $value;
        }
        else
        {
            croak("Invalid key \"$param\" for samba version $version");
        }
    }
    return $self->{_global}->{$param};
}

=head2 load(filename)

Read a smb.conf file from disk, and parse it. The version will be identified as best as possible
but may not be correct, you should use version method after calling load to make sure the version
detected correctly

Params:
	the smb.conf file to load
Returns:
	none
Example:
	$smb->load('/etc/samba/smbconf');
Exceptions:
	If the file does not exist croak

=cut


sub load
{
    my $self = shift;
    my $file = shift;
    cluck("No such file $file") unless -e $file;
    # Load the file and run
    open(FH,$file);
    my $isGlobal;
    my $lastSection;
    # guess version 2 we need a good wy to see if version 3
    my $lastDetVersion = 2;
    while(<FH>)
    {
        chomp;
        next if /^;|^#/;
        next if /^\s+$/;
        next if length($_) <= 1;
        s/\t//;
        s/\n//;
        s/^\s+//;
        s/\s+$//;
        next if /^;/;
        if(/\[global\]/i)
        {
            $isGlobal = 1;
        }
        elsif(/\[(\w+)\]/)
        {
            $isGlobal = 0;
            $lastSection = $1;
        }
        else
        {
            my($key,$value) = split('=',$_,2);
            $key =~ s/\s+$//;
            $value =~ s/^\s+//;
            if($isGlobal)
            {
                $self->{_global}->{$key}=$value;
                my ($v2,$v3);
                $v2 = $self->{_VALID}->{global}->{v2}->{$key};
                $v3 = $self->{_VALID}->{global}->{v3}->{$key};
                if($v3 && !$v2)
                {
                    $self->{_version} = 3;
                }
            }
            else
            {
                if($self->{_section}->{$lastSection})
                {
                    $self->{_section}->{$lastSection}->{$key} = $value;
                }
                else
                {
                    $self->{_section}->{$lastSection} = {};
                    $self->{_section}->{$lastSection}->{$key} = $value;                    
                }
            }
        }
    }
    close(FH);
    #print "[Global] \n",dump($self->{_global});
    #print "\n[Sections] \n",dump($self->{_section});
    #print "\n[Version] \n",$self->{_version};
}

=head2 save(filename)

Save the current inmemory smb.conf file

Params:
	the file to save to
Returns:
	none
Example:
	$smb->save('/home/test.conf');

=cut


sub save
{
    my $self = shift;
    my $outputFile = shift;
    # Save it now !!
    open(WH,">$outputFile");
    # Ok write Header
    print WH "################################################################################\n";
    print WH "#                      Generate By File::Samba $VERSION                            #\n";
    print WH "# This is the main Samba configuration file. You should read the               #\n";
    print WH "# smb.conf(5) manual page in order to understand the options listed            #\n";
    print WH "# here.                                                                        #\n";
    print WH "# Any line which starts with a ; (semi-colon) or a # (hash)                    #\n"; 
    print WH "# is a comment and is ignored. In this example we will use a #                 #\n";
    print WH "# for commentry and a ; for parts of the config file that you                  #\n";
    print WH "# may wish to enable                                                           #\n";
    print WH "#                                                                              #\n";
    print WH "# NOTE: Whenever you modify this file you should run the command \"testparm\"    #\n";
    print WH "# to check that you have not made any basic syntactic errors.                  #\n";
    print WH "################################################################################\n";
    print WH ";========================= Global Settings =====================================\n";
    # write global section
    print WH "[global]\n";
    foreach my $key ($self->keys('global'))
    {
        print WH "\t$key = ",$self->{_global}->{$key},"\n";
    }
    print WH "\n";
    print WH ";=========================== Share Settings =====================================\n";
    my @sList = $self->listShares;
    foreach my $skey (@sList)
    {
        print WH "[$skey]\n";
        if($skey eq "homes" || $skey eq "printers" )
        {
            print WH "\t;special shares for samba see smb.conf(5)\n";
        }
        my @skList = $self->keys($skey);
        foreach my $subK (@skList)
        {
            print WH "\t$subK = ",$self->{_section}->{$skey}->{$subK},"\n";
        }
        print WH "\n";
    }
    close(WH);
}

1;
__DATA__
# Samba version 2
global:2:add printer command
global:2:add share command
global:2:add user script
global:2:allow trusted domains
global:2:announce as
global:2:announce version
global:2:auto services
global:2:bind interfaces only
global:2:browse list
global:2:change notify timeout
global:2:change share command
global:2:character set
global:2:client code page
global:2:code page directory
global:2:coding system
global:2:config file
global:2:deadtime
global:2:debug hires timestamp
global:2:debug pid
global:2:debug timestamp
global:2:debug uid
global:2:debuglevel
global:2:default
global:2:default service
global:2:delete printer command
global:2:delete share command
global:2:delete user script
global:2:dfree command
global:2:disable spoolss
global:2:dns proxy
global:2:domain admin group
global:2:domain guest group
global:2:domain logons
global:2:domain master
global:2:encrypt passwords
global:2:enhanced browsing
global:2:enumports command
global:2:getwd cache
global:2:hide local users
global:2:hide unreadable
global:2:homedir map
global:2:host msdfs
global:2:hosts equiv
global:2:interfaces
global:2:keepalive
global:2:kernel oplocks
global:2:lanman auth
global:2:large readwrite
global:2:ldap admin dn
global:2:ldap filter
global:2:ldap port
global:2:ldap server
global:2:ldap ssl
global:2:ldap suffix
global:2:lm announce
global:2:lm interval
global:2:load printers
global:2:local master
global:2:lock dir
global:2:lock directory
global:2:lock spin count
global:2:lock spin time
global:2:pid directory
global:2:log file
global:2:log level
global:2:logon drive
global:2:logon home
global:2:logon path
global:2:logon script
global:2:lpq cache time
global:2:machine password timeout
global:2:mangled stack
global:2:mangling method
global:2:map to guest
global:2:max disk size
global:2:max log size
global:2:max mux
global:2:max open files
global:2:max protocol
global:2:max smbd processes
global:2:max ttl
global:2:max wins ttl
global:2:max xmit
global:2:message command
global:2:min passwd length
global:2:min password length
global:2:min protocol
global:2:min wins ttl
global:2:name resolve order
global:2:netbios aliases
global:2:netbios name
global:2:netbios scope
global:2:nis homedir
global:2:nt pipe support
global:2:nt smb support
global:2:nt status support
global:2:null passwords
global:2:obey pam restrictions
global:2:oplock break wait time
global:2:os level
global:2:os2 driver map
global:2:pam password change
global:2:panic action
global:2:passwd chat
global:2:passwd chat debug
global:2:passwd program
global:2:password level
global:2:password server
global:2:prefered master
global:2:preferred master
global:2:preload
global:2:printcap
global:2:printcap name
global:2:printer driver file
global:2:protocol
global:2:read bmpx
global:2:read raw
global:2:read size
global:2:remote announce
global:2:remote browse sync
global:2:restrict anonymous
global:2:root
global:2:root dir
global:2:root directory
global:2:security
global:2:server string
global:2:show add printer wizard
global:2:smb passwd file
global:2:socket address
global:2:socket options
global:2:source environment
global:2:ssl
global:2:ssl CA certDir
global:2:ssl CA certFile
global:2:ssl ciphers
global:2:ssl client cert
global:2:ssl client key
global:2:ssl compatibility
global:2:ssl egd socket
global:2:ssl entropy bytes
global:2:ssl entropy file
global:2:ssl hosts
global:2:ssl hosts resign
global:2:ssl require clientcert
global:2:ssl require servercert
global:2:ssl server cert
global:2:ssl server key
global:2:ssl version
global:2:stat cache
global:2:stat cache size
global:2:strip dot
global:2:syslog
global:2:syslog only
global:2:template homedir
global:2:template shell
global:2:time offset
global:2:time server
global:2:timestamp logs
global:2:total print jobs
global:2:unix extensions
global:2:unix password sync
global:2:update encrypted
global:2:use mmap
global:2:use rhosts
global:2:username level
global:2:username map
global:2:utmp
global:2:utmp directory
global:2:valid chars
global:2:winbind cache time
global:2:winbind enum users
global:2:winbind enum groups
global:2:winbind gid
global:2:winbind separator
global:2:winbind uid
global:2:winbind use default domain
global:2:wins hook
global:2:wins proxy
global:2:wins server
global:2:wins support
global:2:workgroup
global:2:write raw
section:2:admin users
section:2:allow hosts
section:2:available
section:2:blocking locks
section:2:block size
section:2:browsable
section:2:browseable
section:2:case sensitive
section:2:casesignames
section:2:comment
section:2:copy
section:2:create mask
section:2:create mode
section:2:csc policy
section:2:default case
section:2:default devmode
section:2:delete readonly
section:2:delete veto files
section:2:deny hosts
section:2:directory
section:2:directory mask
section:2:directory mode
section:2:directory security mask
section:2:dont descend
section:2:dos filemode
section:2:dos filetime resolution
section:2:dos filetimes
section:2:exec
section:2:fake directory create times
section:2:fake oplocks
section:2:follow symlinks
section:2:force create mode
section:2:force directory mode
section:2:force directory security mode
section:2:force group
section:2:force security mode
section:2:force unknown acl user
section:2:force user
section:2:fstype
section:2:group
section:2:guest account
section:2:guest ok
section:2:guest only
section:2:hide dot files
section:2:hide files
section:2:hosts allow
section:2:hosts deny
section:2:include
section:2:inherit acls
section:2:inherit permissions
section:2:invalid users
section:2:level2 oplocks
section:2:locking
section:2:lppause command
section:2:lpq command
section:2:lpresume command
section:2:lprm command
section:2:magic output
section:2:magic script
section:2:mangle case
section:2:mangled map
section:2:mangled names
section:2:mangling char
section:2:map archive
section:2:map hidden
section:2:map system
section:2:max connections
section:2:max print jobs
section:2:min print space
section:2:msdfs root
section:2:nt acl support
section:2:only guest
section:2:only user
section:2:oplock contention limit
section:2:oplocks
section:2:path
section:2:posix locking
section:2:postexec
section:2:postscript
section:2:preexec
section:2:preexec close
section:2:preserve case
section:2:print command
section:2:print ok
section:2:printable
section:2:printer
section:2:printer admin
section:2:printer driver
section:2:printer driver location
section:2:printer name
section:2:printing
section:2:profile acls
section:2:public
section:2:queuepause command
section:2:queueresume command
section:2:read list
section:2:read only
section:2:root postexec
section:2:root preexec
section:2:root preexec close
section:2:security mask
section:2:set directory
section:2:share modes
section:2:short preserve case
section:2:status
section:2:strict allocate
section:2:strict locking
section:2:strict sync
section:2:sync always
section:2:use client driver
section:2:use sendfile
section:2:user
section:2:username
section:2:users
section:2:valid users
section:2:veto files
section:2:veto oplock files
section:2:vfs object
section:2:vfs options
section:2:volume
section:2:wide links
section:2:writable
section:2:write cache size
section:2:write list
section:2:write ok
section:2:writeable
# Samba Version 3
global:3:abort shutdown script
global:3:add group script
global:3:add machine script
global:3:addprinter command
global:3:add share command
global:3:add user script
global:3:add user to group script
global:3:algorithmic rid base
global:3:allow trusted domains
global:3:announce as
global:3:announce version
global:3:auth methods
global:3:auto services
global:3:bind interfaces only
global:3:browse list
global:3:change notify timeout
global:3:change share command
global:3:client lanman auth
global:3:client ntlmv2 auth
global:3:client plaintext auth
global:3:client schannel
global:3:client signing
global:3:client use spnego
global:3:config file
global:3:deadtime
global:3:debug hires timestamp
global:3:debuglevel
global:3:debug pid
global:3:debug timestamp
global:3:debug uid
global:3:default
global:3:default service
global:3:delete group script
global:3:deleteprinter command
global:3:delete share command
global:3:delete user from group script
global:3:delete user script
global:3:dfree command
global:3:disable netbios
global:3:disable spoolss
global:3:display charset
global:3:dns proxy
global:3:domain logons
global:3:domain master
global:3:dos charset
global:3:enable rid algorithm
global:3:encrypt passwords
global:3:enhanced browsing
global:3:enumports command
global:3:get quota command
global:3:getwd cache
global:3:guest account
global:3:hide local users
global:3:homedir map
global:3:host msdfs
global:3:hostname lookups
global:3:hosts equiv
global:3:idmap backend
global:3:idmap gid
global:3:idmap uid
global:3:include
global:3:interfaces
global:3:keepalive
global:3:kernel change notify
global:3:kernel oplocks
global:3:lanman auth
global:3:large readwrite
global:3:ldap admin dn
global:3:ldap delete dn
global:3:ldap filter
global:3:ldap group suffix
global:3:ldap idmap suffix
global:3:ldap machine suffix
global:3:ldap passwd sync
global:3:ldap port
global:3:ldap server
global:3:ldap ssl
global:3:ldap suffix
global:3:ldap user suffix
global:3:lm announce
global:3:lm interval
global:3:load printers
global:3:local master
global:3:lock dir
global:3:lock directory
global:3:lock spin count
global:3:lock spin time
global:3:log file
global:3:log level
global:3:logon drive
global:3:logon home
global:3:logon path
global:3:logon script
global:3:lpq cache time
global:3:machine password timeout
global:3:mangled stack
global:3:mangle prefix
global:3:mangling method
global:3:map to guest
global:3:max disk size
global:3:max log size
global:3:max mux
global:3:max open files
global:3:max protocol
global:3:max smbd processes
global:3:max ttl
global:3:max wins ttl
global:3:max xmit
global:3:message command
global:3:min passwd length
global:3:min password length
global:3:min protocol
global:3:min wins ttl
global:3:name cache timeout
global:3:name resolve order
global:3:netbios aliases
global:3:netbios name
global:3:netbios scope
global:3:nis homedir
global:3:ntlm auth
global:3:nt pipe support
global:3:nt status support
global:3:null passwords
global:3:obey pam restrictions
global:3:oplock break wait time
global:3:os2 driver map
global:3:os level
global:3:pam password change
global:3:panic action
global:3:paranoid server security
global:3:passdb backend
global:3:passwd chat
global:3:passwd chat debug
global:3:passwd program
global:3:password level
global:3:password server
global:3:pid directory
global:3:prefered master
global:3:preferred master
global:3:preload
global:3:preload modules
global:3:printcap
global:3:private dir
global:3:protocol
global:3:read bmpx
global:3:read raw
global:3:read size
global:3:realm
global:3:remote announce
global:3:remote browse sync
global:3:restrict anonymous
global:3:root
global:3:root dir
global:3:root directory
global:3:security
global:3:server schannel
global:3:server signing
global:3:server string
global:3:set primary group script
global:3:set quota command
global:3:show add printer wizard
global:3:shutdown script
global:3:smb passwd file
global:3:smb ports
global:3:socket address
global:3:socket options
global:3:source environment
global:3:stat cache
global:3:strip dot
global:3:syslog
global:3:syslog only
global:3:template homedir
global:3:template primary group
global:3:template shell
global:3:time offset
global:3:time server
global:3:timestamp logs
global:3:unicode
global:3:unix charset
global:3:unix extensions
global:3:unix password sync
global:3:update encrypted
global:3:use mmap
global:3:username level
global:3:username map
global:3:use spnego
global:3:utmp
global:3:utmp directory
global:3:winbind cache time
global:3:winbind enable local accounts
global:3:winbind enum groups
global:3:winbind enum users
global:3:winbind gid
global:3:winbind separator
global:3:winbind trusted domains only
global:3:winbind uid
global:3:winbind use default domain
global:3:wins hook
global:3:wins partners
global:3:wins proxy
global:3:wins server
global:3:wins support
global:3:workgroup
global:3:write raw
global:3:wtmp directory
section:3:acl compatibility
section:3:admin users
section:3:allow hosts
section:3:available
section:3:blocking locks
section:3:block size
section:3:browsable
section:3:browseable
section:3:case sensitive
section:3:casesignames
section:3:comment
section:3:copy
section:3:create mask
section:3:create mode
section:3:csc policy
section:3:default case
section:3:default devmode
section:3:delete readonly
section:3:delete veto files
section:3:deny hosts
section:3:directory
section:3:directory mask
section:3:directory mode
section:3:directory security mask
section:3:dont descend
section:3:dos filemode
section:3:dos filetime resolution
section:3:dos filetimes
section:3:exec
section:3:fake directory create times
section:3:fake oplocks
section:3:follow symlinks
section:3:force create mode
section:3:force directory mode
section:3:force directory security mode
section:3:force group
section:3:force security mode
section:3:force user
section:3:fstype
section:3:group
section:3:guest account
section:3:guest ok
section:3:guest only
section:3:hide dot files
section:3:hide files
section:3:hide special files
section:3:hide unreadable
section:3:hide unwriteable files
section:3:hosts allow
section:3:hosts deny
section:3:inherit acls
section:3:inherit permissions
section:3:invalid users
section:3:level2 oplocks
section:3:locking
section:3:lppause command
section:3:lpq command
section:3:lpresume command
section:3:lprm command
section:3:magic output
section:3:magic script
section:3:mangle case
section:3:mangled map
section:3:mangled names
section:3:mangling char
section:3:map acl inherit
section:3:map archive
section:3:map hidden
section:3:map system
section:3:max connections
section:3:max print jobs
section:3:max reported print jobs
section:3:min print space
section:3:msdfs proxy
section:3:msdfs root
section:3:nt acl support
section:3:only guest
section:3:only user
section:3:oplock contention limit
section:3:oplocks
section:3:path
section:3:posix locking
section:3:postexec
section:3:preexec
section:3:preexec close
section:3:preserve case
section:3:printable
section:3:printcap name
section:3:print command
section:3:printer
section:3:printer admin
section:3:printer name
section:3:printing
section:3:print ok
section:3:profile acls
section:3:public
section:3:queuepause command
section:3:queueresume command
section:3:read list
section:3:read only
section:3:root postexec
section:3:root preexec
section:3:root preexec close
section:3:security mask
section:3:set directory
section:3:share modes
section:3:short preserve case
section:3:strict allocate
section:3:strict locking
section:3:strict sync
section:3:sync always
section:3:use client driver
section:3:user
section:3:username
section:3:users
section:3:use sendfile
section:3:-valid
section:3:valid users
section:3:veto files
section:3:veto oplock files
section:3:vfs object
section:3:vfs objects
section:3:volume
section:3:wide links
section:3:writable
section:3:writeable
section:3:write cache size
section:3:write list
section:3:write ok
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

File::Samba - Samba configuration Object

=head1 SYNOPSIS

  use File::Samba;
  my $smb = File::Samba->new("/etc/samba/smb.conf");
  @list = $smb->listShares;
  $smb->deleteShare('homes');
  $smb->createShare('newShare');

=head1 DESCRIPTION

 This module allows for easy editing of smb.conf in an OO way.
 The need arised from openfiler http://www.openfiler.org which at this current
 time setups a smb conf for you, however any changes you made by hand are lost
 when you make change due to the fact it doesnt havea way to edit an existing
 smb.conf but simply creates a new one. This modules allows for any program to
 be ables to extract the current config, make changes nd save the file. Comments
 are lost however on save.
 
=head2 EXPORT

The following methods may be imported
version
keys
value
listShares
deleteShare
createShare
sectionParameter
globalParameter
load
save

=head1 SEE ALSO

http://www.samba.org Samba homepage
All the config keys were extracted from version 2 and 3 man pages

=head1 AUTHOR

Salvatore E. ScottoDiLuzio<lt>washu@olypmus.net<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Salvatore ScottoDiLuzio

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
