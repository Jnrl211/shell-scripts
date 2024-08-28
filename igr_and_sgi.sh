#!/bin/bash
# 
# [I]mport [G]itHub [r]epository and [s]et [G]itHub SSH [i]dentity script
# 
# A shell script to easily clone Git repositories to the local machine and select a custom SSH identity for the repository
# Setting up multiple SSH keys to use multiple GitHub accounts on a single machine can turn out more difficult than expected, and requires setting up Git differently,
# this script makes the process of using multiple GitHub accounts easier, without having to modify Git config files or call Git commands with a custom SSH command every time.
# 
# Basically, you must set up your SSH keys as usual: generate your public and private SSH keys for each GitHub account you are using and associate each pair with each account,
# Then, for each account, also addressed as "identity" in this file, you must create the following files in your "~/.ssh" or "%USERPROFILE%\.ssh" folder:
# - a .username file named as your identity, containing your GitHub username
# - a .noreplyemail file named as your identity, containing your GitHub no-reply e-mail
# Your .ssh directory should look like this:
# - account1 (private SSH key associated with your GitHub account)
# - account1.pub (public SSH key associated with your GitHub account)
# - account1.username (containing your GitHub user name in the first line of the file)
# - account1.noreplyemail (containing your GitHub no-reply e-mail in the first line of the file)
# - (and a similar set of files for each extra GitHub account you have)
# 
# Arguments:
# - Repository remote SSH URL (cloning from HTTP causes a variety of issues, and only cloning from SSH allows authentication based on SSH keys)
#   SSH requires more initial setup but provides a more seamless and secure authentication experience once configured. Preferred for frequent interactions with the repository
# - Identity name (script will look for 4 files with this name: one for the user name, another for the no reply e-mail, and two more for the public and private SSH keys
# - Repository Local directory (if destination doesn't exist, will clone it, otherwise, will clone to a temporary location and then cut-paste its contents to the extant directory)

# In the function definition scope, positional arguments refer to arguments passed to the function, not to the positional arguments of the script
# Local variables in functions take precedence over global variables in functions
# Bash functions don't return values directly, the mechanism differs from many programming languages,
# the return statement in a Bash function returns an integer exit status code (between 0 and 255) to indicate success or failure, but is not suitable for returning data
# - A common approach is to use echo or printf to print the result, and then capture that output when calling the function (including to return arrays)
# - Functions can modify global variables, which can then be accessed after the function executes
# - For more complex cases, it is possible to redirect output to a file or use file descriptors
function test_source() {
    local source="$1"
    # This regex checks whether a GitHub repository URL is valid based on -some- user name and repository name restrictions
    # assuming the original SSH user and host name are used (git@github.com) straight from the "<> Code" button of the repository
    if [[ $(echo "$source" | grep -E "^git@github\.com:[a-zA-Z0-9-]{1,39}/[a-zA-Z0-9._-]{1,100}\.git$") == "" ]]; then
        echo "Failed to parse source repository address, please provide a valid SSH URL"
        echo "(verify the URL points to a valid GitHub repository, uses user and host name \"git@github.com\", and ends in \".git\")"
        return 1
    fi
    echo "$source"
    return 0
}

function test_identity() {
    local identity="$1"
    local private_key_file=$1
    local public_key_file="$1.pub"
    local user_name_file="$1.username"
    local user_no_reply_email_file="$1.noreplyemail"
    local is_failed=0
    # TODO: add check for forbidden names
    # Checks whether the identity files of the selected identity exist in the ~/.ssh folder
    # grep produces a multi-line string containing the file names that match the regex: each regex below is designed so grep only finds a single file if it exists, using ERE
    # - ERE (Extended Regular Expression flavor), adding -E option to grep (preferred): "^id([\.]{1}[a-zA-Z0-9]*){0,1}$"
    # - BRE (Basic Regular Expression flavor): "^id\([\.]\{1\}[a-zA-Z0-9]*\)\{0,1\}$"
    # the output of ls is piped to grep so the output of ls acts as the input of grep, as a file stream
    if [[ $(ls ~/.ssh | grep -E "^$identity$") != "$private_key_file" ]]; then
        echo Private key file not found
        is_failed=1
    fi
    if [[ $(ls ~/.ssh | grep -E "^$identity\.pub$") != "$public_key_file" ]]; then
        echo Public key file not found
        is_failed=1
    fi
    if [[ $(ls ~/.ssh | grep -E "^$identity\.username$") != "$user_name_file" ]]; then
        echo User name file not found
        is_failed=1
    fi
    if [[ $(ls ~/.ssh | grep -E "^$identity\.noreplyemail$") != "$user_no_reply_email_file" ]]; then
        echo No-reply e-mail file not found
        is_failed=1
    fi
    # Check if there was at least a missing file
    if [ $is_failed -eq 1 ]; then 
        echo "Failed to find identity files, please ensure the ~/.ssh folder contains the following files of your Git/GitHub identity:"
        echo "- Private SSH key (e. g. my_id)"
        echo "- Public SSH key (e. g. my_id.pub)"
        echo "- User name (e. g. my_id.username)"
        echo "- No-reply e-mail (e. g. my_id.noreplyemail)"
        return 1
    fi
    return 0
}

