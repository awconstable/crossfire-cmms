#!/usr/bin/perl -w

use strict;
use CMMS::Database::MysqlConnection;

my $mc = new CMMS::Database::MysqlConnection;
$mc->connect;

foreach my $genre (@{$mc->query_and_get('select * from genre')||[]}) {
	my $qname = $genre->{name};
	if($qname =~ /[\r\n]/) {
		$qname =~ s/[\r\n]+//g;
		$qname = $mc->quote($qname);
		my $dupe = shift(@{$mc->query_and_get('select * from genre where name = '.$qname)||[]});
		$mc->query('update track set genre_id = '.$dupe->{id}.' where genre_id = '.$genre->{id});
		$mc->query('update album set genre_id = '.$dupe->{id}.' where genre_id = '.$genre->{id});
		$mc->query('delete from genre where id = '.$genre->{id});
	}
}
