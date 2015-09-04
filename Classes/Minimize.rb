 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 # 															 #
 # Ruby Minimizer for CSS and JS files v1.0.2				 #
 # http://www.pedrojhenriques.com 							 #
 # 															 #
 # Copyright 2015, PedroHenriques 							 #
 # Free to use under the MIT license.			 			 #
 # http://www.opensource.org/licenses/mit-license.php 		 #
 # 															 #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class Minimize
	attr_reader :ignore_list, :watch_list

	def initialize()
		# these paths point to the watch and ignore files
		@ignore_path = "Data/ignore_list.txt"
		@watch_path = "Data/watch_list.txt"

		# supported file types
		@valid_file_types = ["css", "js"]

		# default options, to be used when no options are passed for a path
		@default_opts = @valid_file_types.join("|")

		# class variable to store the modified time of the watch and ignore lists last used
		# this allows for the watch and ignore list files to be changed without requiring an application restart
		@lists_mtime = Array.new

		# build the arrays with paths to watch and ignore
		build_list(0)
		build_list(1)
	end

	# main method of this class that will actively watch for the relevant files and deal with them
	# receives an integer representing the numer of seconds to wait between loops
	def watch(sleep_time=5)
		sleep_time = sleep_time.to_i
		
		begin
			# check if the watch and ignore lists are up-to-date
			if File.stat(File.absolute_path(@ignore_path)).mtime > @lists_mtime[0]
				# the ignore list file is newer than the one used to build the current @ignore_list
				build_list(0)
			end
			if File.stat(File.absolute_path(@watch_path)).mtime > @lists_mtime[1]
				# the watch list file is newer than the one used to build the current @watch_list
				build_list(1)
			end

			# loop each of the watch paths
			@watch_list.each { |item|
				# build an array with the files to check for this path
				files = Array.new
				if File.directory?(item[:path])
					# navigate this folder and search all the files that match the criteria
					files = search_files(item[:path], item[:opts])
				elsif File.exist?(item[:path])
					# store the file
					files.push(item[:path])
				else
					puts "\n\r=> WARNING: The path \"#{item[:path].to_s}\" in the watch list doesn't exist!"

					next
				end

				# validate the files
				files = validate_files(files)

				# run the files against the ignore list
				files = check_against_ignore(files)

				# loop through each validated file
				files.each { |file|
					# if this file is an empty array of files or an empty string, move to next files item
					if file.empty?
						next
					end

					# if we're joining multiple files into 1 .min file
					if file.is_a?(Array)
						# grab the first file in the array of files
						file_current = file.first
					else # minimizing a file on its own
						file_current = file
					end
					
					# split the file's directory path from file name
					file_detail = File.split(file_current)

					# determine the minimized file's path
					pos_aux = file_detail[1].length - 1 - file_detail[1].reverse.index(".") # position of last "."
					if pos_aux === nil or pos_aux == file_current.length - 1
						# ignore if the file doesn't have a "." or no file type
						next
					else
						if file.is_a?(Array)
							# file is a joint minimized file, so create it in the up most folder of this watch_list item
							file_min_path = "#{item[:path]}/joined.min#{file_detail[1].slice(pos_aux..-1)}"
						else
							# file is being minimized individualy, so keep file name and add .min to it
							file_min_path = "#{file_detail[0]}/#{file_detail[1].slice(0...pos_aux)}.min#{file_detail[1].slice(pos_aux..-1)}"
						end
					end

					# if the minimized file isn't up-to-date
					if !min_up_to_date(file_min_path, file.clone) # pass a clone of file to avoid loosing information in the variable file
						# create the raw version of the minimized file
						if create_min_file(file_min_path, file.clone) # pass a clone of file to avoid loosing information in the variable file
							# process this file's minimization
							if minimize_file(file_min_path)
								# display message informing the file was created/updated
								puts "\n\r=> UPDATED: #{file_min_path}"
							else
								# display message informing of an error
								puts "\n\r=> WARNING: an error occured while minimizing the file #{file_min_path}!"
							end
						else
							# display message informing of an error
							puts "\n\r=> WARNING: an error occured while joining the specified files into #{file_min_path}!"
						end
					end
				}
			}
		rescue Exception => e
			raise e
		end

		sleep sleep_time
	end

	private

		# this method builds the watch and ignore lists, based on the respective files in Data/
		def build_list(item)
			# item === 0	=> ignore list
			# item === 1	=> watch list

			# build an array with paths to be ignored/watched
			begin
				item = item.to_i

				# validate parameter
				if item === 0
					# ignore list
					path = File.absolute_path(@ignore_path)
				elsif item === 1
					# watch list
					path = File.absolute_path(@watch_path)
				else
					# invalid parameter value
					raise
				end

				list_raw = Array.new
				File.new(path, "r").each { |line|
					# make sure the path are using /
					line = line.to_s.strip.gsub(/\\/, "/")

					# separate the path from the options
					if line.match(/\[\D+\]$/) === nil
						# if no options were passed, assume default opts
						line_data = {:path => File.absolute_path(line.chomp), :opts => @default_opts}
					else
						# find the index where the options start
						pos_opts_i = line.index(/\[\D+\]$/)

						# grab the options
						aux_opts_a = line.slice(pos_opts_i+1...-1).strip.chomp.downcase.split("|")

						# if the options don't include a file type, add all of the valid file types
						has_ftype = false
						@valid_file_types.each { |ftype|
							if aux_opts_a.include?(ftype)
								has_ftype = true
								break
							end
						}
						if !has_ftype
							# no valid file types were passed
							aux_opts_a += @valid_file_types
						end

						# convert array into string
						aux_opts = aux_opts_a.join("|")

						line_data = {:path => File.absolute_path(line.slice(0...pos_opts_i).strip.chomp), :opts => aux_opts}
					end

					list_raw.push(line_data)
				}

				# sort ignore list by path from the lower to the higher path
				list_raw.sort! {|h1,h2| h2[:path] <=> h1[:path]}

				# store the list in the respective class variable
				if item === 0
					@ignore_list = list_raw
				else
					@watch_list = list_raw
				end

				# store this file's modified time
				@lists_mtime[item] = File.stat(path).mtime
			rescue Exception => e
				if item === 0
					puts "\n\r=> WARNING: There was a problem reading the \"#{@ignore_path}\" file. Please make sure such a file exists."
				elsif item === 1
					puts "\n\r=> WARNING: There was a problem reading the \"#{@watch_path}\" file. Please make sure such a file exists."
				else
					puts "\n\rinvalid parameter in build_list method"
				end
				
				raise e
			end
		end

		# checks an array of file hashes agaist the ignore list
		# only deals with paths leading to files. will skip paths pointing to directories
		def check_against_ignore(list)
			begin
				# if there is no ignore list, return
				if @ignore_list.empty?
					return list
				end

				# loop each watch list item
				result = Array.new
				list.each { |wl_item|
					# if this watch list item is an array, we're joining the array's files into 1 .min file
					if wl_item.is_a?(Array)
						# all these files will be returned inside an array
						result.push(Array.new)

						# grab the first element of the array
						wl_item_current = wl_item.shift.to_s.strip

						joining = true
					else
						# path is pointing to a file, use it as is
						wl_item_current = wl_item

						# we're not joining multiple files
						joining = false
					end

					# loop until there are no more items in this path_list element
					begin
						if File.exist?(wl_item_current)
							# until further notice we'll watch this item
							to_watch = true

							# search the ignore list for a relevant item
							@ignore_list.each { |ig_item|
								# check if this ignore list entry is relevant for the current watch list item
								# the ignore list is already sorted from the lowest to highest folder structure, so the first relevant item we find is the one to use

								# create array with the ignore list folder's options
								ig_item_opts = ig_item[:opts].to_s.split("|")

								if File.directory?(ig_item[:path])
									# the ignore list item is a folder

									# split the watch list file's name from the directory path
									file_detail = File.split(wl_item_current)

									# determine the ignore list's folder degree of parenthood to the watch list file
									folder_comparison = file_folder_rel(wl_item_current.to_s.downcase, ig_item[:path].to_s.downcase)
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

										break
									elsif folder_comparison > 1
										# the ignore list folder is the 2nd or higher degree parent of the watch list file
										# i.e., the watch list file is in a subfolder of this ignore list folder
										# in this case the folder's "nosub" option is relevant

										# check if we're ignoring just files inside this one folder, or in all its subfolders as well
										# and check the file type and the join or no join status
										if !ig_item_opts.include?("nosub") and (ig_item_opts.include?(file_detail[1].split(".").last) and (!ig_item_opts.include?("nojoin") or joining))
											# we're ignoring files in this folder and its subfolders
											# and it's set to ignore files of this type
											# and either it's ignoring all operations or just joining and we're doing one
											# so skip this watch list item
											to_watch = false
										end

										break
									end
								elsif File.exist?(ig_item[:path]) and wl_item_current.to_s.downcase.eql?(ig_item[:path].to_s.downcase)
									# the watch list item is the same as this ignore list item
									# check if we don't want this file minimized or if we just don't want it to be minimized in a joint file
									if !ig_item_opts.include?("nojoin") or joining
										# either this file is not to be minimized (dosn't have nojoin)
										# or it's not to be minimized in joint actions and we're trying to do so (has nojoin and we're joining)
										# skip this file
										to_watch = false
										break
									end
								else
									# not comparable so not relevant
									next
								end
							}

							# if this file isn't covered by the ignore list, watch it
							if to_watch
								if joining
									result.last.push(wl_item_current)
								else
									result.push(wl_item_current)

									# this path was pointing to a file, move on to next watch list item
									break
								end
							end
						end
						
						# if this wl_item item isn't empty (only when we're joining multiple files)
						if joining and !wl_item.empty?
							# grab next item and let the loop keep going
							wl_item_current = wl_item.shift.to_s.strip
						else
							# there are no more itms in this joining array
							# move on to next wl_item item
							break
						end
					end while true
				}

				result
			rescue Exception => e
				raise e
			end
		end

		# receives an array with file paths and validates them
		# checks if they exist and if they are of a supported type
		def validate_files(path_list)
			begin
				files = Array.new

				path_list.each { |path|
					# if path is an array, then we're joining all it's files into 1 .min file
					if path.is_a?(Array)
						# these files will be joined, so return them all inside an array
						files.push(Array.new)

						# grab the first element of the array
						path_current = path.shift.to_s.strip

						# joining multiple files
						joining = true
					else
						# path is pointing to a file, use it as is
						path_current = path

						# not joining multiple files
						joining = false
					end

					# loop until there are no more items in this path_list element
					begin
						# split the watch list file's name from the directory path
						file_detail = File.split(path_current)

						# check if the file exists and is a supported file type and isn't empty
						if File.exist?(path_current) and @valid_file_types.include?(file_detail[1].split(".").last) and File.new(path_current).size != 0
							# all OK, add the path to the result set
							if joining
								files.last.push(path_current)

								# if this path_list item isn't empty
								if !path.empty?
									# grab next item and let the loop keep going
									path_current = path.shift.to_s.strip
								else
									# there are no more itms in this joining array
									# move on to next path_list item
									break
								end
							else
								files.push(path_current)

								# this path was pointing to a file, move on to next path_list item
								break
							end
						end
					end while true
				}

				files
			rescue Exception => e
				raise e
			end
		end

		# receives a path to a folder and seaches for files that match the options
		# will ignore all files that have as name: *.min.[one of the valid file types]
		def search_files(dir_path, dir_opts)
			begin
				dir_path = dir_path.to_s.strip
				dir_opts = dir_opts.to_s.strip

				# if the path doesn't point to a folder, return
				if !File.directory?(dir_path)
					return files
				end

				# if no options are passed, assume the default options
				if dir_opts.empty?
					dir_opts = @default_opts
				end

				# build array with options
				opts = dir_opts.split("|")

				# check which file types we're looking for
				search_ftypes = Array.new
				joining_hash = Hash.new
				@valid_file_types.each { |ftype|
					if opts.include?(ftype)
						search_ftypes.push(ftype)

						# build a hash with an array for each file type -> needed later
						joining_hash[ftype] = Array.new
					end
				}

				# if no supported search file types are set, return
				if search_ftypes.empty?
					return files
				end

				# local variable where the files found will be stored
				files = Array.new

				# if the files found in this folder are to be joined into 1 .min file
				if opts.include?("join")
					joining = true
				else
					# not joining these files
					joining = false
				end

				# open the directory
				dir = Dir.new(dir_path)

				# build the search pattern to be used
				search_pattern = "*.{#{search_ftypes.join(",")}}"
				if !opts.include?("nosub")
					# if we want to search inside subfolders, adjust search pattern to search folders recursively
					search_pattern = File.join("**", search_pattern)
				end

				# run each content in the diretory and check for matches to the search options
				search_regex_minimized = ".\.min\.(#{search_ftypes.join("|")})"
				Dir.chdir(dir_path) do
					Dir.glob(search_pattern.to_s) { |found_file|
						# if the file is already a minimized version, ignore it
						if found_file.to_s.match(search_regex_minimized) != nil
							next
						end

						# store the full path to the file
						if joining
							# check what file type we're dealing with -> find the last "." index
							found_file_aux = found_file.length - found_file.reverse.index(".")

							# add this file to the respective file type in the temp hash
							joining_hash[found_file.slice(found_file_aux..-1)].push("#{dir_path}/#{found_file}")
						else
							files.push("#{dir_path}/#{found_file}")
						end
					}
				end

				# close directory
				dir.close

				# if joining, add all the arrays to the result set
				if joining
					joining_hash.each_value { |value|
						# if this file type has at least 1 file found, add it to the result set
						if !value.empty?
							files.push(value)
						end
					}
				end

				files
			rescue Exception => e
				raise e
			end
		end

		# receives the path to the minimized file and the source file(s)
		# return TRUE if the .min file is up-to-date or FALSE if it's needed to run the minimize_file method
		def min_up_to_date(min_path, sources)
			begin
				min_path = min_path.to_s.strip

				# if the minimized file doesn't exist, return not up-to-date
				if !File.exist?(min_path)
					return false
				end

				# if the source is an array of files (we're minimizing several files into 1 .min file)
				if sources.is_a?(Array)
					# grab the first element of sources
					sources_current = sources.shift.to_s.strip

					joining = true
				else # source is a single file
					# minimizing a file on its own, so use as is
					sources_current = sources

					joining = false
				end

				# loop until there are no more files in source to check
				begin
					# check if the current source file is newer than the minimized file
					if File.stat(sources_current).mtime > File.stat(min_path).mtime
						# the source is newer, return not up-to-date
						return false
					else
						if joining
							# if we're joining, check if there are any more source files to loop through
							if sources.empty?
								# no more source files
								# exit loop to return
								break
							else
								# grab the next element of sources
								# keep loop going
								sources_current = sources.shift.to_s.strip
							end
						else
							# only 1 file was being checked
							# exit loop to return
							break
						end
					end
				end while true

				# if we reach this line then the minimized file is up-to-date
				return true
			rescue Exception => e
				raise e
			end
		end

		# receives the path to the minimized file and the source file(s)
		# return TRUE if the .min file was created or FALSE otherwise
		def create_min_file(min_path, sources)
			begin
				min_path = min_path.to_s.strip

				# if sources is an array, then we're joining multiple files into 1 .min file
				if sources.is_a?(Array)
					# grab the first element of the sources array
					sources_current = sources.shift.to_s.strip

					joining = true
				else
					# minimizing a file on it's own, so use as is
					sources_current = sources

					joining = false
				end

				# until otherwise stated, the .min file was successfully created
				result = true

				# if the file already exists, remove all contents
				if File.exist?(min_path)
					File.truncate(min_path, 0)
				end
				# open the .min file in append mode (will create the file if it doesn't exist)
				file = File.new(min_path, "a")

				# loop until all source files have been added to the minimized file
				begin
					# add the current source file to the .min file
					file << IO.read(sources_current)

					# if we're joining multiple files into 1 .min file
					if joining
						if sources.empty?
							# no more source files to add
							# exit loop to return
							break
						else
							# grab the next element of the sources array
							# keep loop going
							sources_current = sources.shift.to_s.strip
						end
					else # minimizing a single file on its own
						# no more source files to add
						# exit loop to return
						break
					end
				end while true

				# close the File object and resolve any pending write actions
				file.close

				# if we reach this line then the file was successfully created
				return result
			rescue Exception => e
				raise e
			end
		end

		# receives a path to a file and will edit it to minimize it
		# return TRUE if successful or FALSE if an error occured
		def minimize_file(file_path)
			begin
				file_path = file_path.to_s.strip

				# open the file in read-write mode, without truncating
				file = IO.read(file_path, mode: "r")

				# local variable to store the minimized text as it is built
				min_str = String.new
				# local variable to store temporarily parts of the file for processing
				aux_str = String.new
				# local variables to help keep track of strings in the source file
				pos_str_i = 0 # is always at the start of the chunk text to be changed
				pos_str_e = 0 # is always at the position after the end of the chunk of text to be changed
				inside_str = false
				# local variables to help with regex
				line_break = /(\r|\n)/
				inline_comment = /\/\//
				multiline_comment_start = /\/\*/
				multiline_comment_end = /\*\//
				# local variable (array) storing all characters that don't need to have a whitespace before or after
				specific_chars = [";",":",",","{","}","[","]","(",")","+","-","*","<",">","=","||","&&","!="]

				while pos_str_e < file.length - 1
					# find the end of the next chunk of text
					if inside_str
						# find the closing quote to the currently open string in the source file
						# the closing quote has to be of the same type as the opening quote - single or double
						pos_str_e = file.index(file.slice(pos_str_e), pos_str_e + 1)
					else
						# find the next single or double quote in the source file
						pos_str_e = file.index(/[\"\']/, pos_str_e + 1)
					end

					# if a quote wasn't found, set index to end of file
					if pos_str_e === nil
						pos_str_e = file.length
					else # validate the quote found
						if inside_str
							# if the quote found is escaped ignore it
							if pos_str_e > 0 and file.slice(pos_str_e - 1).match(/\\/) != nil
								next
							end
						else
							# if the quote found is inside a comment (single or multi line) ignore it
							aux_str = file.slice(pos_str_i...pos_str_e)
							aux = Array.new

							# multiline comment
							# find the start of the multiline comment closest to the quote
							aux[0] = aux_str.reverse.index(multiline_comment_start)
							if aux[0] != nil
								# if there is a start to a multiline comment, find the closest end to a multiline comment
								aux[1] = aux_str.reverse.index(multiline_comment_end)

								if aux[1] === nil or aux[0] > aux[1]
									# if there is no end to the comment or the closest end is before the start (then we have an open comment, meaning the quote is inside a comment)
									# ignore this quote
									next
								end
							end

							# inline comment
							# find the start of the inline comment closest to the quote
							aux[0] = aux_str.reverse.index(inline_comment)
							if aux[0] != nil and aux_str.slice(aux[0]-5...aux[0]).match(/http:/) === nil and aux_str.slice(aux[0]-6...aux[0]).match(/https:/) === nil
								# if there is a start to an inline comment, find the closest end to an inline comment
								aux[1] = aux_str.reverse.index(line_break)

								if aux[1] === nil or aux[0] < aux[1]
									# if there is no end to the comment or the closest end is before the start (then we have an open comment, meaning the quote is inside a comment)
									# ignore this quote
									next
								end
							end
						end
					end

					# if between pos_str_i and pos_str_e is a string, don't change anything
					if inside_str
						# don't change any of the text inside a string
						aux_str = file.slice(pos_str_i..pos_str_e)

						# adjust control variables for next chunk of text from the source file
						inside_str = false
						pos_str_i = pos_str_e + 1
					else # not inside a string
						# store the chunk of text we're looking at the moment
						aux_str = file.slice(pos_str_i...pos_str_e)

						# find any inline comments // and remove them
						regex_start = 0
						while aux_str.match(inline_comment, regex_start) != nil
							aux = Array.new

							# find the start of the next inline comment
							aux[0] = aux_str.index(inline_comment, regex_start)
							if aux_str.slice(aux[0]-5...aux[0]).match(/http:/) != nil or aux_str.slice(aux[0]-6...aux[0]).match(/https:/) != nil
								# if the match has http: or https: before, ignore
								regex_start = aux[0] + 1
								next
							end
							# find the end of the next inline comment -> either the 1st line break or the end of this chunk of text
							if aux_str.match(line_break, aux[0]) === nil
								# no line breaks, so the inline comment ends at this chunk of text's end
								aux[1] = aux_str.length - 1
							else
								# found a line break
								aux[1] = aux_str.index(line_break, aux[0])
							end

							# adjust the current chunk of text
							aux_str = aux_str.slice(0...aux[0]) + aux_str.slice(aux[1]..-1)
						end

						# replce all tabs with nothing
						aux_str.gsub!(/\t/, "")

						# find any multiline comments and remove them
						while aux_str.match(multiline_comment_start) != nil
							aux = Array.new

							# find the start of the next comment
							aux[0] = aux_str.index(multiline_comment_start)
							# find the end of the next comment
							aux[1] = aux_str.index(multiline_comment_end) + 1

							# adjust the current chunk of text
							aux_str = aux_str.slice(0...aux[0]) + aux_str.slice(aux[1]+1..-1)
						end

						# remove any line breaks
						aux_str.gsub!(line_break, "")

						# replace all multiple whitespaces (2+ whitespaces) with a single whitespace
						aux_str.gsub!(/[[:space:]]{2,}/, " ")

						# remove selected single whitespaces
						# convert the specific characters into a string ready for regex
						specific_chars_str = Regexp.escape(specific_chars.join("Q")).gsub(/Q/, "|")
						# remove whitespaces before specific characters
						aux_str.gsub!(Regexp.new("[[:space:]](#{specific_chars_str})"), "\\1")
						# remove whitespaces after specific characters
						aux_str.gsub!(Regexp.new("(#{specific_chars_str})[[:space:]]"), "\\1")

						# adjust control variables for next chunk of text from the source file
						pos_str_i = pos_str_e
						inside_str = true
					end

					# add the current chunk of text to the final text
					min_str += aux_str
				end

				# replace the content of the .min file with the minimized text
				if IO.write(file_path, min_str) == 0
					false
				else
					true
				end
			rescue Exception => e
				raise e
			end
		end

		# receives the paths to a file and a folder
		# return -1 if the file has no direct relationship to the folder (they are in different branches of the directory tree)
		# returns zero if the file and the folder are directly under the same directory, i.e., they both have the same 1st degree parent folder
		# return a positive integer if the file is a child of the folder -> the value of the integer is the degree of relationship
		# EX: 1 = the file is inside the folder; 2 = the file is inside a subfolder directly under the folder
		# return nil if the file and the folder have the same path
		def file_folder_rel(file, folder)
			file = File.absolute_path(file.to_s.strip)
			folder = File.absolute_path(folder.to_s.strip)

			# if the file and folder path are the same, then we don't have a file and a folder
			if file.eql?(folder)
				return nil
			end

			# split the paths into each directory node
			file_detail = file.split("/")
			folder_detail = folder.split("/")

			# store the number of indexes in both paths directory structure
			file_max_index = file_detail.length - 1
			folder_max_index = folder_detail.length - 1

			# loop throught each directory tree node and compare it in the file and folder
			# the loop ends when we reach the end of 1 of the paths
			i = 0 # start with the 1st node
			while i <= file_max_index and i <= folder_max_index
				# compare this tree node in the file and folder
				if !file_detail[i].eql?(folder_detail[i])
					# the nodes aren't the same, so the file and the folder are either
					# inside the same directory (are siblings)
					# or are in unrelated directory trees 
					break
				end

				# if the nodes match, move on to the net one
				i += 1
			end

			# if the loop ended naturaly, then the paths match and either the file or the folder is
			# further into the directory tree
			if i > file_max_index or i > folder_max_index
				# the file is deeper into the tree, so the folder is a parent of the file
				if file_max_index > folder_max_index
					# return the degree of parenthood of folder to the file
					file_max_index - folder_max_index
				else
					# the folder is deeper into the tree, so there is no parenthood relationship
					# between the folder and the file
					-1
				end
			# if the loop ended prematurely but both paths whent all the way to the last node
			elsif i == file_max_index and i == folder_max_index
				# the file and the folder are inside the same directory
				# they are siblings
				0
			# the loop ended prematurely and didn't reach thelast node
			else
				# the file and the folder are unrelated
				-1
			end
		end
end