function test_destination() {
    local destination="$1"
    local destination_parent_directory="$(dirname "$(readlink -f "$destination")")"
    # Check if the parent directory exists
    if [ ! -d "$destination_parent_directory" ]; then
        echo "Failed to process destination, parent directory does not exist"
        return 1
    fi
    # Check if the parent directory is writable
    if [ ! -w "$destination_parent_directory" ]; then
        echo "Failed to process destination, no write permission in the parent directory"
        return 1
    fi
    return 0
}

function import_repository() {
    # If destination doesn't exist but can be created at the parent directory (confirmed or denied by test_directory), does "git clone" to the parent directly,
    # If destination exists, renames local directory to a temporary name, then does "git clone" and cut-pastes all contents from local directory to cloned repository recursively
    # and finally remove the renamed local directory
    local source="$1"
    local identity="$2"
    local destination="$3"
    local git_path="$4"
    # eval is necessary here so "~" expands properly if contained in the destination argument, because "~" doesn't expand to the user directory when in quotes, only without them
    if [ -d $(eval echo "$destination") ]; then
        echo "info: destination $destination exists"
        # Rename extant folder to a placeholder name
        mv "$destination" "$destination-tmpbkup"
        # Git clone (SSH key must be provided to prove authorization to clone private or restricted repositories)
        $git_path clone --config core.sshCommand="ssh -i ~/.ssh/$identity" "$source" "$destination"
        # copy contents from local tmpbkup folder and paste them (overwriting) to Git folder (all configs are done later), all files (normal) and all files starting with .
        # verbose
        mv -f -v "$destination-tmpbkup/{*,.*}" "$destination"
        # remove temporary backup local repository folder after all contents have been moved out of it (-d only removes empty directories)
        # verbose
        rm -d -v "$destination-tmpbkup"
    else
        echo "info: destination $destination doesn't exist"
        # Git clone (SSH key must be provided to prove authorization to clone private or restricted repositories)
        $git_path clone --config core.sshCommand="ssh -i ~/.ssh/$identity" "$source" "$destination"
    fi
    # Once the script finishes, any changes made to the working directory are lost because the script runs in a separate subshell (its own context),
    # so there's no need to get the save script location beforehand (this is -not- the default behavior on Windows CMD, unless scripts are run with START on a separate window)
    # To change the directory for the current shell session, source the script instead of executing it: this runs it in the current shell environment rather than a subshell,
    # using: "source script.sh" or ". script.sh"
    cd "$destination"
    # Calling git commands inside a folder that is not a git repository is ineffectual and harmless, otherwise, everything works as intended
    $git_path config --local core.sshCommand "ssh -i ~/.ssh/$identity"
    # cat is used to concatenate the contents of each file and print them to console, wrapped in an expression so cat output expands to the file content
    $git_path config --local user.name "$(cat ~/.ssh/$identity.username)"
    $git_path config --local user.email "$(cat ~/.ssh/$identity.noreplyemail)"
    # Return the last exit code: if git succeeds, it should return exit code 0 as usual, if it fails, it will produce a non-zero exit code
    return $?
}

