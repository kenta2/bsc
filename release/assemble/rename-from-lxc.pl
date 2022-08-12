#!perl -wl
die "need filename" unless defined ($_=$ARGV[0]);
print STDERR "processing $_";
die "'$_' does not exist" unless -e $_;
die unless ($path,$os)=m,(.*/)bsc-[^-/]+-([^-/]+)-on-[^/]+\.zip$,;
if($os =~ /^ubuntu(..)(.*)$/){
    $os="ubuntu$1.$2";
}
die "cannot figure out OS number" unless ($name,$number)=($os=~/^([^0-9]+)(\d.*)/);
$os=$name."-".$number;
$file="$path$os build.zip";
die "'$file' already exists" if -e $file;
rename $_,$file or die "'rename ($_) ($file)' failed";
