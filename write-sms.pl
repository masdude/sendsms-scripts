#!/usr/bin/perl
# Creation date : 2013-01-28

# Module        : write-sms.pl
# Purpose       : Write SMS from console to Android phone
# Usage         : perl write-sms.pl
# Licence       : GPL v2
# Contact       : Florian Breitwieser <florian.bw@gmail.com>

use strict;
use warnings;
use FindBin qw/$RealBin/;
use lib $RealBin;
use Term::Screen::Uni;
use Term::ANSIColor;
use Complete;
use AndroidSMS;

my $ADB = "adb";

my $scr = new Term::Screen::Uni;
$scr->clrscr();

$scr->at(4,5)->puts(" Gathering contacts ... \n");
my @contacts = get_contacts();
my %contact_to_number = contact_to_number(@contacts);
my %number_to_contact = number_to_contact(@contacts);

$scr->at(5,5)->puts(" Gathering SMS ... \n");
my @sms = AndroidSMS::get_sms();
for (my $i=0; $i<=$#sms; ++$i) {
  $sms[$i] =~ s/\+43/0/g;
  $sms[$i] =~ s/([0-9]) ([0-9])/$1$2/g;
}

$scr->at(7,5)->puts(" Recent SMS \n");
$scr->at(8,0);
my @recentcontacts = print_sms(\%number_to_contact,\@sms);

my $max_recent = min(scalar(@recentcontacts),9);
print "\n Recent contacts: ";
for (my $i=0;$i<$max_recent;++$i) {
  print "(",$i+1, ") ";
  print colored $recentcontacts[$i], "green";
  print ", " unless $i == $max_recent-1;
}
print "\n";
#$scr->clreol()->puts("Press Enter or a number of recent contact to write SMS: ");

my ($name,$number);
my $txt = join(" ",@ARGV);

my $ch = $scr->getch();
if (defined $ch && $ch > 0 && $ch <= $max_recent) {
  $name =$recentcontacts[$ch-1];
  $number = $contact_to_number{$name};
  $scr->clrscr();
  $scr = new Term::Screen::Uni;
  $scr->at(1,1)->puts(" Sending SMS to $name [$number]. ");
}

while (1) {

  ($name,$number) = ask_for_contact(%contact_to_number) unless defined $number;
  
  last if (!defined $name || $name eq "");

  show_recent_messages($name,$number,@sms);
  $txt = send_sms_to_number($number,$txt);

  print "\n Send another SMS? [yNsf] (to same contact with s, forward text to someone else with f) ";

  my $answer = $scr->getch();
  exit if !defined $answer || uc($answer) eq 'N';
    if (uc($answer) eq 'Y') {
      last;
    } elsif (uc($answer) eq 'S') {
      undef $txt;
      next;
    } elsif (uc($answer) eq 'F') {
      undef $number;
      next;
    }
  
  undef $txt;
  undef $number;
  next;
}

sub ask_for_contact {
  my (%contact_to_number) = @_;
  my $input = Complete("Enter contact name",keys %contact_to_number);
  my $name = $input;
  my $number = $contact_to_number{$name};
  last if $input =~ /quit/;
  last unless defined $number;
  return ($name,$number);
}

sub show_recent_messages {
  my ($name,$number,@sms) = @_;
  print "\n  Recent messages: \r\n";
  my @sms2 = grep(/$number/,@sms);
  AndroidSMS::print_sms1($name,\@sms2);

}

sub send_sms_to_number {
  my ($number,$txt) = @_;
  if (!defined $txt || length($txt) == 0) {
    print "\n\n  Enter text: ";
    $txt = <>;
    chomp $txt if defined $txt;
  }
  return if !defined $txt || length($txt) == 0;
  print "\n Send \"$txt\" to number $number? [Yn] ";
  my $answer = <>; chomp $answer if defined $answer;
  if (defined $answer && (uc($answer) eq 'Y' || $answer eq "")) {
    send_sms_using_shellms($number,$txt) unless !defined $txt || $txt =~ /^\s*$/;
  }
  return $txt;
}

sub send_sms_using_shellms {
  my ($number,$txt) = @_;
#  $txt =~ s/'/\\'/g;
  my $cmd = "$ADB shell am startservice --user 0 -n com.android.shellms/.sendSMS -e contact $number -e msg ".quotemeta($txt)."";
  print STDERR "Executing $cmd\n";
  system($cmd) == 0 or die "Could not send SMS";
  #system("$ADB logcat -d -s -C ShellMS_Service_sendSMS:*");
}

sub send_sms_using_shell {
  my ($number,$txt) = @_;
  print STDERR "Executing $ADB shell am start -a android.intent.action.SENDTO -d sms:$number --es sms_body '$txt' --ez exit_on_sent true\n";
  system("$ADB shell am start -a android.intent.action.SENDTO -d sms:$number --es sms_body '$txt' --ez exit_on_sent true") == 0 or die "Could not send SMS";
  sleep 1;
  system("$ADB shell input keyevent 22") == 0 or die "Could not focus on send button";
  sleep 1;
  system("$ADB shell input keyevent 66") == 0 or die "Could not press send button";
  sleep 1;
  system("$ADB shell input keyevent 3") == 0 or die "Could not press send button";
}


sub min {
  my ($a,$b) = @_;
  return($a > $b ? $b : $a);
}