# This path is overriden if the user provides a custom Git path or Git alias; you may have to pass this argument if you use a portable Git installation
git_path="git"
# This array contains file names that are used by default or are standard for SSH configurations and utilities, 
# to ensure that custom key files don't inadvertently replace or conflict with important files in the ~/.ssh directory
restricted_identity_names=("id_rsa" "id_ecdsa" "id_ed25519" "authorized_keys" "known_hosts" "config" "ssh-keygen")
is_valid_source=1
is_valid_identity=1
is_valid_destination=1
# The list of arguments $@ passed to getopt must be in double quotes so arguments containing blank spaces are parsed correctly. Single quotes save literal strings, not expressions
options=$(getopt -o hs:i:d:g: -l help,source:,identity:,destination:,git_path: -- "$@")
if [ $? -ne 0 ]; then
    echo "Failed to parse options, exiting"
    exit 1
fi
# eval is necessary because it expands the arguments before passing them to set, 
# otherwise, set parses the single quotes around option arguments produced by getopt as part of the arguments, like parsing 'id' as:
# 1. 'id'
# as a four-characters string instead of:
# 1. id
# as a two-characters string, the expected outcome in interactive shell execution
# 
# eval also forces parameter expansion -according to interactive shell rules-, which is necessary to let set parse arguments in quotes as single arguments, like:
# 1. 'an argument'
# as a single string, instead of:
# 1. 'an 
# 2. argument'
# as two separate arguments, which is the default in direct script execution because there is a blank space between them, but not in interactive shell execution
# A deeper explanation is found here: https://stackoverflow.com/a/12137030/25878481
# 
# Finally the options string must -not- be in quotes, otherwise all arguments will be parsed as a single argument, ignoring all options set by getopt
eval set -- $options
# This block only runs if no options were found, so the only option present is the "--" generated by set. Defaults to setting the script to help mode
if [[ $# -eq 1 ]]; then
    # Add "--" before passing positional arguments to be added to the script, otherwise, the positional arguments are interpreted as options for set, not for the script
    set -- -h --
fi
# Argument parsing loop
while [[ $# -gt 0 ]]; do
    # Unlike other languages, in Bash the "case [argument] in" statement is like the switch statement, and pattern matchers act like case labels
    # Unlike traditional loops, often to loop over options only the first argument is evaluated because "shift" continuously pushes further arguments to preceding positions
    # - In the first run: argument 1 is $1 (evaluated), argument 2 is $2, argument 3 is $3, ...
    # - In the second run: argument 2 is $1 (evaluated), argument 3 is $2, ...
    # - In the third run: argument 3 is $1 (evaluated), ...
    # - On each step (each time shift is called in the loop) the argument count is reduced by 1, until it becomes 0
    # Multiple shift calls can be stacked in a pattern matcher to skip arguments of options from being evaluated by case
    # Each pattern matcher contains the single-dash short option and the double-dash long option specified in the getopt call
    # Since the purpose of this loop is to parse options only and not positional parameters, once the "--" symbol added by getopt is found, execution breaks out of the case loop
    # Wildcard "*" catches all other options that are not specified in getopt
    # The ";;" separator in a case statement is used to prevent fall-through to the next pattern (acts like a "break" for patterns only, doesn't affect the parent loop)
    case "$1" in
        -h|--help)
            # Customize this help message if more arguments are added to the script
            echo "Usage: $0 [-h|--help] [-s|--source <source>] [-i|--identity <identity>] [-d|--destination <destination>] [-g|--git_path <git_path>]"
            echo "- source - GitHub remote repository SSH URL"
            echo "- identity - GitHub SSH identity"
            echo "- destination - Local repository destination path"
            echo "- git_path - (Optional) Git path or Git alias"
            exit 0
            ;;
        -s|--source)
            source=$2
            test_source "$source"
            is_valid_source=$?
            shift
            ;;
        -i|--identity)
            identity="$2"
            test_identity "$identity"
            is_valid_identity=$?
            shift
            ;;
        -d|--destination)
            destination=$2
            test_destination "$destination"
            is_valid_destination=$?
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1"
            exit 1
            ;;
    esac
    shift
done
# Argument validation checks
if [ $is_valid_source -ne 0 ]; then
    echo "Source argument not provided, or not valid"
fi
if [ $is_valid_identity -ne 0 ]; then
    echo "Identity argument not provided, or not valid"
fi
if [ $is_valid_destination -ne 0 ]; then
    echo "Destination argument not provided, or not valid"
fi
if [ $is_valid_source -ne 0 ] || [ $is_valid_identity -ne 0 ] || [ $is_valid_destination -ne 0 ]; then
    echo Failed to import GitHub repository, at least one of the arguments is not valid
    exit 1
fi
import_repository "$source" "$identity" "$destination" "$git_path"
exit $?