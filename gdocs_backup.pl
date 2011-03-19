#! /usr/bin/perl
use uni::perl;
use autodie;
use Getopt::Long;
use Net::Google::DocumentsList;
use JSON;
use IO::All -utf8;

my ($output_dir, $login, $password);

GetOptions('login=s' => \$login, 'password=s' => \$password,
    'output=s' => \$output_dir);

unless ($login && $password) {
    die "Usage: $0 --login <login> --password <password> [--output <output dir>]\n";
}

$output_dir //= 'docs/';
-d $output_dir or mkdir $output_dir;

my %save_as = (
    document    => 'odt',
    spreadsheet => 'ods',
    presentation=> 'ppt',
    pdf         => 'pdf',
    drawing     => 'svg',
    'image/png' => 'png',
);

my $gdocs = Net::Google::DocumentsList->new(
    # XXX OAuthify
    username    => $login,
    password    => $password,
);

my @items = $gdocs->items;

for (@items) {
    say "Downloading " . $_->title;
    (my $filename = $_->title) =~ y{/}{_};
    $_->export({
        format  => $save_as{$_->kind},
        file    => "$output_dir/$filename.$save_as{$_->kind}",
    });
}

say "Saving metadata.json";
io("$output_dir/metadata.json")->print(to_json([
    map {
    	my %hash;
    	for my $attr
    	    (qw/title kind published alternate updated edited
    	        resource_id deleted parent/)
    	{ $hash{$attr} = $_->$attr }
        \%hash;
    } @items
], { pretty => 1 }));
