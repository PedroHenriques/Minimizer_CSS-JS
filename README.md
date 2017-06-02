# Bundler and Minimizer for Web files  

**Bundle and Minimize your Web Files.**  
**Supports JavaScript, TypeScript, CSS, SCSS and SASS files.**

Light weight and stand alone (no extra packages/dependencies required). Easy and quick to configure.  

This application is built in Ruby, as such your computer needs to have Ruby installed. You can find the Ruby install for your system at ([www.ruby-lang.org](https://www.ruby-lang.org/en/)).  


## What this application will do for you  

This application will bundle your stylesheets into 1 CSS file and your code files into 1 JavaScript file, allowing you to better organize your code in development, but without requiring the visitors of your website to download multiple files, which will increase the load times of your website.  

Furthermore, this application will minimize those files into 1 line and remove any unnecessary characters, significantly reducing the size of the files your website visitors need to download.  

Another feature of this application is the full support for TypeScript, SCSS and SASS files.  
TypeScript and JavaScript files will be bundled together, as well as CSS, SCSS and SASS being bundled together.  

This application will handle calling for the compilation of these files, using their respective compilers, and in the case of TypeScript files, creating a "combined" file that has all the files in an import chain together, with all the import and export statements resolved.

All of these features make your life as a developer better and the experience of your website visitors better.   


## Setup Instructions and Batch File  

In order to run the program the file `main.rb` must be called from the command line or terminal.  

This program uses a **configuration file** to define its operating parameters. This file will be searched for, by the program, starting from the current working directory used to execute the `main.rb` file and following its sub-directories.  

To facilitate calling the program this repository comes with a **batch file**.  

In the batch file the line `ruby path\to\main.rb` must be adjusted by changing `path\to\main.rb` with the absolute path to the `main.rb` file in your system.  


## Supported File Types  

Currently this application supports the following file types:  
- js
- ts
- css
- scss
- sass

## Basic Explanation of What this Program Does  

The program will search for any files that match each **watch rule** (see below for further detail) removing any files that match any of the **ignore rules** (see below for further detail).  

The relevant files for each watch rule will then be processed. Depending on their file type they might be crawled, compiled and combined or used as they are (see below for further detail).  

If a watch rule has the option to **join**, then all relevant `.js` files, whether they are native JavaScript files or the result of a TypeScript compilation, will be bundled together into 1 JavaScript file and all relevant `.css` files, whether they are native CSS files or the result of a SASS compilation, will be bundled together into 1 CSS file.  
If the option **nojoin** was given instead, then each relevant file will be handled individual and produce 1 output file.  

Finally, if the program is running with the **min** option (see below for further detail) then each output file generated by each of the watch rules will be minimized.  

In order to decide if an output file needs to be rebuilt, all relevant files added to it will be checked for changes after the output file was built. If any relevant file was changed any output file using it will be rebuilt.  

If any of the relevant files are non JavaScript or CSS files, ex: TypeScript, SCSS or SASS, then they will be crawled to find all the files they import.  
If any file in the import chain is modified, the respective entry point file will be recompiled and the output file rebuilt.  


## Use Instructions  

Once the application starts, you will be prompted for a command.  

### **The valid commands are:**  

-> **run**:  

Scans the relevant files, based on the "watch" and "ignore" properties of the configuration file, and checks if any processing needs to be done.  
If any relevant source file is a TypeScript, SCSS or SASS file, the program will call for their compilation and the resulting JavaScript or CSS files added to the output bundle file.  

The syntax for this command is: `run [sleep_timer] [flags]`  

- `sleep_timer`: [OPTIONAL] integer or float with the number of seconds to wait between each scan cycle (only relevant if running in watch mode)

- `flags`: [OPTIONAL] set of flags to apply when running the scan on the relevant files


-> **build**:  

Builds all the output files, compiles all files that need compilation and executes any necessary processing, even if no changes were made to the source files.  
Once the output files have been built the build command ends.  

This command is equivalent to calling `run -f --no-watch`  

The syntax for this command is: `build [flags]`  

- `flags`: [OPTIONAL] set of flags to apply when building the output files


-> **help**:  

Shows help information about the valid commands and their syntax.  

The syntax for this command is: `help [command]`  

- `command`: [OPTIONAL] name of the command detailed information should be displayed


-> **init**:  

Creates a configuration file in the current working directory.  


-> **exit**:  

Terminates the program.  


### **The valid flags are:**  

Flag | Commands | Description
--- | --- | ---
`-w`<br>`--watch` | run | runs the program in "watch mode", which will make the program continuously scan for changes to the relevant files for the watch and ignore rules and rebuild the output files when needed
`--no-watch` | run, build | the program will check if the output files need to be (re)built once and then stop the scan
`-f`<br>`--force` | run, build | forces all output files to be (re)built, including the compilation of all source files that need compilation.<br>If the program is in "watch mode" only the first cycle will be affected
`-m`<br>`--min` | run, build | minimizes output files
`--no-min` | run, build | doesn't minimize output files


## Watch and Ignore Rules  

The core functionality of the program is centered on the concepts of **watch rules** and **ignore rules**.  

The watch rules set the paths and options used to find the files that the program should handle.  

The ignore rules set the paths and options used to ignore some files that might be captured by the watch rules.  

Each watch rule is handled individually and will produce the necessary output files, depending on the number of relevant files matching it and the options affect it.  

All watch rules will be matched against all ignore rules and any relevant files that match, at least, 1 ignore rule will be ignored.  

The watch and ignore rules are set in the configuration file explained in the next section.  


## Configuration File  

The program expects to find a file named `bundler.config.json` somewhere in the project's directory tree.  

The program will search for this file when it starts execution, starting at the current working directory from which the program was executed and going through all its subfolders.  
**NOTE:** If a configuration file can't be found, the program will terminate.  

Any **relative paths** provided in the configuration file will be considered to be relative to the configuration file's path.  

If changes are made to the configuration file, there is no need to restart the program. The changes will take effect on the next scan cycle.  

### Syntax  

The `bundler.config.json` file accepts the following syntax:  

```
{
	"watch": [],

	"ignore": [],

	"options": {}
}
```

-> The **watch** mandatory property contains an *Array* with each value being a *Hash* representing a **watch rule**, accepting the following syntax:  

```
"watch": [
	{
		"paths": ["watch path 1", "watch path 2", ...],
		"out": "path to the directory where the output files will be stored",
		"opts": ["option 1", "option 2", ...],
		"scss_in": ["path to SCSS file 1", "path to SCSS file 1", ...],
		"scss_out": "path to the directory where the compiled SCSS files will be stored",
		"sass_in": ["path to SASS file 1", "path to SASS file 1", ...],
		"sass_out": "path to the directory where the compiled SASS files will be stored",
		"ts_in": ["path to TypeScript file 1", "path to TypeScript file 1", ...],
		"ts_out": "path to the directory where the compiled TypeScript files will be stored"
	},

	{
		...
	}
]
```

Property | Optional | Value Type | Default Value | Description
--- | --- | --- | --- | ---
`paths` | no | array of strings |  | contains the paths, absolute or relative, pointing to files or directories relevant to this watch rule
`out` | no | string |  | path, relative or absolute, to the directory where all the output files produced by this watch rule will be stored
`opts` | yes | array of strings | ["css", "scss", "sass", "js", "ts", "join"] | options regulating this watch rule.<br>the valid options are:<br>`css`: include CSS files<br>`scss`: include SCSS files<br>`sass`: include SASS files<br>`js`: include JS files<br>`ts`: include TS files<br>`nosub`: don't search in sub-directories<br>`join`: bundle files together<br>`nojoin`: don't bundle files together
`scss_in` | yes | array of strings |  | paths, relative or absolute, to the entry point SCSS files<br>these are the files that will be crawled for their imports and then provided to the SASS compiler for compilation
`scss_out` | yes | string |  | path, relative or absolute, to the directory where all the compiled SCSS files, produced by the SASS compiler, will be stored
`sass_in` | yes | array of strings |  | paths, relative or absolute, to the entry point SASS files<br>these are the files that will be crawled for their imports and then provided to the SASS compiler for compilation
`sass_out` | yes | string |  | path, relative or absolute, to the directory where all the compiled SASS files, produced by the SASS compiler, will be stored
`ts_in` | yes | array of strings |  | paths, relative or absolute, to the entry point TypeScript files.<br>these are the files that will be crawled for their imports and then provided to the TypeScript compiler for compilation
`ts_out` | yes | string |  | path, relative or absolute, to the directory where all the compiled TypeScript files, produced by the TypeScript compiler, will be stored

**NOTE:** the following requirements are enforced by the program:  

- If the option `ts` is provided in a watch rule then it must contain the property `ts_in`, even if with an empty array  
- If the option `scss` is provided in a watch rule then it must contain the property `scss_in`, even if with an empty array  
- If the option `sass` is provided in a watch rule then it must contain the property `sass_in`, even if with an empty array  

**NOTE:** If no `ts_out`, `scss_out` or `sass_out` properties are provided and there are `.ts`, `.scss` or `.sass` relevant files to process, the directory where the compiled files will be stored is the source file's directory.  

**NOTE:** In the specific case of TypeScript files, if a path to a `tsconfig.json` files is provided, then the program will ignore any value provided in `ts_out` and instead parse the `tsconfig.json` file to find the path where the TypeScript compiler will actually store the compiled files.  
The program will search for the **outDir** key of the **compilerOptions** property and if it doesn't exist then each compiled file will be stored in the same directory as their source file.  


-> The **ignore** optional property contains an *Array* with each value being a *Hash* representing an **ignore rule**, accepting the following syntax:  

```
"ignore": [
	{
		"paths": ["ignore path 1", "ignore path 2", ...],
		"opts": ["option 1", "option 2", ...]
	},

	{
		...
	}
]
```

Property | Optional | Value Type | Default Value | Description
--- | --- | --- | --- | ---
`paths` | no | array of strings |  | contains the paths, absolute or relative, pointing to files or directories relevant to this ignore rule
`opts` | yes | array of strings | ["css", "scss", "sass", "js", "ts"] | options regulating this ignore rule.<br>the valid options are:<br>`css`: include CSS files<br>`scss`: include SCSS files<br>`sass`: include SASS files<br>`js`: include JS files<br>`ts`: include TS files<br>`nosub`: don't search in sub-directories<br>`nojoin`: these files are only to be ignored for watch rules with the join option


-> The **options** optional property contains a *Hash* with key/value pairs defining various parameters of how the program will operate, accepting the following syntax:  

```
"options": {
	"watch_mode": true or false,
	"minimize": true or false,
	"sleep_timer": positive integer or float,
	"sass_opts": "options to use when calling the SASS compiler",
	"tsc_opts": "options to use when calling the TypeScript compiler",
	"tsconfig": "path to a tsconfig.json file"
}
```

Property | Optional | Value Type | Default Value | Description
--- | --- | --- | --- | ---
`watch_mode` | yes | boolean | false | true will set the program to run in "watch mode"<br>false will set the program to not run in "watch mode"
`minimize` | yes | boolean | false | true will set the program to minimize all output files<br>false will set the program to not minimize output files
`sleep_timer` | yes | integer or float | 5.0 | number of seconds the program will wait between each scan cycle<br>only relevant if the program is in "watch mode"
`sass_opts` | yes | string | "" | options that will be used every time the SASS compiler is called
`tsc_opts` | yes | string | "-m commonjs -t es5 -d  --outDir [the watch rule's out property value]" | options that will be used every time the TypeScript compiler is called
`tsconfig` | yes | string |  | path, relative or absolute, to a `tsconfig.json` file to be used when the TypeScript compiler is called, instead of the **tsc_opts**

**NOTE:** Further information about the configuration syntax can be found in the file located at `data/config_validation.json`.  

**NOTE:** Regarding the `opts` property of both the **watch** and **ignore** fields of the configuration file, the values `css`, `scss`, `sass`, `js` and `ts` are only relevant for paths that point to a directory, where these files types will be searched for.  
This means that if a watch or ignore rule only has paths pointing to files, then there is no need to add any of these `opts` values, since no files will be mass searched for and thus they will have no effect.  


### Configuration Parameter Hierarchy  

Each configuration parameter described above can be set in some or all of the following ways, with the priority being the following:  

- command line arguments
- configuration file --> note that not all configuration options have a configuration file equivalent
- program default values


## Important Assumption made by the Program  

The program assumes that any **/** character used as a division operator will have, at least, 1 whitespace after the **/** and the divisor.  

The reason for this assumption is that the program needs to be able to identify regex objects, which also use the **/** character as their delimiter.  
This creates a potential scenario where a regex object can have the exact same syntax as an arithmetic operation containing at least 2 division operators.  

To distinguish between the 2 cases either a syntax rule that is unique to only one of the cases is used or searching for regex object requires an algorithm that parses the context of a file's content.  

This program took the solution of forcing a syntax rule that is unique to the division operator, which is that it will have, at least, 1 whitespace after itself.  

Consider the following example:  

**code 1**  
```
var gi = 4;

var result = 24 / 3 + Math.randdom() * 10 /gi;
```

**code 2**  
```
var re = / 3 + Math.randdom() * 10 /gi;
```

Both of these codes are valid JavaScript code and yet only by analyzing their context can the distinction between an arithmatic operation and a regex object be made.  

However, by forcing at least 1 whitespace after the **/** character with the meaning of a division operator the distinction is much clearer.  

The text in **code 1** should be:  
```
var gi = 4;

var result = 24 / 3 + Math.randdom() * 10 / gi;
```

The minimized versions of these codes would be:  

**code 1**  
```
var gi=4;var result=24/3+Math.randdom()*10/gi;
```

**code 2**  
```
var re=/ 3 + Math.randdom() * 10 /gi;
```


## TypeScript Files  

**IMPORTANT:** This program requires TypeScript to be installed as a **global** node module.  

This program supports TypeScript files, which can be bundled together with other TypeScript and JavaScript files.  

TypeScript files, unlike JavaScript files, will not be captured by watch rule paths automatically just by adding the `ts` option to that rule.  
This is due to the fact that TypeScript files can import other files, which means that not all `.ts` files are relevant individually.  

The only TypeScript files that will be considered relevant for a watch rule are the ones explicitly provided as **entry point** files, in that rule's `ts_in` property.  

The program will crawl all the entry point files and build a list of all files being imported by them, as well as crawling those imports and so on, building a complete import chain.  
This allows the program to scan every file in the import chain and if any of them has been changed, the respective entry point file will be recompiled, by the TypeScript compiler, and any output files from watch rules that use that entry point file will be rebuilt.  

The way the program resolves module imports is by applying the same rules used by NodeJS, outlined in the [documentation](https://nodejs.org/dist/latest-v8.x/docs/api/modules.html#modules_all_together), with the following caveats:  
- Files with the `.node` extension are not considered  
- Imports of NodeJS core modules are not considered

In terms of the compilation options passed to the TypeScript compiler, the program will use the following priority:  

- use a `tsconfig.json` file, if a path to one was provided in the program's configuration file
- use the specific value for the `tsc_opts` option, if one was provided
- use the default value for the `tsc_opts` option

**Another feature** of this program is that it will produce a "combined" file for each TypeScript entry point file which contains the entry point file and all files in its import chain combined into 1 JavaScript file, with all import and export statements resolved.  
These "combined" files will be stored in the same directory as the compiled files from the TypeScript compiler, and its these files that will be added to the watch rule's output file.  

**NOTE:** This program was designed to handle TypeScript files compiled using the **commonjs** compiler module.  
If any other compiler module is used the program might not be able to resolve all the import and export statements in the resulting JavaScript file.  

**NOTE:** By default the program will not consider any JavaScript file that is the result of the compilation of a TypeScript file as relevant, unless it is the "combined" JavaScript file built from an entry point TypeScript file.  
If a watch rule is intended to affect those JavaScript files, then that rule can't have the `ts` option, or if it has an empty array must be given to the `ts_in` property.  


## SCSS and SASS Files  

This program supports SCSS and SASS files, which can be bundled together with other SCSS, SASS and CSS files.  

Similarly to TypeScript files, these files will be crawled and an import chain will be built for each SCSS and SASS **entry point** file.  

Whenever any file in an import chain is modified, the respective entry point file will be recompiled by the SASS compiler and any output files, for that watch rule, using that entry point will be rebuilt.  

SCSS and SASS files, unlike CSS files, will not be captured by watch rule paths automatically just by adding the `scss` or `sass` options to that rule.  

The only SCSS and SASS files that will be considered relevant for a watch rule are the ones explicitly provided as **entry point** files, in that rule's `scss_in` and `sass_in` properties.  

**NOTE:** By default the program will not consider any CSS file that is the result of the compilation of an SCSS or SASS file as relevant, unless it is the CSS file built from an entry point TypeScript file.  
If a watch rule is intended to affect those CSS files, then that rule can't have the `scss` and/or `sass` option, or if it has an empty array must be given to the `scss_in` and/or `sass_in` property.  


## Files Produced by this Program  

The program will produce the following files:  

- `bundle.css` and `bundle.js`: These output files will be produced for a watch rule that has the `join` option and are the combination of all `css`, `scss` and `sass` files as well as `js` and `ts` respectively  
- `*.min.css` and `*.min.js`: These output files will produced for a watch rule that has the `nojoin` option and are produced for each individual file that matches that rule's paths (and doesn't match the ignore rules). For these cases if the program isn't in "minimize mode" then these files will be a copy of their respective source files
- `*.combined.js`: These files are produced for each TypeScript entry point file and are the result of combining an entry point `.ts` file and all its import chain files and resolving all the import and export statements.  
The program will also make sure that, at maximum, only 1 `use strict;` statement is present and that it is at the top of the file. If none of the source files have this statement then the program will not add it.
- `*.json`: each output file produced by the program will get a JSON file used to keep track of which files were used to build that output file and if it was minimized or not.  
This allows the program to better detect when an output file needs to be rebuilt.


## Tagging File Content for Removal  

Every file added to an output file, directly or as part of an import chain, will be checked for any content inside a pair of tags `/* #bundler remove */`.  

Any content inside a pair of these tags will be removed when that file's content is added to an output file.  

**Example:**  

For a file contain the text:  

```
// imports
import {TextBox} from "./TextBox";
import {getTransitionDuration, css_transition_dur_} from "../main";

/* #bundler remove */
// forward declare these functions to please the requirements of the Engine class
// these functions will be implemented when reading from the script_box.txt file
function textboxExpandCollapse(id: string, only_expand: boolean): void {}
/* #bundler remove */

// this class handles the overall flow control of building the page on the client side
// it will control which text box should be active at any given time
export class Engine {
```

The text that will be added to an output file would be:  

```
// imports
import {TextBox} from "./TextBox";
import {getTransitionDuration, css_transition_dur_} from "../main";

// this class handles the overall flow control of building the page on the client side
// it will control which text box should be active at any given time
export class Engine {
```

**NOTE:** as an advanced information, the regex pattern used by the program to find these tags is `\/\*[\n\t ]*#bundler remove[\n\t ]*\*\/` with the **case insensitive** flag.


## Multi-line Comments and the Minimization Task  

The task of minimizing the output files, by default, will remove all in-line and multi-line comments.  
There is, however, a way to signal the program that specific multi-line comments are to be kept.  

There are 2 ways a multi-line comment can be kept in the minimized version:  

- **Intact:**  
	This will retain a multi-line comment exactly as it is, with all line breaks, tabs and white spaces intact.  
	This format is identified by placing `!!` immediately after the multi-line comment start syntax.

- **Collapsed:**  
	This will collapse a multi-line comment into 1 line, i.e., all tabs and multiple consecutive white spaces will be removed; all line breaks will be converted into a single whitespace.  
	This format is identified by placing `!` immediately after the multi-line comment start syntax.

**EX:**  

### 1)  

```
/*!!****
	This is a multi-line comment
	With line breaks
*****/
```

Is minimized into  

```
/*****
	This is a multi-line comment
	With line breaks
*****/
```

### 2)  

```
/*!****
	This is a multi-line comment
	With line breaks
*****/
```

Is minimized into  

```
/*****This is a multi-line comment With line breaks*****/
```


## Examples  

Consider the following project directory tree:  

```
my_app
 |_ css
    |_ tooltips.css
 |_ js
    |_ tooltips.js
 |_ node_modules
    |_ ...
 |_ sass
    |_ sass1.sass
    |_ sass2.sass
 |_ scss
    |_ general.scss
    |_ mixins.scss
    |_ main.scss
 |_ ts
    |_ classes
       |_ Engine.ts
       |_ TextBox.ts
    |_ main.ts
 |_ bundler.config.json
 |_ package.json
 |_ tsconfig.json
```

And the following import relationships exists:  

- `sass1.sass` imports `sass2.sass`
- `main.scss` imports `general.scss` and `mixins.scss`
- `main.ts` imports `classes/Engine.ts` and `classes/TextBox.ts`

### 1) Simplest case  

If the objective is simply to get 1 CSS and 1 JavaScript file that bundles all of these project's files and stores them in an `assets` directory, then the following `bundler.config.json` file will be enough.  

```
{
 "watch": [
  {
    "paths": ["."],
    "out": "assets",
    "ts_in": ["ts/main.ts"],
    "scss_in": ["scss/main.scss"],
    "sass_in": ["sass/test1.sass"]
  }
 ],

 "options": {
   "tsconfig": "./"
 }
}
```

The changes to the project's directory tree after executing the program's `run` or `build` commands will be:  

```
my_app
 |_ .sass-cache
 |_ assets
    |_ bundle.css (*)
    |_ bundle.css.json (*)
    |_ bundle.js (*)
    |_ bundle.js.json (*)
 |_ js
    |_ classes
       |_ Engine.js
       |_ TextBox.js
    |_ main.combined.js (*)
    |_ main.js
    |_ ...
 |_ sass
    |_ sass1.css
    |_ sass1.css.map
    |_ ...
 |_ scss
    |_ main.css
    |_ main.css.map
    |_ ...
 |_ ts
    |_ declarations
       |_ ...
    |_ ...
 |_ ...
```

The files that were created by the program are marked with an **(*)** while the rest of the changes are made by the TypeScript and SASS compilers.  

**NOTE:** by not providing the `opts` property to the watch rule, the default value will be used which will search for all file of the supported file types, looking in sub-directories and bundling the relevant files into 1 JavaScript and 1 CSS file.  

**NOTE:** the TypeScript compiler was provided with the path to the `tsconfig.json` file referenced in the `bundler.config.json` file.  

**NOTE:** when providing relative paths in the configuration file, using `.` or `./` is equivalent.  

### 2) Adding different paths for the bundle JS and CSS files  

If the following changes are made to the configuration file:  

```
"watch": [
  {
    "paths": ["."],
    "out": "assets/js",
    "opts": ["js", "ts", "join"],
    "ts_in": ["ts/main.ts"]
  },
  {
    "paths": ["."],
    "out": "assets/css",
    "opts": ["css", "scss", "sass", "join"],
    "scss_in": ["scss/main.scss"],
    "sass_in": ["sass/test1.sass"]
  }
]
```

then the project's directory tree would be:  

```
my_app
 |_ assets
    |_ css
       |_ bundle.css
       |_ bundle.css.json
    |_ js
       |_ bundle.js
       |_ bundle.js.json
 |_ ...
```

### 2) Adding ignore rules  

If the following addition is made to the configuration file:  

```
"ignore": [
  {
    "paths": ["js/tooltips.js"],
    "opts": ["nojoin"]
  }
```

then the file `my_app/js/tooltips.js` will no not be used in any watch rule that is **bundling** files in the output files.  

In the case of the previous example, the output file located at `my_app/assets/js/bundle.js` will no longer contain the `my_app/js/tooltips.js` file, as long as the first watch rule has the **join** option.  

**NOTE:** if the watch rule had the **nojoin** option instead, this file wouldn't be ignored.  

**NOTE:** if the ignore rule had `"opts": []` instead, then this file would always be ignored, regardless of which options the watch rule had.  


Application made by **Pedro Henriques** ([www.pedrojhenriques.com](http://www.pedrojhenriques.com))
