# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 															 #
# Ruby Minimizer for CSS and JS files v2.0.0				 #
# 															 #
# Copyright 2017, PedroHenriques 							 #
# http://www.pedrojhenriques.com 							 #
# https://github.com/PedroHenriques 						 #
# 															 #
# Free to use under the MIT license.			 			 #
# http://www.opensource.org/licenses/mit-license.php 		 #
# 															 #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class Application
	attr_accessor :sleep_time

	def initialize()
		# class variable storing the default sleep time between each watch cycle
		@@sleep_time_default = 5.0

		# instance variable storing an instance of the Cli class
		@cli_obj = Cli.new(self)

		# instance variable storing the sleep time between each watch cycle
		@sleep_time = -1.0

		# instance variables storing the absolute path to the current project's root directory
		# it is the current working directory where the program was executed
		@project_root = Dir.getwd

		# instance variables storing an array with the paths to watch and ignore
		# these variables are populated by buildWatchList() and buildIgnoreList()
		@watch_list = nil
		@ignore_list = nil

		# instance variables storing the absolute paths to the watch and ignore files
		@watch_path = ""
		@ignore_path = ""

		# instance variables with the names of the watch and ignore list files
		@watch_file_basename = "minimizer_watch.txt"
		@ignore_file_basename = "minimizer_ignore.txt"

		# find the watch and ignore files in this project's directory tree
		files_found = findFiles("**/{#{@watch_file_basename},#{@ignore_file_basename}}", @project_root)

		# loop through the files found
		files_found.each { |file_basename,file_path|
			# check if this file is the watch list
			if file_basename.eql?(@watch_file_basename)
				# it is
				@watch_path = file_path
			# check if this file is the ignore list
			elsif file_basename.eql?(@ignore_file_basename)
				# it is
				@ignore_path = file_path
			end
		}

		# local variables used to control whether the watch and ignore lists should be built
		build_lists = true

		# check if the watch list was found
		if @watch_path.empty?
			# it wasn't
			# print error message
			@cli_obj.printStr("=> ERROR: The watch list file (#{@watch_file_basename}) couldn't be found in this project's directory tree", false)

			# no need to build the lists
			build_lists = false
		end

		# check if the ignore list was found
		if @ignore_path.empty?
			# it wasn't
			# print error message
			@cli_obj.printStr("=> ERROR: The ignore list file (#{@ignore_file_basename}) couldn't be found in this project's directory tree", false)

			# no need to build the lists
			build_lists = false
		end

		# instance variable storing the supported file types
		@valid_file_types = ["css", "js"]

		# instance variable storing the default options, to be used when no options are passed for a path
		@default_opts = @valid_file_types.join("|")

		# instance variable storing the modified time of the watch and ignore files at the time of last list build
		# this allows for the watch and ignore list files to be changed without requiring a restart of the program
		# format: [file basename] = file mtime
		@lists_mtime = Hash.new

		# check if the lists should be built
		if build_lists
			# they should
			# build the watch list
			if !buildWatchList()
				# the watch list couldn't be built
				# terminate the program
				raise Interrupt
			end

			# build the ignore list
			if !buildIgnoreList()
				# the ignore list couldn't be built
				# terminate the program
				raise(Interrupt)
			end
		else
			# they shouldn't -> this is because the files with the watch and
			# ignore items couldn't be found
			# terminate the program
			raise(Interrupt)
		end
	end

	# getter for the class variable sleep_time_default
	def self.sleep_time_default
		return(@@sleep_time_default)
	end

	# main function of the class -> will ask the user for a command and will
	# call the necessary functions to scan and minimize files as needed
	def run()
		begin
			# controls the main loop
			run = true

			# main loop
			while run
				# signal the Cli class to ask the user for commands
				action = @cli_obj.askCommand()

				# check if the command triggers the termination of the program
				if action == -1
					# it does
					run = false
				# check if the command triggers the start of the scan of source files
				elsif action == 1
					# it does
					begin
						# start the scan
						watch()
					rescue Interrupt => e
						# the user pressed CTRL-C
						# ask for the next command
						next
					end
				end
			end
		rescue Interrupt => e
			# the user pressed CTRL-C so terminate the program
			# bubble the exception up
			raise(e)
		end

		# at this point the program will terminate, so print the outro message
		printOutroMsg()
	end

	# calls for the print of the program's outro message
	def printOutroMsg()
		# print outro message
		@cli_obj.printStr("\n=> Thank you for using this application!\nFollow this application at https://github.com/PedroHenriques/Minimizer_CSS-JS\n", false)
	end

	# scans each of the watch list items and processed them as necessary
	def watch()
		# check if a specific and valid sleep time was provided for this scan
		if @sleep_time < 1.0
			# it wasn't -> use the default sleep time
			sleep_seconds = @@sleep_time_default
		else
			# it was -> use it
			sleep_seconds = @sleep_time
		end

		# print running message
		@cli_obj.printStr("\nwatching for changes...\n=> press CTRL-C to terminate\n", false)

		# loops until the user presses CTRL-C
		while true
			# check if the watch list is up-to-date
			if File.stat(@watch_path).mtime > @lists_mtime[@watch_file_basename]
				# the watch list file is newer than the one used to build the current @watch_list
				# build the watch list
				if !buildWatchList()
					# the watch list couldn't be built
					# terminate the program
					raise(Interrupt)
				end
			end

			# check if the ignore list is up-to-date
			if File.stat(@ignore_path).mtime > @lists_mtime[@ignore_file_basename]
				# the ignore list file is newer than the one used to build the current @ignore_list
				# build the ignore list
				if !buildIgnoreList()
					# the ignore list couldn't be built
					# terminate the program
					raise(Interrupt)
				end
			end

			# loop through each of the watch paths
			@watch_list.each { |item|
				# stores the files to check for this path
				files = Array.new

				# check if this item's path is a directory
				if File.directory?(item[:path])
					# it is
					# navigate this folder and search for all the files matching this item's options
					files = processWatchPath(item[:path], item[:opts], item[:min_path])
				# check if this item's path is a file
				elsif File.exist?(item[:path])
					# it is
					# store the file
					files.push({
						# if no destination for the .min file was provided, store it in the same folder as the source file
						:min_path => (item[:min_path].empty? ? File.dirname(item[:path]) : item[:min_path]),
						:file_paths => item[:path]
					})
				else
					# this item's path is not valid
					# print warning message
					@cli_obj.printStr("WARNING: The path \"#{item[:path].to_s}\" in the watch list doesn't exist!", true)

					# move to next watch_list element
					next
				end

				# check if any files were found
				if files.empty?
					# no, so move to next watch_list element
					next
				end

				# run the files found against the ignore list
				files = checkAgainstIgnore(files)

				# loop through each validated file
				files.each { |file|
					# check if this watch list entry has any relevant files to process
					if file[:file_paths].empty?
						# it doesn't, so move on
						next
					end

					# check if this item refers to joining multiple files into 1 minimized file
					if file[:file_paths].is_a?(Array)
						# it does
						joining = true

						# grab the first path in the array of files to be joined
						# NOTE: this will only be used to determine the minimized file's path
						# 		when the "joined.min.*" file is created below, all files will be used
						file_current = file[:file_paths].first
					else
						# it doesn't -> minimizing this file on its own
						joining = false

						# get this file's path
						file_current = file[:file_paths]
					end

					# get this file's basename
					file_basename = File.basename(file_current)

					# find the position of the last "." in this file's basename
					pos_aux = file_basename.reverse.index(".")

					# check if there are any "."
					if pos_aux === nil
						# there aren't, so this file doesn't have an explicit extension
						# move on to next file
						next
					end

					# determine the starting position of this file's extension
					file_ext_pos = file_basename.length - file_basename.reverse.index(".")

					# check if this file will be joint minimized
					if joining
						# it will
						# this file's minimized path will be the "joined.min.*" file's path
						file_min_path = "#{file[:min_path]}/joined.min.#{file_basename.slice(file_ext_pos..-1)}"
					else
						# it won't
						# this file's minimized path will be based on this file's basename
						file_min_path = "#{file[:min_path]}/#{file_basename.slice(0...file_ext_pos-1)}.min.#{file_basename.slice(file_ext_pos..-1)}"
					end

					# check if this minimized file is up-to-date
					if !minUpToDate(file_min_path, file[:file_paths].clone)
						# it isn't
						# create the raw version of the minimized file
						# this raw version only contains all the relevant file's contents, but it hasn't been
						# properly minimized
						if createMinFile(file_min_path, file[:file_paths].clone)
							# check the size of the raw version of the minimized file
							# if the size is zero, then all of it's source files are empty
							raw_min_size = File.new(file_min_path).size

							# execute this file's minimization
							if raw_min_size == 0 or minimizeFile(file_min_path)
								# the source files are empty or the minimization was successful
								# display message informing the file was created/updated
								@cli_obj.printStr("UPDATED: #{file_min_path}", true)
							else
								# the source files aren't empty and the minimization failed
								# display message informing of an error
								@cli_obj.printStr("WARNING: an error occured while minimizing the file #{file_min_path}!", true)
							end
						else
							# display message informing of an error
							@cli_obj.printStr("WARNING: an error occured while joining the specified files into #{file_min_path}!", true)
						end
					end
				}
			}

			# wait before starting the next scan cycle
			sleep(sleep_seconds)
		end
	end

	private

		# builds the watch list, storing the result in @watch_list
		# returns true if successful, false otherwise
		def buildWatchList()
			# build the watch list
			@watch_list = buildList(@watch_path)

			# check if the watch list was successfully built
			if @watch_list === nil
				# it wasn't
				# print error message
				@cli_obj.printStr("=> ERROR: The watch list couldn't be built. Please confirm that it's syntax is correct", false)

				# return a failure
				return(false)
			end

			# return a success
			return(true)
		end

		# builds the ignore list, storing the result in @ignore_list
		# returns true if successful, false otherwise
		def buildIgnoreList()
			# build the ignore list
			@ignore_list = buildList(@ignore_path)

			# check if the ignore list was successfully built
			if @ignore_list === nil
				# it wasn't
				# print error message
				@cli_obj.printStr("=> ERROR: The ignore list couldn't be built. Please confirm that it's syntax is correct", false)

				# return a failure
				return(false)
			end

			# return a success
			return(true)
		end

		# this method builds the watch and ignore lists, based on their respective files
		# receives the absolute path to the file used to build the list
		# returns an array of hashes with format:
		# [int index] = {:path => "abs path to watch/ignore", :opts => "opt1|opt2...", :min_path => "abs path to store the .min file(s)"}
		# or returns nil if the list couldn't be built
		def buildList(abs_path)
			# stores the final data
			list = Array.new

			# check if a path was provided
			if abs_path.empty?
				# it wasn't
				return(nil)
			end

			line_count = 1
			File.new(abs_path, "r").each { |line|
				# replace any \ with / on any path in this line
				line = line.to_s.strip.gsub(/\\/, "/")

				# prepare this line's data hash
				line_data = {
					:path => "",
					:opts => "",
					:min_path => ""
				}

				# find the index where the options start
				pos_opts_i = line.index(/\[/)

				# check if any options were provided
				if pos_opts_i != nil
					# they were
					# find the index where the options end
					pos_opts_e = line.index(/\]/)

					# check if there is a ], signaling the end of the options
					if pos_opts_e === nil
						# there isn't
						# print message
						@cli_obj.printStr("WARNING: There is a syntax error in #{abs_path} on line #{line_count} with the options.", true)

						# move to next line
						next
					end

					# grab the options string and split into an array
					aux_opts_a = line.slice(pos_opts_i+1...pos_opts_e).strip.chomp.downcase.split("|")

					# used to known if the options include any of the valid file types
					has_ftype = false

					# loop through all the valid file types
					@valid_file_types.each { |ftype|
						# check if the options include this file type
						if aux_opts_a.include?(ftype)
							# it does
							has_ftype = true

							# no need to continue checking
							break
						end
					}

					# check if a valid file types was used
					if !has_ftype
						# it wasn't
						# add all of the valid file types
						aux_opts_a += @valid_file_types
					end

					# store this line's options as a string
					line_data[:opts] = aux_opts_a.join("|")
				else
					# they weren't
					# use the default options
					line_data[:opts] = @default_opts
				end

				# find the index where the .min file's location starts
				pos_min_i = line.index(/\{/)

				# check if a location for the .min files was provided
				if pos_min_i != nil
					# it was
					# find the index where the .min file's location ends
					pos_min_e = line.index(/\}/)

					# check if there is a }, signaling the end of the .min location
					if pos_min_e === nil
						# there isn't
						# print message
						@cli_obj.printStr("WARNING: There is a syntax error in #{abs_path} on line #{line_count} with the minimized file's location.", true)

						# move to next line
						next
					end

					# store this line's .min absolute path
					line_data[:min_path] = File.absolute_path(line.slice(pos_min_i+1...pos_min_e).strip.chomp, @project_root)
				end

				# find the position in this line where the path to watch/ignore ends
				# depending on the syntax used for this line
				# check if both options and .min location exists
				if pos_opts_i != nil and pos_min_i != nil
					# they do
					# check which one appears first on this line
					if pos_opts_i < pos_min_i
						# it's the options
						pos_path_e = pos_opts_i - 1
					else
						# it's the .min location
						pos_path_e = pos_min_i - 1
					end
				# check if only the options exist
				elsif pos_opts_i != nil
					# yes
					pos_path_e = pos_opts_i - 1
				# check if only the .min location exist
				elsif pos_min_i != nil
					# yes
					pos_path_e = pos_min_i - 1
				else
					# neither the options nor the .min location exists
					pos_path_e = -1
				end

				# store this line's absolute path of the file to watch/ignore
				line_data[:path] = File.absolute_path(line.slice(0..pos_path_e).strip.chomp, @project_root)

				# add this line's data to the list
				list.push(line_data)

				# add 1 to the line counter
				line_count += 1
			}

			# check if this list is empty
			if !list.empty?
				# it isn't
				# sort the list by path, from the lower to the higher path
				list.sort! {|h1,h2| h2[:path] <=> h1[:path]}
			end

			# store this list's file modified time
			@lists_mtime[File.basename(abs_path)] = File.stat(abs_path).mtime

			# return the final data
			return(list)
		end

		# searches for the provided pattern (array or string), starting in search_path and following any sub-folders as needed
		# receives an array with basenames and a string with an absolute path to a directory
		# returns a hash with format: [file basename] = file absolute path
		def findFiles(search_pattern, search_path)
			# stores the files found
			files_found = Hash.new

			# check if basenames were given and if the path points to a folder
			if search_pattern.empty? or !File.directory?(search_path)
				# no basenames were provided or the search path is not a directory
				return(files_found)
			end

			# replace any \ with / on the search path
			search_path = search_path.gsub(/\\/, "/")

			# temporarily change the CWD to the provided path
			Dir.chdir(search_path) do
				Dir.glob(search_pattern) { |file_rel_path|
					# replace any \ with / on this path
					file_rel_path = file_rel_path.gsub(/\\/, "/")

					# store this file's absolute path
					files_found[file_rel_path.split("/").last] = "#{search_path}/#{file_rel_path}"
				}
			end

			# return the final data
			return(files_found)
		end

		# checks an array of file hashes agaist the ignore list
		# returns a hash with the same format as the input, but only with the files that
		# are to be watched
		def checkAgainstIgnore(watch_files)
			# check if the ignore list is empty
			if @ignore_list.empty?
				# it is, so nothing to do
				return(watch_files)
			end

			# stores the final data
			result = Array.new

			# loop through each group of watch files
			watch_files.each { |watch_item|
				# check if this watch item has an array of paths
				if watch_item[:file_paths].is_a?(Array)
					# yes -> we're joining the array's files into 1 minimized file
					joining = true

					# all these files will be returned inside an array
					result.push({
						:min_path => watch_item[:min_path],
						:file_paths => Array.new
					})

					# grab the last file path from the array
					watch_item_current = watch_item[:file_paths].pop
				else
					# no -> path is pointing to a file, use it as is
					joining = false

					# grab the file path
					watch_item_current = watch_item[:file_paths]
				end

				# loop until there are no more paths to check, in this watch item
				begin
					# controls whether this path will be watched or not
					to_watch = true

					# search the ignore list for a relevant item
					@ignore_list.each { |ig_item|
						# check if this ignore list entry is relevant for the current watch list item
						# the ignore list is already sorted from the lowest to highest folder structure, so
						# the first relevant item found is the one to use

						# create array with the ignore list folder's options
						ig_item_opts = ig_item[:opts].split("|")

						# check if this ignore list item is a folder
						if File.directory?(ig_item[:path])
							# it is
							# split the watch list file's basename from the directory path
							file_detail = File.split(watch_item_current)

							# determine the ignore list's folder degree of parenthood to this watch list file
							folder_comparison = fileFolderRel(watch_item_current.downcase, ig_item[:path].downcase)
							if folder_comparison === 1
								# the ignore list folder is the 1st degree parent of the watch list file
								# i.e., it's the folder the file is in
								# in this case the folder's "nosub" option is irrelevant

								# check the watch list file's extension against the ignore list directory's options
								# and the join or no join status
								if ig_item_opts.include?(file_detail[1].split(".").last) and (!ig_item_opts.include?("nojoin") or joining)
									# the ignore list parent folder is set to ignore files of this type
									# and either it's ignoring all operations or just joining and we're doing one
									# so skip this watch list item
									to_watch = false
								end

								# a relevant ignore list item was found, so no need to continue checking the rest
								break
							elsif folder_comparison > 1
								# the ignore list folder is the 2nd or higher degree parent of the watch list file
								# i.e., the watch list file is in a subfolder of this ignore list folder
								# in this case the folder's "nosub" option is relevant

								# check if we're ignoring just files inside this one folder, or in all its subfolders as well
								# and check the file type and the join or no join status
								if !ig_item_opts.include?("nosub") and ig_item_opts.include?(file_detail[1].split(".").last) and (!ig_item_opts.include?("nojoin") or joining)
									# we're ignoring files in this folder and its subfolders
									# and it's set to ignore files of this type
									# and either it's ignoring all operations or just joining and we're doing one
									# so skip this watch list item
									to_watch = false
								end

								# a relevant ignore list item was found, so no need to continue checking the rest
								break
							end
						# check if it's a file and specificaly the same file as this watch list item
						elsif File.exist?(ig_item[:path]) and watch_item_current.downcase.eql?(ig_item[:path].to_s.downcase)
							# it is
							# check if we don't want this file minimized or if we just don't want it to be minimized in a joint file
							if !ig_item_opts.include?("nojoin") or joining
								# either this file is not to be minimized (dosn't have nojoin)
								# or it's not to be minimized in joint actions and we're trying to do so (has nojoin and we're joining)
								# skip this file
								to_watch = false

								# a relevant ignore list item was found, so no need to continue checking the rest
								break
							end
						end
					}

					# check if this watch list item is to be watched
					if to_watch
						# it is
						# check if this file will be joint minimized
						if joining
							# it will
							# add this file's absolute path to the final data, in its array of files to be joined
							result.last[:file_paths].push(watch_item_current)
						else
							# it won't
							# add this file's path to the final data
							result.push({
								:min_path => watch_item[:min_path],
								:file_paths => watch_item_current
							})

							# this path was pointing to a file, so there are no more paths to check
							# move on to next watch list item
							break
						end
					end

					# check if this watch list item has an array of paths (when joining)
					if joining
						# it does
						# check if there are any more paths to check for this watch list item
						if !watch_item[:file_paths].empty?
							# there are
							# grab the next path and loop again
							watch_item_current = watch_item[:file_paths].shift
						else
							# there aren't
							# move on to next watch list item
							break
						end
					else
						# it doesn't
						# there are no more itms in this watch list item
						# move on to next one
						break
					end
				end while true
			}

			# return the final data
			return(result)
		end

		# receives a path to a folder and seaches for files that match the options
		# will ignore all files that have as name: *.min.[one of the valid file types]
		# returns an array with format:
		# [int index] = {:min_path => absolute path to store the minimized file, :file_paths => array of absolute file paths}
		def processWatchPath(dir_path, dir_opts, min_path)
			# local variable where the files found will be stored
			# as well as the path where their .min files should be stored
			files = Array.new

			# if the path doesn't point to a folder, return
			if !File.directory?(dir_path)
				return(files)
			end

			# if no options are passed, assume the default options
			if dir_opts.empty?
				dir_opts = @default_opts
			end

			# build array with options
			opts = dir_opts.split("|")

			# check if the relevant files for this watch path are to be joined into 1 minimized file
			if opts.include?("join")
				# yes
				joining = true

				# stores, for each relevant file type, an array of file absolute paths to be joined
				# format: [file type] = array of absolute paths
				files_to_join = Hash.new

				# check if a location for the joint minimized file was provided
				if min_path.empty?
					# it wasn't
					# stores the location of the joint minimized file for each relevant file type
					# format: [file type] = absolute paths
					joined_location = Hash.new
				end
			else
				# no
				joining = false
			end

			# stores the file types relevant for this watch path
			relevant_file_types = Array.new

			# loop through each valid file type
			@valid_file_types.each { |file_type|
				# check if this file type is relevant for this watch path
				if opts.include?(file_type)
					# it is
					# store it as a relevant file type
					relevant_file_types.push(file_type)

					# check if a joint minimized file will be created
					if joining
						# yes
						# create a key for this file type in files_to_join
						files_to_join[file_type] = Array.new

						# check if a location for the joint minimized file was provided
						if min_path.empty?
							# it wasn't -> the joint minimized file will be stored in the
							# upper most directory common to all relevant files
							# create a key for this file type in joined_location
							joined_location[file_type] = ""
						end
					end
				end
			}

			# check if any valid file types are relevant
			if relevant_file_types.empty?
				# no, so bail out
				return(files)
			end

			# build the base search pattern to be used
			search_pattern = "*.{#{relevant_file_types.join(",")}}"

			# check if we want to search inside subfolders
			if !opts.include?("nosub")
				# yes -> adjust search pattern to search folders recursively
				search_pattern = File.join("**", search_pattern)
			end

			# find all relevant files for this watch path
			files_found = findFiles(search_pattern, dir_path)

			# build the regex string to identify minimized files
			regex_minimized = ".\.min\.(#{relevant_file_types.join("|")})"

			# check if these files will be joined
			if joining
				# they will
				# loop through each file found
				files_found.each { |file_basename,file_abs_path|
					# check if this file is a minimized file
					if file_abs_path.match(regex_minimized) != nil
						# it is, so ignore it
						next
					end

					# find the index of the last "." in this file's basename
					aux_pos = file_basename.length - file_basename.reverse.index(".")
					# find this file's type
					file_type = file_basename.slice(aux_pos..-1)

					# get this file's directory path
					file_dirname = File.dirname(file_abs_path)

					# check if a location for the joint minimized file was provided
					if min_path.empty?
						# it wasn't
						# need to check if this file changes the location where the joint minimized file will be stored
						# check if there is already a tentative path
						if joined_location[file_type].empty?
							# there isn't, so for now store in this file's directory
							joined_location[found_file_type] = file_dirname
						# there is -> check if this file's directory is the current tentative path
						elsif !joined_location[file_type].eql?(file_dirname)
							# it isn't the same, so determine the new tentative path
							joined_location[file_type] = commonPath(joined_location[file_type], file_dirname)
						end
					end

					# add this file to the array of files to be joined, based on this file's type
					files_to_join[file_type].push(file_abs_path)
				}

				# loop through the files to join for each file type
				files_to_join.each { |file_type,abs_paths|
					# if this file type has at least 1 file found, add it to the result set
					if !abs_paths.empty?
						# add these files to the final data
						files.push({
							# if no destination for the minimized file was provided, store it in the chosen joined location
							:min_path => (min_path.empty? ? joined_location[file_type] : min_path),
							:file_paths => abs_paths
						})
					end
				}
			else
				# they won't
				# loop through each file found
				files_found.each { |file_basename,file_abs_path|
					# check if this file is a minimized file
					if file_abs_path.match(regex_minimized) != nil
						# it is, so ignore it
						next
					end

					# add this file to the final data
					files.push({
						# if no destination for the minimized file was provided, store it in the same folder as the source file
						:min_path => (min_path.empty? ? File.dirname(file_abs_path) : min_path),
						:file_paths => file_abs_path
					})
				}
			end

			# return the final data
			return(files)
		end

		# receives the path to the minimized file and the source file(s)
		# return TRUE if the minimized file is up-to-date or FALSE if it needs to be rebuilt
		def minUpToDate(min_path, sources)
			# check if the minimized file exists
			if !File.exist?(min_path)
				# it doesn't, so return not up-to-date
				return(false)
			end

			# check if this minimized file is a joint from multiple files
			if sources.is_a?(Array)
				# it is
				# grab the first element of sources
				sources_current = sources.shift

				joining = true
			else
				# it isn't
				# minimizing a file on its own, so use as is
				sources_current = sources

				joining = false
			end

			# loop until there are no more files in source to check
			begin
				# check if the current source file exists
				if !File.exist?(sources_current)
					# it doesn't, so return not up-to-date
					return(false)
				end

				# check if the current source file is newer than the minimized file
				if File.stat(sources_current).mtime > File.stat(min_path).mtime
					# it is, return not up-to-date
					return(false)
				else
					# it isn't
					# check if there are more source files to process
					if joining and !sources.empty?
						# yes
						# grab the next element of sources
						sources_current = sources.shift
					else
						# no
						# clear the current source file's path to exit the loop
						sources_current = ""
					end
				end
			end while sources_current.length > 0

			# at this point the minimized file is up-to-date
			return(true)
		end

		# receives the path to the minimized file and the source file(s)
		# return TRUE if the minimized file was created or FALSE otherwise
		def createMinFile(min_path, sources)
			# check if this minimized file is a joint from multiple files
			if sources.is_a?(Array)
				# it is
				# grab the first element of sources
				sources_current = sources.shift

				joining = true
			else
				# it isn't
				# minimizing a file on its own, so use as is
				sources_current = sources

				joining = false
			end

			# controls if the minimized file was successfully created
			result = true

			# check if the minimized file already exists
			if File.exist?(min_path)
				# it does, so remove all contents
				File.truncate(min_path, 0)
			else
				# it doesn't
				# get the directory hierarcy of the minimized file
				directories = File.dirname(min_path).split("/")

				# if any of those directories don't exist, create them
				dir_path = ""
				directories.each { |directory|
					# build the absolute path so far
					dir_path += (dir_path.empty? ? "" : "/") + directory

					# check if this directory exists
					if !Dir.exist?(dir_path)
						# it doesn't, so create it
						begin
							Dir.mkdir(dir_path)
						rescue SystemCallError
							# couldn't create this directory
							# return failure
							return(false)
						end
					end
				}
			end

			# open the minimized file in append mode (will create the file if it doesn't exist)
			file_obj = File.new(min_path, "a")

			# loop until all source files have been added to the minimized file
			begin
				begin
					# add the current source file to the minimized file
					file_obj << IO.read(sources_current)

					# check if there are more source files to process
					if joining and !sources.empty?
						# yes
						# grab the next element of sources
						sources_current = sources.shift
					else
						# no
						# clear the current source file's path to exit the loop
						sources_current = ""
					end
				rescue Exception => e
					# something went wrong while joining the multiple files
					result = false

					# clear the current source file's path to exit the loop
					sources_current = ""
				end
			end while sources_current.length > 0

			# close the File object and resolve any pending write actions
			file_obj.close

			# at this point the minimized file was successfully created
			return(result)
		end

		# receives a path to a file and will edit it to minimize it
		# return TRUE if successful or FALSE otherwise
		def minimizeFile(file_path)
			# open the file in read-write mode, without truncating
			file = IO.read(file_path, mode: "r")

			# stores the minimized text as it is built
			min_str = ""

			# stores temporary parts of the file for processing
			aux_str = ""

			# variables to help keep track of strings in the source file
			pos_str_i = 0 # is always at the start of the chunk of text to be changed
			pos_str_e = 0 # is always at the position after the end of the chunk of text to be changed
			inside_str = false

			# variables to help with regex
			re_line_break = /(\r|\n)/
			re_inline_comment = /(\/\/)/
			re_multiline_comment_start = /(\/\*)/
			re_multiline_comment_end = /(\*\/)/
			multiline_comment_keep_1line = "!"
			multiline_comment_keep_intact = "!!"

			# stores all characters that don't need to have a whitespace before or after
			no_whsp_chars = [";",":",",","{","}","[","]","(",")","+","-","*","<",">","||","&&","=","!="]

			# loop while there's content to process
			# NOTE: the logic used is based on the existance of strings in the minimized file
			# 		since strings are not to be processed, the code will search for the start of the next string
			# 		and process any content that is between strings
			while pos_str_e < file.length - 1
				# check if this iteration's chunk is a string
				if inside_str
					# it is
					# find the closing quote to the currently open string
					# NOTE: the closing quote has to be of the same type as the opening quote (single or double)
					# 		at this point pos_str_e has the end index of the last iteration's chunk
					pos_str_e = file.index(file.slice(pos_str_e), pos_str_e + 1)
				else
					# it isn't
					# find the next single or double quote in the source file
					pos_str_e = file.index(/[\"\']/, pos_str_e + 1)
				end

				# check if a quote was found
				if pos_str_e === nil
					# it wasn't, so set the end index to the EOF
					pos_str_e = file.length
				else
					# it was -> validate it
					# check if this iteration's check is a handling a string
					if inside_str
						# it is
						# check if the quote found is escaped
						if pos_str_e > 0 and file.slice(pos_str_e - 1).match(/\\/) != nil
							# it is, so ignore it
							next
						end
					else
						# it isn't -> make sure this quote is not inside a comment (single or multi line)
						# get this iteration chunk's text
						aux_str = file.slice(pos_str_i...pos_str_e)

						# stores the start and end index of any relevant comments
						comment_pos = Array.new

						# multiline comment
						# find the start index of the multiline comment closest to the quote
						# NOTE: using re_multiline_comment_end because the string is reversed, so /* becomes */
						comment_pos[0] = aux_str.reverse.index(re_multiline_comment_end)

						# check if a multiline comment was found
						if comment_pos[0] != nil
							# it was
							# find the end index to this multiline comment
							# NOTE: using re_multiline_comment_start because the string is reversed, so */ becomes /*
							comment_pos[1] = aux_str.reverse.index(re_multiline_comment_start)

							# check if this quote is inside this multiline comment
							# NOTE: the relation between start and end positions is reversed, because the reverse string was used to find those positions
							if comment_pos[1] === nil or comment_pos[0] < comment_pos[1]
								# it is
								# NOTE: if there is no end to the comment or the closest end is before the start then the quote is inside it
								# ignore this quote
								next
							end
						end

						# inline comment
						# find the start index of the inline comment closest to the quote
						comment_pos[0] = aux_str.reverse.index(re_inline_comment)

						# check if a valid inline comment was found
						# NOTE: ignore a // if they are part of a URL
						if comment_pos[0] != nil and aux_str.slice(comment_pos[0]-5...comment_pos[0]).match(/http:/) === nil and aux_str.slice(comment_pos[0]-6...comment_pos[0]).match(/https:/) === nil
							# it was
							# find the end index to this inline comment, which is the closest line break
							comment_pos[1] = aux_str.reverse.index(re_line_break)

							# check if this quote is inside this inline comment
							# NOTE: the relation between start and end positions is reversed, because the reverse string was used to find those positions
							if comment_pos[1] === nil or comment_pos[0] < comment_pos[1]
								# it is
								# NOTE: if there is no end to the comment or the closest end is before the start (then we have an open comment, meaning the quote is inside a comment)
								# ignore this quote
								next
							end
						end
					end
				end

				# check if this iteration's chunk is a string
				if inside_str
					# it is -> don't change any of the text inside a string
					# get this iteration chunk's text, including both the start and end quotes
					aux_str = file.slice(pos_str_i..pos_str_e)

					# adjust control variables for next iteration
					# since this iteration was handling a string, the next iteration won't be handling a string
					inside_str = false

					# the start index for the next iteration is just after this iteration's end index
					pos_str_i = pos_str_e + 1
				else
					# it isn't
					# get this iteration chunk's text, excluding the end quotes
					aux_str = file.slice(pos_str_i...pos_str_e)

					# stores the index to start searching for comments in this iteration chunk's text
					regex_start = 0

					# loop while there are inline comments to process
					match_data = aux_str.match(re_inline_comment, regex_start)
					while match_data != nil
						# stores the start and end indexes of this comment
						comment_pos = Array.new

						# get the start index for this comment
						comment_pos[0] = match_data.begin(1)

						# check if the "//" found is an actual inline comment
						if aux_str.slice(comment_pos[0]-5...comment_pos[0]).match(/http:/) != nil or aux_str.slice(comment_pos[0]-6...comment_pos[0]).match(/https:/) != nil
							# it isn't, so ignore this "//"
							# advance the starting index for the next regex search to after this "//"
							regex_start = comment_pos[0] + 1
						else
							# it is
							# find the end of the next inline comment -> either the 1st line break or the end of this chunk of text
							regex_match = aux_str.match(re_line_break, comment_pos[0])

							# check if any line breaks were found after this comment's start index
							if regex_match === nil
								# no
								# this inline comment ends at this iteration chunk's text end
								comment_pos[1] = aux_str.length - 1
							else
								# yes
								# this inline comment ends at that line break's index
								comment_pos[1] = regex_match.begin(1)
							end

							# edit the text by removing this inline comment
							aux_str = aux_str.slice(0...comment_pos[0]) + aux_str.slice(comment_pos[1]..-1)
						end

						# search for the next inline comment
						match_data = aux_str.match(re_inline_comment, regex_start)
					end

					# stores this iteration chunk's text in slices
					# those slices are formed by spliting the text across the multiline comments
					# this allows for different processing to be done to the comments
					# and to the non-comment text
					text_slices = Array.new

					# loop while there are multiline comments to process
					match_data = aux_str.match(re_multiline_comment_start)
					while match_data != nil
						# stores the start and end indexes of this comment
						comment_pos = Array.new

						# get the start index for this comment
						comment_pos[0] = match_data.begin(1)

						# get the end index for this comment
						comment_pos[1] = aux_str.index(re_multiline_comment_end)

						# check if this comments end was found
						if comment_pos[1] === nil
							# it wasn't
							# assume the comment ends at the end of the text
							comment_pos[1] = aux_str.length - 1

							# print error message
							@cli_obj.printStr("WARNING: In the file #{file_path}, there is a multiline comment that doesn't have an explicit end symbol.", true)
						else
							# it was -> advance the index to after the comment's end characters
							comment_pos[1] += 1
						end

						# store the non-comment text
						text_slices.push({
							:value => aux_str.slice(0...comment_pos[0]),
							:type => :normal
						})

						# get the 2 characters after this comment's start characters
						comment_substr = aux_str.slice(comment_pos[0]+2, 2)

						# check if those 2 characters indicate this comment is to be kept as is
						if comment_substr.match(/^#{multiline_comment_keep_intact}$/i) != nil
							# yes
							# store this comment's content, but remove the characters used to indicate
							# the comment is to be kept
							comment_value = aux_str.slice(comment_pos[0], 2) + aux_str.slice(comment_pos[0]+4..comment_pos[1])

							# store this comment type
							comment_type = :comment_intact
						# check if those 2 characters indicate this comment is to be kept, but collapsed to 1 line
						elsif comment_substr.match(/^#{multiline_comment_keep_1line}/i) != nil
							# yes
							# store this comment's content, but remove the characters used to indicate
							# the comment is to be kept
							comment_value = aux_str.slice(comment_pos[0], 2) + aux_str.slice(comment_pos[0]+3..comment_pos[1])

							# store this comment type
							comment_type = :comment_collapse
						else
							# this comment is to be removed
							comment_value = nil
							comment_type = nil

						end

						# check if this comment is to be kept
						if comment_type != nil
							# it is, so store it's contents
							text_slices.push({
								:value => comment_value,
								:type => comment_type
							})
						end

						# edit the text by removing this comment
						aux_str = aux_str.slice(comment_pos[1]+1..-1)

						# search for the next multiline comment
						match_data = aux_str.match(re_multiline_comment_start)
					end

					# store the last non-comment text, if the loop run at least once, or the entire
					# chunk, if the loop didn't run
					text_slices.push({
						:value => aux_str,
						:type => :normal
					})

					# in preparation for the removal of selected whitespaces
					# convert the no whitespace characters into a string ready for regex
					no_whsp_chars_str = Regexp.escape(no_whsp_chars.join("Q")).gsub(/Q/, "|")

					# reset this variable to store the rebuild string
					aux_str = ""

					# loop through each part of this iteration chunk's text and reconstruct it
					# for each part do the necessary treatment, depending if it's a comment or not
					text_slices.each { |text_slice|
						# check if this slice is to be processed
						if text_slice[:type] != :comment_intact
							# it is
							# remove all tabs
							text_slice[:value].gsub!(/\t/, "")

							# process line breaks
							# check if this slice is a comment to be kept, but collapsed into 1 line
							if text_slice[:type] == :comment_collapse
								# it is, replace all line breaks with a white space
								text_slice[:value].gsub!(re_line_break, " ")
							else
								# it isn't, so remove all line breaks
								text_slice[:value].gsub!(re_line_break, "")
							end

							# replace all multiple whitespaces (2+ whitespaces) with a single whitespace
							text_slice[:value].gsub!(/[[:space:]]{2,}/, " ")

							# remove whitespaces before specific characters
							text_slice[:value].gsub!(/[[:space:]](#{no_whsp_chars_str})/, "\\1")

							# remove whitespaces after specific characters
							text_slice[:value].gsub!(/(#{no_whsp_chars_str})[[:space:]]/, "\\1")
						end

						# add this text slice to the rebuilt string
						aux_str += text_slice[:value]
					}

					# adjust control variables for the next iteration chunk's text
					# next iteration will start searching for a string after this iteration's end index
					pos_str_i = pos_str_e

					# this iteration processed a non-string chunk, which means the next iteration will deal with a string
					inside_str = true
				end

				# add this iteration chunk's text to the minimized text
				min_str += aux_str
			end

			# replace the content of the minimized file with the minimized text
			if IO.write(file_path, min_str) == 0
				# something went wrong when writing the minimized content to the file
				return(false)
			else
				# all OK
				return(true)
			end
		end

		# receives the paths to a file and a folder
		# return -1 if the file has no direct relationship to the folder (they are in different branches of the directory tree)
		# returns 0 if the file and the folder are directly under the same directory, i.e., they both have the same 1st degree parent folder
		# return a positive integer if the file is a child of the folder -> the value of the integer is the degree of relationship
		# EX: 1 = the file is inside the folder; 2 = the file is inside a subfolder directly under the folder
		# return nil if the file and the folder have the same path
		def fileFolderRel(file, folder)
			# check if the file and folder paths are the same
			if file.eql?(folder)
				# they are
				return(nil)
			end

			# split the paths into each directory node
			file_detail = file.split("/")
			folder_detail = folder.split("/")

			# store the number of indexes in both paths' directory structure
			file_max_index = file_detail.length - 1
			folder_max_index = folder_detail.length - 1

			# loop throught each directory tree node to determine if the shortest path of the two
			# matches entirely to the longest of the two paths
			node_index = 0
			while node_index <= file_max_index and node_index <= folder_max_index
				# check if this tree node is the same for the file and the folder
				if !file_detail[node_index].eql?(folder_detail[node_index])
					# it isn't
					# the nodes don't match, so the file and the folder are either
					# inside the same directory (are siblings)
					# or are in unrelated directory trees
					break
				end

				# move on to the next node
				node_index += 1
			end

			# check if the above loop ended naturaly
			if node_index > file_max_index or node_index > folder_max_index
				# it did
				# the paths match and either the file or the folder is further down the directory tree
				# check if the folder has the shortest path
				if folder_max_index < file_max_index
					# it has
					# return the degree of parenthood of the folder to the file
					return(file_max_index - folder_max_index)
				else
					# it hasn't
					# the folder is deeper into the tree, so there is no parenthood relationship
					# between the folder and the file
					return(-1)
				end
			# the loop ended prematurely -> check if both paths went all the way to the last node
			elsif node_index == file_max_index and node_index == folder_max_index
				# they did, the file and the folder are inside the same directory
				# they are siblings
				return(0)
			# the loop ended prematurely and didn't reach the last node on both paths
			else
				# the file and the folder are unrelated
				return(-1)
			end
		end

		# receives 2 absolute paths
		# returns the common part of the 2 paths OR empty if there is no common part
		def commonPath(path1, path2)
			# check if the 2 paths are exactly the same
			if path1.eql?(path2)
				# they are, so any of them is the common path
				return(path1)
			end

			# split both paths into each directory node
			path1_detail = path1.split("/")
			path2_detail = path2.split("/")

			# store the number of indexes in both paths structure
			path1_max_index = path1_detail.length - 1
			path2_max_index = path2_detail.length - 1

			# loop throught the nodes of path1 and check against path2
			node_index = 0
			while node_index <= path1_max_index and node_index <= path2_max_index
				# check if this current node matches in boths paths
				if !path1_detail[node_index].eql?(path2_detail[node_index])
					# they don't -> the paths diverge on this node, exit loop
					break
				end

				# move on to next node
				node_index += 1
			end

			# check if there are any common nodes between the 2 paths
			if node_index == 0
				# there aren't
				return("")
			else
				# there are -> the last common node is in index "node_index - 1"
				return(path1_detail.slice(0...node_index).join("/"))
			end
		end
end
