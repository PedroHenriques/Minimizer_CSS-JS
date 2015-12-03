# Minimizer for CSS and JS files
**Minimize your CSS and JavaScript files.**

Light weight and self contained (no extra packages/dependencies required)

This application is built in Ruby, as such your computer needs to have Ruby installed. You can find the Ruby install for your system at ([www.ruby-lang.org](https://www.ruby-lang.org/en/)).

## What this application will do for you
This application will condense CSS and JavaScript code down to 1 line by removing comments, line breaks and other pieces of text unecessary for the browser to interpret your CSS or Javascript code.

This minimization process will significantly reduce the size of your files and thus the load time of your websites.

This application also allows you to minimize several CSS and javascript files into a single minimized file. This way you can organize your code into several specialized files and then have them all joint into a single minimized file (the one to link in your website).

## Setup Instructions
Place all the files (unzip if necessary) in a place on your computer that is central to the files you'll be minimizing.
This application can receive absolute or relative paths to the files/folders to be minimized, so you can have the application in a central place or have a copy in each project.

To start the application simply double click the file "app.rb".
Alternatively you may also run "app.rb" via the command line or console.

## Use Instructions
Once the application starts, you will be prompted for a command.
The valid commands are:
- **help:** displays all the valid commands and useful information
- **close:** terminates the application
- **exit:** same as the close command
- **run:** starts the scan and minimization of the specified folders and files

Once the application is running it will continuously keep watch over the folders and files you specified (see below for more information) and update the minimized files whenever the source files are changed. You can stop it by pressing `CTRL`-`c` with the window selected.

By default the application will cycle through the specified folders and files (see below for more information) every 5 seconds.  
This value can be adjusted by inserting the desired number of seconds to wait when calling the RUN command.  
EX: `run` will start the scan and minimization process waiting 5 seconds (default value) between cycles, while `run 10` will wait 10 seconds between cycles.

## Supported File Types
Currently this application supports the following file types:
- .css
- .js

## Watch List and Ignore List
The way you tell the application which files to minimize is by adding paths to folders or files in watch_list.txt and ignore_list.txt.
These paths can be either absolute or relative to "app.rb".
The order in which the paths are placed inside both files is irrelevant.

These two files are, by default, inside the "Data" folder but can be moved, as long as the path to their location is updated in the file "Classes/Minimize.rb". Inside the "initialize" method there are two variables - @watch_path and @ignore_path - which must point to the location of watch_list.txt and ignore_list.txt, respectively.

If changes are made to these files, there is no need to restart the application. The changes will take effect on the next cycle.

### Syntax
Inside watch_list.txt and ignore_list.txt each line should have only 1 path.
Each path can be either absolute or relative to "app.rb" and can point to a file or a folder.

The syntax to be used for each line is:

File | Syntax
:--- | :---
watch_list.txt | path/to/file/or/folder [option1&#124;option2&#124;...] {location for minimized files}
ignore_list.txt | path/to/file/or/folder [option1&#124;option2&#124;...]

**NOTE:** the paths provided to the application can not contain any of the following characters `[]{}`, since those are used to identify the options and the minimized file's location.

#### Options:

Option | Meaning | Used with paths pointing to | Valid in
:--- | :--- | :--- | :---
css | Search for .css files | folders | watch_list.txt and ignore_list.txt
js | Search for .js files | folders | watch_list.txt and ignore_list.txt
nosub | Don't search subfolders | folders | watch_list.txt and ignore_list.txt
join | Join all files found in 1 minimized file per type | folders | watch_list.txt
nojoin | Don't join into 1 minimized file | folders and files | ignore_list.txt

The minimized files will have the name of the original file with a ".min". If the minimized file is a joint of several files, the resulting file will have the name "joined.min".  
These files will be placed in the same folder as the original files.

**By default, if no options are passed, the application will use the following options: `[css|js]`**  
This means it will search and minimize all .css and .js files, searching in all subfolders (if the path is a folder) and not joining multiple files, i.e., each file will be minimized individualy.

Aditionaly, if options are passed but no specific file type, all supported file types will be assumed.

#### Location where the minimized file(s) will be created:

For each entry of the watch list you can specify where you want the resulting minimized files to be stored.

The paths provided can be absolute or relative to "app.rb".  
Any folders in the path that don't exist will be created.

If no destination is provided the following default behaviours will be used:  
- Files being minimized individualy will be placed in the same folder as their source file
- Files being minimized together into 1 ".min" file will be placed in the last folder common to all the relevant source files  
Example: if the source files are `C:/xampp/htdocs/project/css/main.css` and `C:/xampp/htdocs/project/css/helpers/tables.css` then the minimized file will be placed in `C:/xampp/htdocs/project/css`

## Examples

### 1)
watch_list.txt | ignore_list.txt
:--- | :---
C:/xampp/htdocs/website [css&#124;nosub] | C:/xampp/htdocs/website/buttons.css

All .css files inside the website folder, not counting files inside any subfolders and with the exception of buttons.css, will be minimized individualy, with the resulting ".min" files placed in the same folder as their respective source files.

### 2)
watch_list.txt | ignore_list.txt
:--- | :---
C:/xampp/htdocs/website [join] | C:/xampp/htdocs/website/temp [css]

All .js files inside the website folder and its subfolders will be minimized into 1 single .min file named "joined.min.js".  
All .css files inside the website folder and its subfolders, except the temp subfolder, will be minimized into 1 single .min file named "joined.min.css".  
Both of the resulting minimized files will be placed in the last folder common to their respective relevant source files.

### 3)
watch_list.txt | ignore_list.txt
:--- | :---
C:/xampp/htdocs/website [js&#124;join] | C:/xampp/htdocs/website/slider.js [nojoin]
C:/xampp/htdocs/website/slider.js {C:/xampp/htdocs/website/assets} | 
C:/xampp/htdocs/website/css/buttons.css | 

All .js files inside the website folder and its subfolders, with the exception of slider.js, will be minimized into 1 single ".min" file named "joined.min.js" and placed in the last folder common to all the relevant source files.  
The file slider.js will be minimized individualy in "slider.min.js", placed in C:/xampp/htdocs/website/assets.  
The file buttons.css will be minimized individualy in "buttons.min.css", placed in the same folder as the source file.

**NOTE:** if slider.js, in ignore_list.txt, doesn't have the "nojoin" option, then it won't be minimized, individualy or joined, even if slider.js is in watch_list.txt.

Application made by **Pedro Henriques** ([www.pedrojhenriques.com](http://www.pedrojhenriques.com))