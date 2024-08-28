#!/bin/bash
# 
# Tips
# 
# A comments-only file containing useful tips and information for creating and understanding Unix shell scripts
# 
# -> The first line "#!/bin/bash" is used in every shell script to instruct the operating system to use "bash" (or some other program) as the command interpreter,
# the first two characters of the file must be a shebang, the character sequence "#!", followed by the path to the command interpreter.
# 
# -> When using Windows, in Visual Studio Code, click the lower-right "CRLF/LF" button, and leave it as "LF" when working on Unix shell files, like this one, to avoid runtime errors,
# this is because Windows and Unix use different end-of-line characters (CRLF for Windows, LF for Unix).
# 
# -> The special variable "$#" contains the number of arguments passed (or set with the "set" command) to the script,
# likewise, $1, $2, $3, and so forth contain the positional arguments passed to the script or to a function
# 
# -> Adding "$" at the beginning of an expression in parentheses allows saving the output of the expression to a variable, as: $([expression]),
# likewise, add "$" at the beginning of a variable name to access its value as $my_variable where "my_variable" is the variable name.
# 
# -> Avoid adding "sudo" calls in scripts, advise the user to run the whole script as "sudo" instead.
# 
# -> "$?" returns the exit code of the previous command, which will typically return "0" on success, or a different (greater) number on error.
# 
# -> To supress script/command output, redirection operators are used to redirect output to the null device,
# redirections are sequential, from left to right, like this: [expression] >/dev/null 2>&1
# - stdout (1) file descriptor is redirected to null device (1 is implicit)
# - then, stderr (2) file descriptor is redirected to the same location (&> or >&) of stdout (1), so to the null device too
# Additional sources: 
# https://stackoverflow.com/a/47372890/25878481
# https://catonmat.net/bash-one-liners-explained-part-three
# 
# -> In Bash scripts, "getopt" is a utility for parsing command-line options and arguments. It's often used to handle options in a flexible and user-friendly way.
# It is typically used as: $(getopt -o a:b: --long alpha:,beta: -- "$@") where:
# - The -o option specifies the short options of the script (or function)
# - The --long option specifies the long options of the script (or function)
# - "--" is a sequence used to indicate the end of option arguments, and the start of positional arguments
# getopt option strings can be annotated with flags to indicate option requirements, like making option arguments mandatory or not
# - Absence of ":" or "::" indicates that the preceding option does not require an argument (like when multiple short option letters are next to each other)
# - ":" indicates that the preceding option requires an argument
# - "::" indicates that the preceding option has an optional argument
# - "," is used in the long options string to separate long options
# the output of getopt is combined with a "set" call, and followed by an argument parsing loop that performs certain actions based on the presence or abscense of options
#
# -> Single quotes ('') preserve literal strings, double quotes ("") allow for variable expansion and command substitution, special characters "$" and "\" are interpreted.
# 
# ...
# 
echo "(this is a comments-only script, it does nothing)"