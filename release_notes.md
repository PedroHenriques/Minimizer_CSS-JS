# RELEASE NOTES  

## Version 3.0.0  

### Changes  

- Added support for SASS, SCSS and TypeScript files
- Added the options `ts`, `scss` and `sass` to the watch and ignore rules relating to the handling of TypeScript, SCSS and SASS files respectively
- Added support for multiple files with the same basename
- Discontinued the watch and ignore list `.txt` files and introduced a `bundler.config.json` file
- The program no longer automatically minimizes the output files, since during development it makes debugging less convenient  
This feature is now controlled by the user through a command line flag and the configuration file
- Added support for tagging parts of a file's content that shouldn't be added to an output file
- Improved the handling of the command line interface --> added more commands and support for flags
- The output files built by joining multiple files, previously named `joined.min.*` are now named `bundle.*`
- Each output file now has an auxiliary `.json` file containing information about which files were used to build that output file and whether it is minimized or not
- Removed the functionality where, if a path for an output file wasn't provided, the program would follow a set of rules to decide where to store it  
Now an `out` path is required for each watch rule, where all output files produced by that rule will be stored

### Bug Fixes  

- Fixed a bug that was causing, under certain conditions, some whitespaces to be removed from inside a regex pattern  
This fix required the introduction of an assumption made by the program, explained in the `readme.md` file under the section **Important Assumption made by the Program**

### Other  

- Overall code optimizations and clean up
