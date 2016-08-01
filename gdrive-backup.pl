#! /usr/bin/perl
use uni::perl;
use autodie;
use Getopt::Long;
use Net::Google::Drive::Simple;
use Encode qw/decode/;
use Data::Dumper;
use DateTime::Format::RFC3339;
use File::Spec;
use File::Path;

my $output_dir;

GetOptions('output=s' => \$output_dir);

unless ($output_dir) {
    die "Usage: $0 --output <output dir>\n";
}

-d $output_dir or mkdir $output_dir;

my @interesting_types = qw{
    application/vnd.oasis.opendocument.text
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    text/csv
    image/svg+xml
    image/png
    application/vnd.openxmlformats-officedocument.presentationml.presentation
};

my $date_parser = DateTime::Format::RFC3339->new();

# requires a ~/.google-drive.yml file containing an access token,
# see documentation of Net::Google::Drive::Simple
my $gdrive = Net::Google::Drive::Simple->new();
my $files = $gdrive->search({}, { page => 1 }, ""); # get all files

say scalar(@$files), " files found";

for my $file (@$files) {
    my %file_data;

    for my $field (qw/title mimeType downloadUrl originalFilename exportLinks modifiedDate/) {
        if ($file->can($field)) {
            $file_data{$field} = ref $file->$field ? $file->$field : decode('utf8', $file->$field());
        }
    }

    if ($file_data{originalFilename}) {
        say "Downloading [$file_data{originalFilename}] which is $file_data{mimeType}";
        download($file, \%file_data, "$output_dir/$file_data{originalFilename}");
    }
    elsif ($file_data{exportLinks}) {
        my $is_exported = 0;
        while (my ($type, $link) = each($file_data{exportLinks})) {
            if ($type ~~ @interesting_types) {
                my $ext = $link =~ /exportFormat=(\w+)/ ? ".$1" : "";

                my $filename = "$file_data{title}$ext";
                say "Exporting [$filename] which is $file_data{mimeType} as $type";
                download($link, \%file_data, "$output_dir/$filename");
                $is_exported = 1;
            }
        }
        unless ($is_exported) {
            print STDERR Dumper(\%file_data);
            die "Failed to export $file_data{title}";
        }
    }
    else {
        say "Skipping strange [$file_data{title}] which is $file_data{mimeType}";
        #print Dumper(\%file_data);
    }
}

sub download {
    my ($file_or_link, $file_data, $new_filename) = @_;

    my $mtime = $date_parser->parse_datetime($file_data->{modifiedDate});

    my $dir;
    (undef, $dir, undef) = File::Spec->splitpath($new_filename);
    File::Path::make_path($dir);

    $gdrive->download($file_or_link, $new_filename)
        or die "Download failed: $!\n";
    utime($mtime->epoch, $mtime->epoch, $new_filename);
}
