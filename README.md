# Minimizer for CSS and JS files
**Minimize your CSS and JavaScript files.**  

Light weight and stand alone (no extra packages/dependencies required)  

This application is built in Ruby, as such your computer needs to have Ruby installed. You can find the Ruby install for your system at ([www.ruby-lang.org](https://www.ruby-lang.org/en/)).  

## What this application will do for you
This application will condense CSS and JavaScript code down to 1 line by removing comments, line breaks and other pieces of text unecessary for the browser to interpret your CSS or Javascript code.  

This minimization process will significantly reduce the size of your files and thus the load time of your websites.  

This application also allows you to minimize several CSS and javascript files into a single minimized file.  
This way you can organize your code into several specialized files and have them all joint into a single minimized file (the one to link in your website).  

## Setup Instructions and Batch File
In order to run the program the file `main.rb` must be called from the command line or terminal.  

The working directory from where the program is called will be considered the **project's root directory**, which will be used when building absolute paths from relative paths in the watch and ignore lists.  

To facilitate calling the program this repository comes with a **batch file**.  

In the batch file the line `ruby path\to\main.rb` must be adjusted by changing `path\to\main.rb` with the path to the `main.rb` file.  

## Use Instructions
Once the application starts, you will be prompted for a command.  

The valid commands are:  
- **help:** displays all the valid commands and useful information
- **exit:** terminates the program
- **run:** starts the scan and minimization of the specified folders and files

Once the application is running it will continuously keep watch over the folders and files specified (see below for more information) and updates the minimized files whenever the source files are changed.  
The scan can be stopped by pressing `CTRL`-`c`.  

By default the application will cycle through the specified folders and files (see below for more information) every 5 seconds.  
This value can be adjusted by inserting the desired number of seconds, to wait between each cycle, when calling the `run` command.  

EX: `run` will start the scan and minimization process waiting 5 seconds (default value) between cycles, while `run 10` will wait 10 seconds between cycles.  

## Supported File Types
Currently this application supports the following file types:  
- css
- js

## Watch List and Ignore List
The way to informe the program of the files to be minimized is by adding paths, absolute or relative, to folders or files in `minimizer_watch.txt` and `minimizer_ignore.txt`.  
The order in which the paths are placed inside both files is irrelevant.  

**NOTE:** Relative paths will be considered to be relative to the project's root directory.  

These two files must be present somewhere in the project's directory tree.  

If changes are made to these files, there is no need to restart the program. The changes will take effect on the next scan cycle.  

### Syntax
Inside `minimizer_watch.txt` and `minimizer_ignore.txt` each line should have only 1 path.  

The syntax to be used for each line is:  

File | Syntax
:--- | :---
minimizer_watch.txt | path/to/file/or/folder [option1\|option2\|...] {location for minimized files}
minimizer_ignore.txt | path/to/file/or/folder [option1\|option2\|...]

**NOTE:** the paths provided to the program can not contain any of the following characters `[]{}`, since those are used to identify the options and the minimized file's location.  

#### Options:

Option | Meaning | Used with paths pointing to | Valid in
:--- | :--- | :--- | :---
css | Search for css files | folders | minimizer_watch.txt and minimizer_ignore.txt
js | Search for js files | folders | minimizer_watch.txt and minimizer_ignore.txt
nosub | Don't search in subfolders | folders | minimizer_watch.txt and minimizer_ignore.txt
join | Join all files found, of each type, in 1 minimized file | folders | minimizer_watch.txt
nojoin | Don't join into 1 minimized file | folders and files | minimizer_ignore.txt

The minimized files will have the name of the original file with a ".min". If the minimized file is a joint of several files, the resulting file will have the name "joined.min".  

**By default, if no options are passed, the application will use the following options: `[css|js]`**  
This means it will search and minimize all .css and .js files, searching in all subfolders (if the path is a folder) and not joining multiple files, i.e., each file will be minimized individualy.  

Aditionaly, if options are provided but not a specific file type, all supported file types will be assumed.  

#### Location where the minimized file(s) will be created:

For each entry of the watch list you can specify where you want the resulting minimized files to be stored.  

The paths provided can be absolute or relative to the project's root directory.  
Any folders in the path that don't exist will be created.  

If no destination is provided the following default behaviours will be used:  
- Files being minimized individualy will be placed in the same folder as their source file
- Files being minimized together into 1 ".min" file will be placed in the last folder common to all the relevant source files  
Example: if the source files are `C:/xampp/htdocs/project/css/main.css` and `C:/xampp/htdocs/project/css/helpers/tables.css` then the minimized file will be placed in `C:/xampp/htdocs/project/css`

## Multi-line Comments

The program, by default, will remove all in-line and multi-line comments.  
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

### 1)
minimizer_watch.txt | minimizer_ignore.txt
:--- | :---
C:/xampp/htdocs/website [css\|nosub] | C:/xampp/htdocs/website/buttons.css

All css files inside the "website" folder, not counting files inside any subfolders and with the exception of "buttons.css", will be minimized individualy, with the resulting ".min" files placed in the same folder as their respective source files.  

### 2)
minimizer_watch.txt | minimizer_ignore.txt
:--- | :---
C:/xampp/htdocs/website [join] | C:/xampp/htdocs/website/temp [css]

All js files inside the "website" folder and its subfolders will be minimized into 1 single ".min" file named "joined.min.js".  
All css files inside the "website" folder and its subfolders, except the "temp" subfolder, will be minimized into 1 single ".min" file named "joined.min.css".  
Both of the resulting minimized files will be placed in the last folder common to their respective relevant source files.  

### 3)
minimizer_watch.txt | minimizer_ignore.txt
:--- | :---
C:/xampp/htdocs/website [js\|join] | C:/xampp/htdocs/website/slider.js [nojoin]
C:/xampp/htdocs/website/slider.js {C:/xampp/htdocs/website/assets} |
C:/xampp/htdocs/website/css/buttons.css |

All js files inside the "website" folder and its subfolders, with the exception of "slider.js", will be minimized into 1 single ".min" file named "joined.min.js" and placed in the last folder common to all the relevant source files.  
The file "slider.js" will be minimized individualy into "slider.min.js", placed in "C:/xampp/htdocs/website/assets".  
The file "buttons.css" will be minimized individualy into "buttons.min.css", placed in the same folder as the source file.  

**NOTE:** if "slider.js", in `minimizer_ignore.txt`, doesn't have the "nojoin" option, then it won't be minimized, individualy or joined, even if "slider.js" is in `minimizer_watch.txt`.  

Application made by **Pedro Henriques** ([www.pedrojhenriques.com](http://www.pedrojhenriques.com))
