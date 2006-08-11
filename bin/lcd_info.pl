#!/usr/bin/perl

use IO::LCDproc;
use Filesys::Df;
use Net::IP;
use Net::Interface qw(
		      IFF_UP
		      IFF_BROADCAST
		      IFF_DEBUG
		      IFF_LOOPBACK
		      IFF_POINTOPOINT
		      IFF_NOTRAILERS
		      IFF_RUNNING
		      IFF_NOARP
		      IFF_PROMISC
		      IFF_ALLMULTI
		      IFF_MASTER
		      IFF_SLAVE
		      IFF_MULTICAST
		      IFF_SOFTHEADERS
		      IFHWADDRLEN
		      IFNAMSIZ
		      mac_bin2hex
		      );
use Data::Dumper;

our %screens;
our $client = IO::LCDproc::Client->new(name => 'cmms', host => $self->{conf}->{ripper}->{lcdhost}, port => $self->{conf}->{ripper}->{lcdport});
our $scr;

create_screen("screen");

$client->connect() or die "cannot connect: $!";
$client->initialize();

print STDERR Dumper($client);

while( 1==1 ) {
    update_network();
    sleep 3;
    update_disk();
    sleep 3;
}

sub update_network {
    my $if = Net::Interface->new('eth0');
    my $address = join(".",unpack("CCCC", $if->address()));
    my $netmask = join(".",unpack("CCCC", $if->netmask()));
    my $broadcast = join(".",unpack("CCCC", $if->broadcast()));
    my $mac = mac_bin2hex(scalar $if->hwaddress());

    $scr->{title}->set( data => "Network" );
    $scr->{line1}->set( data => "IP:".$address );
    $scr->{line3}->set( data => "NM:".$netmask );
    $scr->{line2}->set( data => "MC:".$mac );
}

sub update_disk {
    my $ds = df("/");
    my $percentage = $ds->{per};
    my $tempstr = `/usr/sbin/hddtemp /dev/hdc`;
    my ($temp) = ($tempstr =~ /.*\:\s(\d+)/sig);
    $temp or $temp = "N/A ";

    $scr->{title}->set( data => "Disk Space" );
    $scr->{line1}->set( data => "Used: ".$percentage."%" );
    $scr->{line2}->set( data => "Disk temp: ".$temp."C" );
    $scr->{line3}->set( data => " ");
}

sub create_screen {
    my $sname = shift @_;
    
    my $screen = IO::LCDproc::Screen->new(name => $sname, client => $client);
    my $title  = IO::LCDproc::Widget->new(screen => $screen, name => 'title', type => 'title');
    my $line1  = IO::LCDproc::Widget->new(screen => $screen, name => 'line1',  xPos => 1,  yPos => 2);
    my $line2  = IO::LCDproc::Widget->new(screen => $screen, name => 'line2',  xPos => 1,  yPos => 3);
    my $line3  = IO::LCDproc::Widget->new(screen => $screen, name => 'line3',  xPos => 1,  yPos => 4);
    
    $client->add($screen);
    $screen->add($title,$line1,$line2,$line3);
    
    $scr = {
	screen=>$screen,
	title=>$title,
	line1=>$line1,
	line2=>$line2,
	line3=>$line3
	};
    
}
