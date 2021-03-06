package AndroidSMS;
require 5.000;
require Exporter;

use strict;
use warnings;
use Term::ReadKey;
use Term::ANSIColor;
use Data::Dumper;

our @ISA = qw(Exporter);
our @EXPORT = qw(get_sms print_sms get_contacts contact_to_number number_to_contact);
our $VERSION = '1';

my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();

my $CONTACTS_DB = "/data/data/com.android.providers.contacts/databases/contacts2.db";
my $SMS_DB = "/data/data/com.android.providers.telephony/databases/mmssms.db";

sub get_contacts {
  #my $SQLCMD='select count(*),number,name from calls group by number,name'
  my $SQLCMD='SELECT name, number, _id FROM view_v1_phones';
  my $adb_cmd = "adb shell su -c \"sqlite3 -header -list -separator ' :: ' $CONTACTS_DB '$SQLCMD'\"";
  my @res = `$adb_cmd`;
  chomp @res;
  return @res;  
}

sub number_to_contact {
  contact_hash(1,0,@_);
}

sub contact_to_number {
  contact_hash(0,1,@_);
}

sub contact_hash {
  my ($key_field,$value_field,@contacts) = @_;
  my %contacts;
  foreach (@contacts) {
    my @c = split(/ :: /);
    if (defined $c[1]) {
      $c[1] =~ s/ //g;
      $c[1] =~ s/\+43/0/;
      $contacts{$c[$key_field]} = $c[$value_field];
    }
  }
  return(%contacts);
}



sub get_sms {
# my $SQLCMD="select address,replace(body,x'0A', ' '),type,read from sms order by _id desc limit 25";
  my $SQLCMD="select address,replace(replace(body,x'0A', ' '),x'0D', ' '),type,read from sms order by _id desc limit 25";
  my $sms_cmd="adb shell su -c \"sqlite3 -header -list -separator ' :: ' $SMS_DB \\\\\\\"$SQLCMD\\\\\\\"\"";
  my @res = `$sms_cmd`;
  chomp @res;
  return @res;  
}

sub print_sms1 {
  my ($contact,$sms) = @_;
  my %sms;
  my $first_line = 1;
  foreach (reverse @$sms) {
    my @s = split(/ :: /);
    next if $s[0] eq 'address';

    my $color = 'blue';
    $color = 'green' if ($s[2] == 1);
    $color = 'red' if ($s[3] == 0);

    if ($s[2] == 2) {
      printf " %".length($contact)."s ","[Me]";
      print colored $s[1]."\n",$color;
    } else {
      print " [$contact] ";
      print colored $s[1]."\n",$color;
    }
  }
}


sub print_sms {
  my ($contacts,$sms) = @_;
  my @recent_contacts;
  my %sms;
  my $first_line = 1;
  chomp @$sms;
  foreach (reverse @$sms) {
    my @s = split(/ :: /);
    next if $s[0] eq 'address';
    $s[0] =~ s/ //g;
    $s[0] =~ s/\+43/0/;
    # address,body,type,read
    #my $dest = $s[2] == 1? "from " : "  to ";
    my $dest = $s[2] == 1? " from " : " to ";
    my $read = $s[3] == 0? " [unread]" : "";
    my $color = 'blue';
    $color = 'green' if ($s[2] == 1);
    $color = 'red' if ($s[3] == 0);
    my $contact = defined $contacts->{$s[0]}? $contacts->{$s[0]} : $s[0];
    push @recent_contacts, $contact if $s[2] == 1 && $contact ne '';
    my $str = sprintf(" %25s","$dest".$contact);
    my $indent = length($str) + 2;
    
    my $width = $wchar-$indent-3;
  
    my @txt2 = split(/  */,$s[1]);
    my @txt = shift @txt2;
    foreach (@txt2) {
      if (length($txt[$#txt]) + length($_) < $width) {
        $txt[$#txt] .= " $_";
      } else {
        push @txt, $_;
      }
    }
  
    @txt = map { $_."\r\n" } @txt;
    my $txt = join(" " x $indent,@txt);
  
    print colored $str, $color;
    print ": ";
    print colored $txt, $color;
  }
  print "\n";
  return uniq(reverse @recent_contacts);
}

sub uniq { 
  my %seen; 
  grep !$seen{$_}++, @_;
}


1;


