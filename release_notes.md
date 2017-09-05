# RELEASE NOTES  

## Version 3.1.1  

### Changes  

- Updated the intro and outro messages
- Renamed the batch file

### Bug Fixes  

- Fixed bug that was preventing the program from correctly searching SCSS and SASS entry point files for their imports

## Version 3.1.0  

### Changes  

- Added support for ES6 compiled TypeScript files, which can have the imported modules stored in a `const` or a `let` besides the ES5 default of `var`
- Added support for ES6 "template literal" strings
- Changed the module import rules from using TypeScript's rules to using NodeJS's rules. This allows for better support when handling external dependencies

### Bug Fixes  

- Fixed the following bugs in the code that creates the `*.combined.js` file:  

  1. When using variables or functions that are exported by that module in an operation other than assignments and some logical comparisons, the `exports.` wasn't being analyzed and processed being left in the `*.combined.js` file
  2. When importing a module's default export, the references to the variable where that import was being stored weren't being replaced by the name of the imported property. Instead a call to `default(` was being left in their place
  3. When handling the use of variables that are being exported by that module in the global scope, the first time each variable is used the `exports.` has to be replaced with a `var ` since it is there that it is being declared

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
