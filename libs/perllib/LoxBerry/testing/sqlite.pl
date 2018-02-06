#!/usr/bin/perl

use DBI;
$dbfile = "/tmp/notifications.sqlite";
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");

create_notify_tables();

# Insert values
my $sth = $dbh->prepare('INSERT INTO notifications (package, name, message, severity, timestamp) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP);');
$sth->execute('updates', 'update', 'Das ist eine Meldung', 0);
my $id = $dbh->sqlite_last_insert_rowid();
my $sth2;
$sth2 = $dbh->prepare('INSERT INTO notifications_attr (keyref, attrib, value) VALUES (?, ?, ?);');
$sth2->execute($id, 'logfile', 'This is the log');
$sth2->execute($id, 'level', 5);


# Select values
$sth = $dbh->prepare('SELECT * FROM notifications;');
$sth2 = $dbh->prepare('SELECT * FROM notifications_attr;');

$sth->execute;
$sth2->execute;

$hashref = $sth->fetchall_hashref('notifykey');

exit;

sub create_notify_tables
{

	
		$dbh->do("CREATE TABLE IF NOT EXISTS notifications (
					package VARCHAR(255) NOT NULL,
					name VARCHAR(255) NOT NULL,
					message TEXT,
					severity INT,
					timestamp DATETIME NOT NULL,
					notifykey INTEGER PRIMARY KEY AUTOINCREMENT 
				)");
	
		$dbh->do("CREATE TABLE IF NOT EXISTS notifications_attr (
					keyref INTEGER NOT NULL,
					attrib VARCHAR(255) NOT NULL,
					value VARCHAR(255),
					PRIMARY KEY ( keyref, attrib )
					)");
	
					
}
