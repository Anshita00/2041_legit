#!/usr/bin/perl -w
use File::Copy;
use File::Compare;
$prog = $0;
$prog =~ s/\.\///g;

# Error message when there are no arguments
if (scalar @ARGV < 1) {
    $prog = $0;
    $prog =~ s/\.\///g;
    print STDERR "Usage: legit.pl <command> [<args>]\n\n";
    print STDERR "These are the legit commands:\n";
    print STDERR "   init       Create an empty legit repository\n";
    print STDERR "   add        Add file contents to the index\n";
    print STDERR "   commit     Record changes to the repository\n";
    print STDERR "   log        Show commit log\n";
    print STDERR "   show       Show file at particular state\n";
    print STDERR "   rm         Remove files from the current directory and from the index\n";
    print STDERR "   status     Show the status of files in the current directory, index, and repository\n";
    print STDERR "   branch     list, create or delete a branch\n";
    print STDERR "   checkout   Switch branches or restore current directory files\n";
    print STDERR "   merge      Join two development histories together\n\n";
    exit 1;
}
# Initialising the repo
if ($ARGV[0] eq "init") {
    
    # .legit has already been created
    if (-e ".legit" && -d ".legit") {
        print "legit.pl: error: .legit already exists\n";
        exit 1;
    }
    mkdir ".legit";

    # Store commits here
    mkdir ".legit/commits";

    # Store index here
    mkdir ".legit/index";
    print "Initialized empty legit repository in .legit\n";

} elsif ($ARGV[0] eq "add") {

    if (! -e ".legit") {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n";
        exit 1;
    }

    shift @ARGV;

    # No files given to add
    if (scalar @ARGV < 1) {
        print STDERR "legit.pl: error: internal error Nothing specified, nothing added.\n";
        print STDERR "Maybe you wanted to say 'git add .'?\n";
        exit 1;
    }

    # Checking if filename is valid
    foreach $file (@ARGV) {
        if ($file !~ /^[\da-zA-Z]{1}[\da-zA-Z.-_]*$/) {
            print STDERR "legit.pl: error: invalid filename $file\n";
            exit 1;
        }
    }

    # Add every file in list of arguments
    foreach $file (@ARGV) {
        $name = ".legit/index/$file";

        # If our repo has been freshly committed
        if (-e ".legit/index/.committed" && ((-e $name && compare("$file", "$name") != 0 ) || !(-e $name))) {

            # If the file exists in index but not in directory we remove it
            if (-e $name && ! (-e $file)) {
                unlink $name;
            } else {
                copy("$file", "$name") or print STDERR "legit.pl: error: can not open '$file'\n" ;
            }

            # Remove this file to show that the index has now changed
            unlink ".legit/index/.committed";
        } else {
            if (-e $name && ! (-e $file)) {
                unlink $name;
            } else {
                copy("$file", "$name") or print STDERR "legit.pl: error: can not open '$file'\n" ;
            }
        }

    }

} elsif ($ARGV[0] eq "commit") {
    
    if (! -e ".legit") {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n";
        exit 1;
    }

    # Extracting all options
    if ((scalar @ARGV < 3) || $ARGV[1] !~ /^-[am]$/) {
        print STDERR "usage: legit.pl commit [-a] -m commit-message\n";
        exit 1;
    }

    $flag = 0;
    $message = "";
    if ($ARGV[1] =~ /^-a/) {
        if ($ARGV[2] !~ /^-m$/ || scalar @ARGV < 4 || $ARGV[3] =~ /^-/) {
            print STDERR "usage: legit.pl commit [-a] -m commit-message\n";
            exit 1;
        } elsif ($ARGV[3] =~ /\n/) {
            print STDERR "legit.pl: error: commit messages can not contain a newline\n";
            exit 1;
        } else {
            $flag = 1;
            $message = "$ARGV[3]";
        }

    } elsif ($ARGV[2] =~ /^-/) {
        print STDERR "usage: legit.pl commit [-a] -m commit-message\n";
        exit 1;
    } elsif ($ARGV[2] =~ /\n/) {
            print STDERR "legit.pl: error: commit messages can not contain a newline\n";
            exit 1;
    } else {
        $message = "$ARGV[2]";
    }

    # Trying to find out the number of the last commit
    $dir = ".legit/commits/.commit.";
    $i = 0;
    $final_dir = $dir.$i;
    while (-e $final_dir && -d $final_dir) {
        $i++;
        $final_dir = $dir.$i;
    }
    $commit_no = 0;
    $dir = ".legit/commits/.commit.";
    $final_dir = $dir.$commit_no;
    while (-e $final_dir) {
        $commit_no++;
        $final_dir = $dir.$commit_no;
    }
    $commit_no--;

    # If repo has been freshly committed
    if (-e ".legit/index/.committed") {
        if ($flag == 0) {

            # If this is not first commit
            if ($commit_no >= 0) {
                print STDERR "nothing to commit\n";
                exit 1;
            }
        } else {

            # If using -a, check if at least one file present in index is different to directory
            my $diff_files = 0;
            foreach $file (glob ".legit/index/*") {
                $file =~ /\.legit\/index\/(.+)/;
                $new_file = "$1";
                if (compare("$new_file", "$file") != 0) {
                    $diff_files++;
                }
            }

            # If all files are the same, print error message
            if ($diff_files == 0 && $commit_no >= 0) {
                print STDERR "nothing to commit\n";
                exit 1;
            } else {
                unlink ".legit/index/.committed";
            }
        }
    }

    # Otherwise, make new commit directory
    mkdir $final_dir;
    $committed = 0;
    foreach $file (glob ".legit/index/*") {
        $file =~ /\.legit\/index\/(.+)/;
        $new_file = "$1";
        if ($new_file !~ /^\./) {
            if ($flag) {
                copy("$new_file", "$file") or print STDERR "legit.pl: error: can not open '$new_file'\n";
            }
            $committed = 1;
            copy("$file", "$final_dir/$new_file");
        }
    }

    # If there were no files to be committed and this is the first commit, print error message
    if ($committed == 0 && $commit_no < 0) {
        print STDERR "nothing to commit\n";
        while (-e $final_dir) {
            rmdir $final_dir;
        }
        exit 1;
    }

    # Store commit message in a file
    open F, ">", "$final_dir/.message" or die "Can't make the message file\n";
    print F "$message\n";
    close F;

    # Store that the repo has been freshly committed in index
    open F, ">", ".legit/index/.committed" or die "Can't say file has been committed\n";
    print F "freshly committed\n";
    close F;
    print "Committed as commit $i\n";
} elsif ($ARGV[0] eq "log") {

    if (! -e ".legit") {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n";
        exit 1;
    }

    $check = ".legit/commits/.commit.0";
    if (! -e $check) {
        print STDERR "legit.pl: error: your repository does not have any commits yet\n";
        exit 1;
    }

    if (scalar @ARGV > 1) {
        print STDERR "usage: legit.pl log\n";
        exit 1;
    }

    # Find last commit
    $dir = ".legit/commits/.commit.";
    $i = 0;
    $final_dir = $dir.$i;
    $commits = 0;
    while (-e $final_dir) {
        $commits = 1;
        $i++;
        $final_dir = $dir.$i;
    }
    $i--;
    $final_dir = $dir.$i;

    # Print all commits starting from last commit
    while (-e $final_dir) {
        print "$i ";
        open F, "<", "$final_dir/.message" or die "Couldn't open message file\n";
        $line = <F>;
        print "$line";
        close F;
        $i--;
        $final_dir = $dir.$i;
    }

    if ($commits == 0) {
        print STDERR "legit.pl: error: your repository does not have any commits yet\n";
        exit 1;
    }

} elsif ($ARGV[0] eq "show") {

    # Error checking
    if (! -e ".legit") {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n";
        exit 1;
    }

    $check = ".legit/commits/.commit.0";
    if (! -e $check) {
        print STDERR "legit.pl: error: your repository does not have any commits yet\n";
        exit 1;
    }

    if (scalar @ARGV != 2) {
        print STDERR "usage: legit.pl show <commit>:<filename>\n";
        exit 1;
    }

    if ($ARGV[1] !~ /\d*:.*/) {
        print STDERR "legit.pl: error: invalid object $ARGV[1]\n";
        exit 1;
    }

    # Extracting the commit and filename
    $ARGV[1] =~ /([^:]*):(.*)/;
    $commit = $1;
    $file = $2;
    $dir = "";

    # Deciding which commit to use
    if ($commit eq "") {
        $dir = ".legit/index";
    } else {
        $dir = ".legit/commits/.commit.$commit";
        if (! -e $dir) {
            print STDERR "legit.pl: error: unknown commit '$commit'\n";
            exit 1;
        }
    }

    # Checking if filename is valid
    if ($file !~ /^[\da-zA-Z]{1}[\da-zA-Z.-_]*$/) {
        print STDERR "legit.pl: error: invalid filename '$file'\n";
        exit 1;
    }

    # Checking if file exists
    $final_file = "$dir/$file";
    if (! -e $final_file) {
        if ($commit eq  "") {
            print STDERR "legit.pl: error: '$file' not found in index\n";
            exit 1;
        } else {
            print STDERR "legit.pl: error: '$file' not found in commit $commit\n";
            exit 1;
        }
    }

    # Oprning required file and printing contents
    open F, "<", $final_file or die "Can't open file $file\n";
    while ($line = <F>) {
        print $line;
    }
    close F;
} elsif ($ARGV[0] eq "rm") {

    if (! -e ".legit") {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n";
        exit 1;
    }

    $check = ".legit/commits/.commit.0";
    if (! -e $check) {
        print STDERR "legit.pl: error: your repository does not have any commits yet\n";
        exit 1;
    }

    # Extracting the options
    shift @ARGV;
    $forced = 0;
    $cached = 0;
    foreach $arg (@ARGV) {
        if ($arg eq "--force") {
            $forced = 1;
        } elsif ($arg eq "--cached") {
            $cached = 1;
        } elsif ($arg =~ /^-/) {
            print STDERR "usage: legit.pl rm [--force] [--cached] <filenames>\n";
            exit 1;
        }
    }

    @ARGV = grep {$_ ne "--force" && $_ ne "--cached"} @ARGV;
    if (scalar @ARGV == 0) {
        print STDERR "usage: legit.pl rm [--force] [--cached] <filenames>\n";
        exit 1;
    }
    
    # Checking if filename is valid
    foreach $arg (@ARGV) {
        if ($arg !~ /^[\da-zA-Z]{1}[\da-zA-Z.-_]*$/) {
            print STDERR "legit.pl: error: invalid filename '$file'\n";
            exit 1;
        }
    }

    # For each file to be removed
    foreach $file (@ARGV) {
        $index_file = ".legit/index/";
        $index_file = $index_file.$file;
        if (-e "$index_file") {
            if ($forced == 1) {
                # No error checking done for forced
                unlink $index_file;
                if (-e "$file" && !($cached)) {
                    unlink $file;
                }
                # If file has been freshly committed, remove .committed to signify a change has been made in index
                if (-e ".legit/index/.committed") {
                    unlink ".legit/index/.committed";
                }
            } else {
                # Find the latest commit
                $i = 0;
                $dir = ".legit/commits/.commit.";
                $final_dir = $dir.$i;
                while (-e $final_dir) {
                    $i++;
                    $final_dir = $dir.$i;
                }
                $i--;
                $final_dir = $dir.$i;

                # All error checks to prevent user from losing data
                if (-e "$file" && compare("$index_file", "$file") != 0 && !(-e "$final_dir/$file") && !($cached)) {
                    print STDERR "legit.pl: error: '$file' in index is different to both working file and repository\n";
                    exit 1;
                } elsif (-e "$file" && compare("$index_file", "$file") != 0 && -e "$final_dir/$file" && compare("$index_file", "$final_dir/$file") != 0) {
                    print STDERR "legit.pl: error: '$file' in index is different to both working file and repository\n";
                    exit 1;
                }  elsif (-e "$file" && compare("$index_file", "$file") != 0 && -e "$final_dir/$file" && compare("$index_file", "$final_dir/$file") == 0 && !($cached)) {
                    print STDERR "legit.pl: error: '$file' in repository is different to working file\n";
                    exit 1;
                } elsif (-e "$final_dir/$file" && compare("$final_dir/$file", "$index_file") != 0 && !($cached)) {
                    print STDERR "legit.pl: error: '$file' has changes staged in the index\n";
                    exit 1;
                }elsif (! -e "$final_dir/$file" && !($cached)) {
                    print STDERR "legit.pl: error: '$file' has changes staged in the index\n";
                    exit 1;
                } elsif ($cached || !(-e "$file")) {
                    unlink $index_file;
                } else {
                    unlink $index_file;
                    unlink $file;
                }
                if (-e ".legit/index/.committed") {
                    unlink ".legit/index/.committed";
                }
            }
        } else {
            print STDERR "legit.pl: error: '$file' is not in the legit repository\n";
            exit 1;
        }

    }
    
} elsif ($ARGV[0] eq "status") {

    if (! -e ".legit") {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n";
        exit 1;
    }

    $check = ".legit/commits/.commit.0";
    if (! -e $check) {
        print STDERR "legit.pl: error: your repository does not have any commits yet\n";
        exit 1;
    }

    # Our array of all files
    @files = ();

    # Extract from current directory
    foreach $file (glob "*") {
        push @files, $file;
    }

    # Extract from the index
    foreach $file (glob ".legit/index/*") {
        $file =~ /.legit\/index\/(.+)/;
        $file = $1;
        if ( !(grep( /^$file$/, @files)) ) {
            push @files, $file;
        }
    }

    # Find last commit and extract from last commit
    $dir = ".legit/commits/.commit.";
    $i = 0;
    $final_dir = $dir.$i;
    while (-e $final_dir) {
        $i++;
        $final_dir = $dir.$i;
    }
    $i--;
    $final_dir = $dir.$i;
    foreach $file (glob "$final_dir/*") {
        $file =~ /$final_dir\/(.+)/;
        $file = $1;
        if ( !(grep( /^$file$/, @files)) ) {
            push @files, $file;
        }
    }

    # Sort our array and find out its status for each file in array
    foreach $file (sort @files) {
        $index_file = ".legit/index/$file";
        $commit_file = "$final_dir/$file";
        if (! -e "$file" && ! -e "$index_file") {
            print "$file - deleted\n";
        } elsif (! -e "$file") {
            print "$file - file deleted\n";
        } elsif (! -e "$index_file") {
            print "$file - untracked\n";
        } elsif (! -e "$commit_file") {
            print "$file - added to index\n";   
        } elsif (compare("$file", "$index_file") == 0 && compare("$file", "$commit_file") == 0) {
            print "$file - same as repo\n";
        } elsif (compare ("$file", "$index_file") == 0) {
            print "$file - file changed, changes staged for commit\n";
        } elsif (compare("$index_file", "$commit_file") == 0 && compare("$file", "$index_file") != 0) {
            print "$file - file changed, changes not staged for commit\n";
        } else {
            print "$file - file changed, different changes staged for commit\n";
        }

    }
}