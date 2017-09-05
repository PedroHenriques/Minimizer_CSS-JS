# # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 																									 	#
# Bundler and Minimizer for Web files v3.1.1				 	#
# 																										#
# Copyright 2017, PedroHenriques 							 				#
# http://www.pedrojhenriques.com 							 				#
# https://github.com/PedroHenriques 						 			#
# 															 											#
# Free to use under the MIT license.			 			 			#
# http://www.opensource.org/licenses/mit-license.php 	#
# 															 											#
# # # # # # # # # # # # # # # # # # # # # # # # # # # #

require "json"

class Application
	attr_reader :config_file_dirname

	# define the setter for @cmd_line_args
	define_method(:cmd_line_args) { |key, value| @cmd_line_args[key.to_sym] = value }

	def initialize()
		begin
			# class variable storing the parsed JSON file with the information to
			# validate the config file
			@@config_validation_content_ = JSON.parse(IO.read("#{File.dirname(File.dirname(__FILE__))}/data/config_validation.json"))
		rescue Errno::ENOENT
			# something went wrong while opening and parsing the JSON file
			# raise an error message
			raise("=> ERROR: An error occured while opening/parsing the file \"#{File.dirname(File.dirname(__FILE__))}/data/config_validation.json\"")
		end

		# class variables storing the regex patters used through out this class
		# matches a regex
		# NOTE: assumes that a division operator will have a whitespace after itself
		# 		(more details in the README file)
		@@re_regex_ = /(\/[^*\n][^\n]*\/[gim]*)[;,\]}\)]/
		# matches line breaks
		@@re_line_break_ = /(\r|\n)/
		# matches the start of an inline comment
		@@re_inline_comment_ = /(\/\/)/
		# matches the start of a block (multi line) comment
		@@re_multiline_comment_start_ = /(\/\*)/
		# matches the end of a block (multi line) comment
		@@re_multiline_comment_end_ = /(\*\/)/
		# matches the character after the start of a multi line comment that
		# signals that comment is to be kept, but collapsed to 1 line
		@@multiline_comment_keep_1line_ = "!"
		# matches the characters after the start of a multi line comment that
		# signals that comment is to be kept intact
		@@multiline_comment_keep_intact_ = "!!"

		# class variable storing the name of the config file
		@@config_file_basename_ = "bundler.config.json"

		# class variable storing the partial names for the output files
		@@output_file_names_ = {
			# starting of the output file built by joining multiple files
			:join => "bundle",
			# middle of the output file built from a single file
			:nojoin => "min"
		}

		# class variable storing the modifier to the name of the JavaScript file, produced for each
		# TypeScript entry point file, that contains the entry point file and all its imports in 1 file
		@@ts_combined_extra_path_ = "combined"

		# class variable storing the extra name part used to store each output file's auxiliary file
		# this extra name part is added to the respective output file's absolute path
		@@aux_file_extra_path_ = ".json"

		# class variable storing the supported bundle file types
		# format: [bundle file type] = array with file types to be included in that bundle file
		@@bundle_file_types_ = {
			"css" => ["css", "scss", "sass"],
			"js" => ["js", "ts"]
		}

		# class variable storing the default options for watch rules
		# to be used when no options are passed to a watch rule
		@@default_watch_opts_ = @@config_validation_content_["key_accepts"]["watch"]["each_value"]["each_value"]["key_accepts"]["opts"]["default_value"]

		# class variable storing the default options for ignore rules
		# to be used when no options are passed to an ignore rule
		@@default_ignore_opts_ = @@config_validation_content_["key_accepts"]["ignore"]["each_value"]["each_value"]["key_accepts"]["opts"]["default_value"]

		# class variable storing the default behavior for the program: join or nojoin
		# to be used when no specific 1 value is passed to a watch rule
		@@default_join_behavior_ = "join"

		# class variable storing another organization of the data in @@bundle_file_types_
		# where it stores the bundle file type for each supported file type
		# format: [supported file type] = the bundle file type it goes in
		@@valid_file_types_ = Hash.new

		# populate @@valid_file_types_ based on the data of @@bundle_file_types_
		# loop through each entry of @@bundle_file_types_
		@@bundle_file_types_.each { |bundle_file_type, supported_file_types|
			# loop through each supported file type
			supported_file_types.each { |file_type|
				# add this file type to @@valid_file_types_
				@@valid_file_types_[file_type] = bundle_file_type
			}
		}

		# class variable storing the methods to call for each file type requiring pre-processing
		# format: [file type] = {:crawl => "method name", :process => "method name"}
		@@file_type_callbacks_ = {
			"scss" => {
				:crawl => "crawlSASS",
				:process => "processSASS"
			},
			"sass" => {
				:crawl => "crawlSASS",
				:process => "processSASS"
			},
			"ts" => {
				:crawl => "crawlTypeScript",
				:process => "processTypeScript"
			}
		}

		# class variable storing lambda functions, for the file types that needed them, that receive a file absolute path
		# and will return the absolute path of the file that should be added to a watch rule's output file
		# format: [file type] = lambda function
		@@file_type_output_basename_ = {
			"ts" => lambda { |file_abs_path|
				return("#{File.dirname(@file_crawl_data[file_abs_path][:out_path])}/#{File.basename(file_abs_path, ".*")}.combined.js")
			}
		}

		# instance variable storing the imported files for files of the types that have a "crawl" action callback
		# as well as storing the respective output absolute path
		# format: [file absolute path] = {:imports => [absolute paths], :out_path => "absolute path", :last_crawl => timestamp}
		@file_crawl_data = {}

		# instance variable storing the values for the scan variables imposed by the arguments provided
		# in the command line with a command call
		# this variable is populated by the Cli class and used by resetScanVars()
		# format: {symbol the name of a scan variable => the value imposed by the command line flag}
		@cmd_line_args = {}

		# instance variable storing the names of the scan variables that don't have a config file variation
		# and their default fallback values
		# this variable is used by resetScanVars()
		# format: {symbol with the name of the scan variable => default fallback value}
		# NOTE: these variables will get the value of a command line flag or the default fallback value, in that order
		@internal_scan_vars = {
			:force_build => false
		}

		# instance variable storing the sleep time to be used between each watch cycle
		@sleep_timer = -1.0

		# instance variable storing a flag that controls whether the program should
		# scan in "watch mode" or scan the relevant files only once
		@watch_mode = false

		# instance variable storing a flag that controls whether the program should
		# minimize all the output files or not
		@minimize = false

		# instance variable storing a flag that controls whether, in a scan() cycle,
		# all output files should be built and all compiled files should be compiled
		# regardless if they needed it or not
		@force_build = false

		# instance variable storing an instance of the Cli class
		@cli_obj = Cli.new(self)

		# instance variable storing the parsed contents of the config file
		@config_content = ""

		# instance variables storing an array with the paths to watch and ignore
		# these variables are populated by buildAllLists()
		@watch_list = nil
		@ignore_list = nil

		# instance variable storing the absolute path to the config file's directory
		@config_file_dirname = ""

		begin
			# search for the config file and if it exists handle it
			handleConfigFile(Dir.getwd)
		rescue Interrupt => e
			# something went wrong while handling the config file
			# bubble the exception up
			raise(e)
		end
	end

	# setter for the instance variable sleep_timer
	def sleep_timer=(value)
		# convert the provided value into a float
		value = value.to_f

		# check if the value is > 0.0
		if value > 0.0
			# it is -> store the value
			@sleep_timer = value
		end
	end

	# setter for the instance variable watch_mode
	def watch_mode=(value)
		# make sure the value stored is a boolean
		@watch_mode = !!value
	end

	# setter for the instance variable minimize
	def minimize=(value)
		# make sure the value stored is a boolean
		@minimize = !!value
	end

	# setter for the instance variable force_build
	def force_build=(value)
		# make sure the value stored is a boolean
		@force_build = !!value
	end

	# getter for the class variable config_file_basename_
	def self.config_file_basename_
		return(@@config_file_basename_)
	end

	# searches for the config JSON file in the project's directory tree, using the
	# provided path as the base point for the search and
	# if the file is found will parse it and call for the build of the watch and ignore lists
	# raises an "Interrupt" if any of the lists fails to be built
	def handleConfigFile(start_path)
		# find the config file in this project's directory tree
		files_found = findFiles("**/#{@@config_file_basename_}", start_path, [])

		# loop through the files found
		files_found.each { |abs_path|
			# check if this file is the config file
			if File.basename(abs_path).eql?(@@config_file_basename_)
				# it is
				# store the config file's dirname
				@config_file_dirname = File.dirname(abs_path)

				# no need to continue the loop
				break
			end
		}

		# check if the config file was found
		if @config_file_dirname.empty?
			# it wasn't
			# print warning message
			@cli_obj.printStr(
				"=> WARNING: A config file couldn't be found in this project's directory tree.\n"\
				"Please create a file named \"#{@@config_file_basename_}\" or use the command \"init\" to "\
				"create a basic config file in the current directory",
				false
			)
		else
			# it was
			# build the config file's absolute path
			config_path = "#{@config_file_dirname}/#{@@config_file_basename_}"

			begin
				# parse the config JSON file's content
				@config_content = JSON.parse(IO.read(config_path))
			rescue IOError
				# the file couldn't be read
				# print error message
				@cli_obj.printStr("=> ERROR: Couldn't open the configuration file at \"#{config_path}\"", false)

				# terminate the program
				raise(Interrupt)
			end

			# check if the parsed config file is valid
			# NOTE: specific error messages will be printed by configFileValid?()
			# TODO: wrap this if statement with a begin...rescue block???
			if !configFileValid?()
				# it isn't
				# terminate the program
				raise(Interrupt)
			end

			# instance variable storing the modified time of the config json file at the time of last list build
			# this allows for the config json file to be changed without requiring a restart of the program
			@config_mtime = File.stat(config_path).mtime

			# reset the scan control variables
			resetScanVars()

			# build all the relevant lists
			buildAllLists()
		end
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
				# it doesn't -> check if the command triggers the start of the scan of source files
				elsif action == 1
					# it does
					begin
						# start the scan
						scan()
					rescue Interrupt => e
						# the user pressed CTRL-C
						# do nothing, but prevent the program from terminating
					end

					# reset the command line flags
					@cmd_line_args = {}
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
		@cli_obj.printStr("\n=> Thank you for using this application!\nFollow this application at https://github.com/PedroHenriques/Web_Bundler_Minimizer\n", false)
	end

	private

		# validates the parsed config JSON file according to the template defined
		# in "config_validation.json"
		# returns true if valid or false if not valid
		# NOTE: will print specific error messages as it validates
		def configFileValid?()
			# store the lambda that will be called recursively to process each
			# tier of the "config_validation.json" file's template
			process_tier = lambda { |test_value, template, tier_full_path|
				# stores the return value (boolean)
				is_valid = true

				# stores any "requirements" property found as this tier is processed
				# format: {
				# 	"path in this tier to the relevant property" => {
				# 		"include" => the value that the relevant property should include for this requirement to take effect
				# 		"require" => the property, in the same path as the relevant property, that must exist
				# 	}
				# 	...
				# }
				requirements_property = {}

				# check if this template tier has information about the specific keys
				# that are supported in "test_value"
				if template.has_key?("key_accepts")
					# it does
					# check if there is a "requirements" property
					if template["key_accepts"].has_key?("requirements")
						# loop through each requirement
						template["key_accepts"]["requirements"].each { |relevant_path, req_data|
							# store this requirement
							requirements_property["key_accepts/#{relevant_path}"] = req_data
						}

						# remove the "requirements" property from the template
						template["key_accepts"].delete("requirements")
					end

					# store a copy of the accepted keys
					accepted_keys = template["key_accepts"].keys

					# loop through each "test_value" key
					test_value.each { |key, value|
						# check if this key is one of the accepted keys
						if accepted_keys.include?(key)
							# it is
							# call this lambda recursively to process the next tier
							# and check if the return is a boolean with value false
							if !process_tier.call({key => value}, template["key_accepts"][key], "#{tier_full_path}")
								# it is
								is_valid = false
							end
						else
							# it isn't
							# print error message
							@cli_obj.printStr("=> ERROR: The #{@@config_file_basename_} file has an invalid key \"#{key}\" at \"#{tier_full_path}\"", false)

							# flag the config file as not valid
							is_valid = false
						end

						# remove this key from the accepted_keys since it has been processed
						accepted_keys.delete(key)
					}

					# loop through any accepted keys not present in the config value
					accepted_keys.each { |missing_key|
						# check if this key is optional
						if !template["key_accepts"][missing_key].has_key?("optional") || !template["key_accepts"][missing_key]["optional"]
							# it isn't
							# print error message
							@cli_obj.printStr("=> ERROR: The #{@@config_file_basename_} file is missing the non-optional key \"#{missing_key}\" at \"#{tier_full_path}\"", false)

							# flag the config file as not valid
							is_valid = false
						end
					}
				else
					# it doesn't
					# check if "test_value" is an array
					if test_value.class.to_s == "Array"
						# it is
						# in the loop below the values of the array will be stored in "test_value_key"
						# and the keys of the array won't be provided to the loop
						# stores the index in the array the loop is in
						test_value_index = 0
					else
						# it isn't
						# the loop won't need to do any adjustments to the keys and values of "test_value"
						test_value_index = nil
					end

					# loop through each "test_value" key
					test_value.each { |test_value_key, test_value_value|
						# check if the values of this loop parameters need to be adjusted
						if test_value_index != nil
							# they do
							# move the value of "test_value_key" to "test_value_value"
							test_value_value = test_value_key

							# change the value of "test_value_key" to be the current "test_value_index"
							test_value_key = test_value_index

							# advance "test_value_index" by 1
							test_value_index += 1
						end

						# build this iteration's "tier_full_path"
						this_tier_full_path = "#{tier_full_path}/#{test_value_key}"

						# get a string representation of the class for "test_value_key"
						test_value_key_class = test_value_key.class.to_s

						# get a string representation of the class for "test_value_value"
						test_value_value_class = test_value_value.class.to_s

						# check if this template tier has information about the valid data types for its key
						# and if it does, check if "test_value_key" is one of the valid data types
						if template.has_key?("key_types") && !template["key_types"].include?(test_value_key_class)
							# "test_value_key" is not one of the valid data types
							# print error message
							@cli_obj.printStr("=> ERROR: The #{@@config_file_basename_} file has an invalid data type for the key \"#{test_value_key}\" at \"#{this_tier_full_path}\"", false)

							# flag the config file as not valid
							is_valid = false
						end

						# check if this template tier has information about the valid data types for its value
						# and if it does, check if "test_value_value" is one of the valid data types
						if template.has_key?("value_types") && !template["value_types"].include?(test_value_value_class)
							# "test_value_value" is not one of the valid data types
							# print error message
							@cli_obj.printStr("=> ERROR: The #{@@config_file_basename_} file has an invalid data type for the value \"#{test_value_value}\" at \"#{this_tier_full_path}\"", false)

							# flag the config file as not valid
							is_valid = false
						end

						# check if this template has information about the accepted values for its associated value
						if template.has_key?("value_accepts")
							# it does
							# check if "test_value_value" is an Array
							if test_value_value_class == "Array"
								# it is
								# check if all the values of "test_value_value" are accepted
								# NOTE: building the union between the arrays template["value_accepts"] and test_value_value
								# 		and comparing its length with the length of template["value_accepts"]
								# 		if its the same, then all values in test_value_value also exists in template["value_accepts"]
								if template["value_accepts"].length != (template["value_accepts"] | test_value_value).length
									# they aren't -> at least 1 value in "test_value_value" is not accepted
									# print error message
									@cli_obj.printStr("=> ERROR: The #{@@config_file_basename_} file has at least one invalid value in \"#{test_value_value}\" at \"#{this_tier_full_path}\"", false)

									# flag the config file as not valid
									is_valid = false
								end
							else
								# it isn't
								# check if the value of "test_value_value" is accepted
								if template["value_accepts"].include?(test_value_value)
									# it isn't
									# print error message
									@cli_obj.printStr("=> ERROR: The #{@@config_file_basename_} file has an invalid value of \"#{test_value_value}\" at \"#{this_tier_full_path}\"", false)

									# flag the config file as not valid
									is_valid = false
								end
							end
						end

						# check if this template has a sub-template for each of its associated values
						if template.has_key?("each_value")
							# it has
							# call this lambda recursively to process the next tier
							# and check if the return is a boolean with value false
							if !process_tier.call(test_value_value, template["each_value"], "#{this_tier_full_path}")
								# it is
								is_valid = false
							end
						end
					}
				end

				# loop through each requirement
				requirements_property.each { |req_path, req_values|
					# split the required path into its components
					req_path_parts = req_path.split("/")

					# loop through each value of this requirement
					req_values.each { |req_value|
						# check if this requirement key exists in this tier's data
						if test_value.include?(req_path_parts.last)
							# it does
							# check if it includes this relevant value and if so if this tier has the required key
							if test_value[req_path_parts.last].include?(req_value["include"]) && !test_value.include?(req_value["require"])
								# this tier doesn't meet this requirement
								is_valid = false

								# print error message
								@cli_obj.printStr(
									"=> ERROR: The #{@@config_file_basename_} file doesn't meet the requirement of having the "\
									"key \"#{req_value["require"]}\", as a requirement of the key \"#{req_path_parts.last}\" including the value "\
									"\"#{req_value["include"]}\", at \"#{tier_full_path}\"",
									false
								)
							end
						# it doesn't -> check if a default value exists for this requirement key
					elsif template[req_path_parts.first][req_path_parts.last].has_key?("default_value")
							# it does
							# check if it includes this relevant value and if so if this tier has the required key
							if template[req_path_parts.first][req_path_parts.last]["default_value"].include?(req_value["include"]) && !test_value.include?(req_value["require"])
								# this tier doesn't meet this requirement
								is_valid = false

								# print error message
								@cli_obj.printStr(
									"=> ERROR: The #{@@config_file_basename_} file doesn't meet the requirement of having the "\
									"key \"#{req_value["require"]}\", as a requirement of the default value for the key \"#{req_path_parts.last}\" "\
									"including the value \"#{req_value["include"]}\", at \"#{tier_full_path}\"",
									false
								)
							end
						end
					}
				}

				# return the boolean indicating whether this tier is valid
				return(is_valid)
			}

			# call the lambda on the entire config file's content and the entire
			# config validation file's content
			return(process_tier.call(@config_content.clone, @@config_validation_content_.clone, "root"))
		end

		# resets all the variables used to control the behaviour of scan()
		# NOTE: the priority used is:
		# 		1) the command line args provided
		# 		2) the config JSON file
		# 		3) the default fallback values
		# NOTE: not all variables have a config file variation
		def resetScanVars()
			# check if the config file's content is empty
			if @config_content.empty?
				# it is -> either a config file wasn't found or it is empty
				# bail out
				return
			end

			# loop through the scan variables that have a config file variation
			# NOTE: the names of these variables are in the keys of the "option" property of the config_validation.json file
			@@config_validation_content_["key_accepts"]["options"]["each_value"]["key_accepts"].each { |name, data|
				# check if this "option" is a scan variable
				if !data.has_key?("scan_default_value")
					# it isn't, so move on
					next
				end

				# check if a command line flag was provided with a value for this scan variable
				if @cmd_line_args.has_key?(name.to_sym)
					# it was
					# set this instance variable to its value in the command line flag
					new_value = @cmd_line_args[name.to_sym]
				# it wasn't -> check if the config file has the "options" key and if a value for this scan variable exists
				elsif @config_content.has_key?("options") && @config_content["options"].has_key?(name)
					# it does
					# set this instance variable to its value in the configuration file
					new_value = @config_content["options"][name]
				else
					# it doesn't
					# set this instance variable to its default value defined in the config_validation.json file
					new_value = data["scan_default_value"]
				end

				# set this variable's new value
				instance_variable_set("@#{name}", new_value)
			}

			# loop through each internal scan variable
			@internal_scan_vars.each { |name, fallback_value|
				# check if a command line flag was provided with a value for this scan variable
				if @cmd_line_args.has_key?(name)
					# it was
					# set this instance variable to its value in the command line flag
					new_value = @cmd_line_args[name]
				else
					# it wasn't
					# set this instance variable to its default fallback value
					new_value = fallback_value
				end

				# set this variable's new value
				instance_variable_set("@#{name.to_s}", new_value)
			}
		end

		# scans each of the watch list items and processed them as necessary
		def scan()
			# check if a config file was found
			if @config_file_dirname.empty?
				# it wasn't
				# print warning message
				@cli_obj.printStr(
					"=> WARNING: A config file couldn't be found in this project's directory tree.\n"\
					"Please create a file named \"#{@@config_file_basename_}\" or use the command \"init\" to "\
					"create a basic config file in the current directory",
					false
				)

				# bail out of this method
				return
			end

			# make sure the latest config file has been parsed before starting the scan
			# NOTE: relevant if the file was changed while the program is running, but not in active scan mode
			handleConfigFile(@config_file_dirname)

			# build the config file's absolute path
			config_path = "#{@config_file_dirname}/#{@@config_file_basename_}"

			# check if the program is in "watch mode"
			if @watch_mode
				# it is
				# set the message to be printed
				message = "\nwatching for changes...\n=> press CTRL-C to terminate\n"
			else
				# it isn't
				# set the message to be printed
				message = "\nprocessing files...\n"

				# set the sleep timer to zero, since the loop will only run once
				@sleep_timer = 0.0
			end

			# print running message
			@cli_obj.printStr(message, false)

			# loops until the user presses CTRL-C or only once if the program is not in "watch mode"
			begin
				# check if the config file is up-to-date
				if File.stat(config_path).mtime > @config_mtime
					# the config file is newer than the one used to build the current watch and ignore lists
					begin
						# search for the config file and if it exists handle it
						# it will also call for a rebuild of all relevant lists
						handleConfigFile(@config_file_dirname)
					rescue Interrupt => e
						# something went wrong while handling the config file
						# bubble the exception up
						raise(e)
					end
				else
					# it is
					# rebuild all the relevant lists
					buildAllLists()
				end

				# loop through each of the watch paths
				@watch_list.each { |item|
					# stores the files to check for this path
					# format: [int index] = {
					# 	:out => absolute path to store the bundle file,
					# 	:file_paths => array of absolute file paths
					# }
					# build the array with relevant files
					files = processWatchPath(item)

					# check if any files were found
					if files.empty?
						# no, so move to next watch_list element
						next
					end

					# check if this item refers to bundling multiple files
					joining = item[:opts].include?("join")

					# run the files found against the ignore list
					files = checkAgainstIgnore(files, joining)

					# loop through each validated file
					files.each { |file|
						# check if this watch list entry has any relevant files to process
						if file[:file_paths].empty?
							# it doesn't, so move on
							next
						end

						# grab the first path in the array of files
						# NOTE: if bundling multiple files, this will only be used to determine the bundle
						# 		file's path -> all relevant files will be added to the bundle file
						file_current = file[:file_paths].first

						# get this file's basename
						file_basename = File.basename(file_current)

						# find the position of the last "." in this file's basename
						file_ext_pos = file_basename.rindex(".")

						# check if there are any "."
						if file_ext_pos === nil
							# there aren't, so this file doesn't have an explicit extension
							# move on to next file
							next
						end

						# determine the starting position of this file's extension
						file_ext_pos += 1

						# store this file's extension
						file_ext = file_basename[file_ext_pos..-1]

						# check if this file will be bundled
						if joining
							# it will
							# this file's bundle path will be the "joined.min.*" file's path
							file_out_path = "#{file[:out]}/#{@@output_file_names_[:join]}.#{@@valid_file_types_[file_ext]}"
						else
							# it won't
							# check if this file is of the same type as a bundle file
							if @@valid_file_types_[file_ext].eql?(file_ext)
								# it is, so the file that will be processed is this file directly
								# the output file's extension is this file's extension
								file_out_ext = file_ext
							else
								# it isn't, so the file that will be processed is the file
								# resulting from the compilation of this file
								# the output file's extension is the compiled file's extension
								file_out_ext = @@valid_file_types_[file_ext]
							end

							# build this output file's absolute path
							file_out_path = "#{file[:out]}/#{file_basename[0...file_ext_pos-1]}.#{@@output_file_names_[:nojoin]}.#{file_out_ext}"
						end

						# stores whether this output file needs to be built
						# either because it doesn't exist or because it is not up-to-date with the its source files
						build_output = !outputUpToDate(file_out_path, file[:file_paths].clone)

						# stores whether this output file needs to be minimized
						minimize_output = false

						# check if this output file will be built this scan cycle
						if build_output
							# it will
							# if the program is configured to minimize all output files then this
							# output file needs to be minimized
							minimize_output = @minimize
						# it will not -> check if this output file's auxiliary file exists
						elsif File.exist?("#{file_out_path}#{@@aux_file_extra_path_}")
							# it does
							# open this output file's auxiliary file in read mode and get its contents
							aux_file_content = JSON.parse(IO.read("#{file_out_path}#{@@aux_file_extra_path_}", mode: "r"))

							# check if its minimized status matches the current program's minimize configuration
							# check if this output file is minimized and the current program configuration doesn't
							# want the output files to be minimized
							if aux_file_content["minimized"] && !@minimize
								# yes
								# this output file needs to be rebuilt and not minimized
								build_output = true
								minimize_output = false
							# no -> check if this output file is not minimized and the current program configuration
							# wants the output files to be minimized
							elsif !aux_file_content["minimized"] && @minimize
								# yes
								# this output file needs to be minimized
								minimize_output = true
							end
						else
							# it doesn't
							# build this output file
							build_output = true

							# minimize this output file if the current program configuration defines it
							minimize_output = true
						end

						# check if this output file needs to be built
						if build_output
							# it does
							# create the raw version of the output file
							# NOTE: this output file doesn't have any processing yet (ex: minimization)
							if createOutputFile(file_out_path, file[:file_paths].clone)
								# print message informing the file was created/updated
								@cli_obj.printStr("=> UPDATED: #{file_out_path}", true)
							else
								# something went wrong while creating the output file
								# print warning message
								@cli_obj.printStr("=> WARNING: an error occured while creating the file \"#{file_out_path}\"", true)

								# move on to the next entry
								next
							end
						end

						# check if this output file needs to be minimized
						if minimize_output && File.stat(file_out_path).size > 0
							# it does
							# execute the minimization process
							if minimizeFile(file_out_path)
								# the minimization was successful
								# print message
								@cli_obj.printStr("=> MINIMIZED: #{file_out_path}", true)
							else
								# the minimization failed
								# print warning message
								@cli_obj.printStr("=> WARNING: an error occured while minimizing the file \"#{file_out_path}\"", true)
							end
						end
					}
				}

				# make sure the "force build" flag is turned off
				@force_build = false

				# wait before starting the next scan cycle
				sleep(@sleep_timer)
			end while (@watch_mode)
		end

		# calls for the build of all relevant lists (watch and ignore)
		# raises an "Interrupt" exception on a failure
		def buildAllLists()
			# build the watch list
			@watch_list = buildList("watch")

			# check if the watch list was successfully built
			if @watch_list === nil
				# it wasn't
				# print error message
				@cli_obj.printStr("=> ERROR: The watch list couldn't be built. Please confirm that its syntax is correct", false)

				# terminate the program
				raise(Interrupt)
			end

			# build the ignore list
			@ignore_list = buildList("ignore")

			# check if the ignore list was successfully built
			if @ignore_list === nil
				# it wasn't
				# print error message
				@cli_obj.printStr("=> ERROR: The ignore list couldn't be built. Please confirm that its syntax is correct", false)

				# terminate the program
				raise(Interrupt)
			end
		end

		# this method builds the watch and ignore lists, based on their respective properties in the config file
		# receives the config key to use to build the list
		# returns an array of hashes with format:
		# [int index] = Hash
		# or returns nil if the list couldn't be built
		def buildList(config_property)
			# stores the final data
			list = Array.new

			# check if a valid property was provided
			if config_property.class != String || config_property.empty?
				# it wasn't, so return a failure
				return(nil)
			end

			# check if the config file has this property
			if !@config_content.has_key?(config_property)
				# it hasn't, so return the empty list
				return(list)
			end

			# stores the current index the loop below is in
			array_index = 0

			# loop through each hash in the array
			@config_content[config_property].each { |rule_data|
				# prepare this entry's data hash
				entry_data = {
					:path => []
				}

				# loop through each path for this rule
				rule_data["paths"].each{ |path|
					# replace any "\" for a "/" and build the path's aboslute path
					entry_data[:path].push(File.absolute_path(path.to_s.strip.gsub(/\\/, "/"), @config_file_dirname))
				}

				# sort the list by path, from the lower to the higher path
				entry_data[:path].sort! { |h1, h2| h2 <=> h1 }

				# check if the list being built is the watch list
				if config_property.eql?("watch")
					# it is
					# loop through each valid property of a "watch" list entry, based on the
					# contents of the config_validation.json file
					@@config_validation_content_["key_accepts"]["watch"]["each_value"]["each_value"]["key_accepts"].each { |key, value|
						# check if this rule has a property with this "key", ignoring the "key" with "path" (it has been handled above)
						if key != "paths" && rule_data.has_key?(key)
							# it has
							# check if this "key" is storing paths
							if value.has_key?("path_to")
								# it is
								# handle processing the path(s)
								case rule_data[key].class.to_s
								# check if this "key" has a string with 1 path
								when "String"
									# it has
									# store a semi-processed version of this path
									cur_path = rule_data[key].to_s.strip

									# check if the this path is pointing to a file
									# NOTE: all file handled by this program have an extension
									if cur_path.index(/\.[^\.\/\\]+$/i) != nil
										# it is
										path_to = "file"
									else
										# it isn't -> it is pointing to a directory
										path_to = "dir"
									end

									# check if this path is pointing to the correct type between file or directory
									if !value["path_to"].eql?(path_to)
										# it isn't
										# print error message
										@cli_obj.printStr("=> ERROR: The path in \"watch\" -> \"#{array_index}\" -> \"#{key}\" in the configuration file is pointing to a #{path_to} and should point to a #{value["path_to"]}", true)

										# return a failure
										return(nil)
									end

									# store the path in its absolute form
									entry_data[key.to_sym] = File.absolute_path(cur_path.gsub(/\\/, "/"), @config_file_dirname)
								# it hasn't -> check if this "key" has an array of paths
								when "Array"
									# it has
									# store the paths in their absolute form
									entry_data[key.to_sym] = rule_data[key].map! { |temp_path|
										# store a semi-processed version of this path
										cur_path = temp_path.to_s.strip

										# check if the this path is pointing to a file
										# NOTE: all file handled by this program have an extension
										if cur_path.index(/\.[^\.\/\\]+$/i) != nil
											# it is
											path_to = "file"
										else
											# it isn't -> it is pointing to a directory
											path_to = "dir"
										end

										# check if this path is pointing to the correct type between file or directory
										if !value["path_to"].eql?(path_to)
											# it isn't
											# print error message
											@cli_obj.printStr("=> ERROR: The path in \"watch\" -> \"#{array_index}\" -> \"#{key}\" -> \"#{temp_path}\" in the configuration file is pointing to a #{path_to} and should point to a #{value["path_to"]}", true)

											# return a failure
											return(nil)
										end

										# pass the absolute path to the block's outside
										File.absolute_path(cur_path.gsub(/\\/, "/"), @config_file_dirname)
									}
								end
							else
								# it isn't
								# store this rule's "key" value as is
								entry_data[key.to_sym] = rule_data[key]
							end
						end
					}

					# check if any options were provided for this watch rule
					if !entry_data.has_key?(:opts) || entry_data[:opts].empty?
						# no options were provided
						# use the watch rule's default options
						entry_data[:opts] = @@default_watch_opts_
					end

					# check if the options have an explicit "join" or "nojoin" value
					if !entry_data[:opts].include?("join") && !entry_data[:opts].include?("nojoin")
						# they don't
						# add the default join behavior to the options
						entry_data[:opts].push(@@default_join_behavior_)
					end
				else
					# it isn't -> its the ignore list
					# store this rule's "opts" property
					entry_data[:opts] = (rule_data["opts"] === nil ? [] : rule_data["opts"])

					# check if any options were provided for this watch rule
					if !entry_data.has_key?(:opts) || entry_data[:opts].empty?
						# no options were provided
						# use the watch rule's default options
						entry_data[:opts] = @@default_ignore_opts_
					end
				end

				# add this entry's data to the list
				list.push(entry_data)

				# advance the current index this loop is in by 1
				array_index += 1
			}

			# return the final data
			return(list)
		end

		# searches for the provided pattern (array or string), starting in search_path and following any
		# sub-folders as needed
		# receives an array with basenames, a string with an absolute path to a directory and an array
		# with file absolute paths to ignore
		# returns an Array with format: [int index] = file absolute path
		def findFiles(search_pattern, search_path, ignore_file_paths)
			# stores the files found
			files_found = Array.new

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

					# build this file's absolute path
					file_abs_path = "#{search_path}/#{file_rel_path}"

					# check if this file is in the ignore paths
					if ignore_file_paths.include?(file_abs_path)
						# it is, so ignore it
						next
					end

					# store this file's absolute path
					files_found.push(file_abs_path)
				}
			end

			# return the final data
			return(files_found)
		end

		# checks an array of file hashes agaist the ignore list
		# returns a hash with the same format as the input, but only with the files that
		# are to be watched
		def checkAgainstIgnore(watch_files, joining)
			# check if the ignore list is empty
			if @ignore_list.empty?
				# it is, so nothing to do
				return(watch_files)
			end

			# stores the final data
			result = Array.new

			# loop through each group of watch files
			watch_files.each { |watch_item|
				# add this watch rule's data to the final data
				result.push({
					:out => watch_item[:out],
					:file_paths => Array.new
				})

				# loop while there are paths to check, in this watch item
				watch_item[:file_paths].each { |watch_item_current|
					# controls whether this path will be watched or not
					to_watch = true

					# search the ignore list for a relevant item
					@ignore_list.each { |ig_item|
						# check if this ignore list entry is relevant for the current watch list item
						# loop through each path in this ignore rule
						ig_item[:path].each { |ig_path|
							# check if this ignore list item is a folder
							if File.directory?(ig_path)
								# it is
								# split the watch list file's basename from the directory path
								file_detail = File.split(watch_item_current)

								# determine the ignore list's folder degree of parenthood to this watch list file
								folder_comparison = fileFolderRel(watch_item_current.downcase, ig_path.downcase)
								if folder_comparison === 1
									# the ignore list folder is the 1st degree parent of the watch list file
									# i.e., it's the folder the file is in
									# in this case the folder's "nosub" option is irrelevant

									# check the watch list file's extension against the ignore list directory's options
									# and the join or no join status
									if ig_item[:opts].include?(file_detail[1].split(".").last) and (!ig_item[:opts].include?("nojoin") or joining)
										# the ignore list parent folder is set to ignore files of this type
										# and either it's ignoring all operations or just joining and this watch rule is doing one
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
									if !ig_item[:opts].include?("nosub") and ig_item[:opts].include?(file_detail[1].split(".").last) and (!ig_item[:opts].include?("nojoin") or joining)
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
							elsif File.exist?(ig_path) and watch_item_current.downcase.eql?(ig_path.to_s.downcase)
								# it is
								# check if we don't want this file minimized or if we just don't want it to be minimized in a joint file
								if !ig_item[:opts].include?("nojoin") or joining
									# either this file is not to be minimized (dosn't have nojoin)
									# or it's not to be minimized in joint actions and we're trying to do so (has nojoin and we're joining)
									# skip this file
									to_watch = false

									# a relevant ignore list item was found, so no need to continue checking the rest
									break
								end
							end
						}

						# check if this watch path is no longer flagged for watching
						if !to_watch
							# yes, so no need to continue checking
							break
						end
					}

					# check if this watch list item is to be watched
					if to_watch
						# it is
						# add this file's absolute path to the final data, in its array of files to be joined
						result.last[:file_paths].push(watch_item_current)
					end
				}
			}

			# return the final data
			return(result)
		end

		# receives the data from a watch list item, and builds the data with all
		# the relevant files
		# returns an array with format:
		# [int index] = {
		# 	:out => absolute path to store the bundle file,
		# 	:file_paths => array of absolute file paths
		# }
		def processWatchPath(item_data)
			# stores the files found as well as the path where their bundle/.min file should be stored
			files = Array.new

			# stores the file extensions of this rule's valid paths that point to files
			file_paths_exts = []

			# stores the file extensions that were added to this watch rule's "opts" due to there being at least 1 valid path
			# pointing to a file of that type and its associated "opts" value wasn't explicitly provided in the config file
			# NOTE: "opts" values are added since that is what will trigger the algorithm below to process those files, but
			# 			if there are watch paths pointing to directories it would cause all files of these types to be captured
			# 			as relevant to this watch rule, when that is not the intention of the user with this watch rule (if it was
			# 			then that "opts" value would have been given explicitly)
			opts_added = []

			# stores the valid paths of this rule that point to a directory
			# NOTE: these paths will be the ones used when searching for all files of certain extensions
			dir_paths = []

			# loop through each path for this watch rule
			item_data[:path].each { |path|
				# check if this path points to a directory
				path_is_dir = File.directory?(path)

				# check if this path is a valid directory or file
				if !path_is_dir && !File.exist?(path)
					# it isn't
					# print warning message
					@cli_obj.printStr("=> WARNING: The path \"#{path.to_s}\" in the watch list doesn't exist", true)

					# move to next path
					next
				end

				# check if the path points to a folder
				if path_is_dir
					# it does
					# check if this directory path already exists in "dir_paths"
					if !dir_paths.include?(path)
						# it doesn't, so add it
						dir_paths.push(path)
					end
				else
					# it doesn't -> adjust some of the item_data information allowing this method
					# to process this individual file
					# find the index of the last "." in this path
					ext_pos = path.rindex(".")

					# check if this path has a "."
					if ext_pos === nil
						# it doesn't
						# move to next path
						next
					end

					# store this file's extension
					file_ext = path[ext_pos + 1..-1]

					# check if the extension of the file pointed by this path is already in "file_paths_exts"
					if !file_paths_exts.include?(file_ext)
						# it doesn't
						# store this file's extension
						file_paths_exts.push(file_ext)
					end

					# check if the item_data has the property "#{file_ext}_in"
					if item_data.has_key?("#{file_ext}_in".to_sym)
						# it does
						# check if this path is already stored
						if !item_data["#{file_ext}_in".to_sym].include?(path)
							# it isn't
							# add this path to the item_data symbol property "#{file_ext}_in"
							item_data["#{file_ext}_in".to_sym].push(path)
						end
					else
						# it doesn't
						# set the item_data symbol property "#{file_ext}_in" to this path
						item_data["#{file_ext}_in".to_sym] = [path]
					end
				end
			}

			# check if any of the valid paths points to a file
			if !file_paths_exts.empty?
				# they do
				# stores a boolean that is true if at least 1 of this rule's valid paths points to a directory or false
				# if all point to files
				only_file_paths = dir_paths.empty?

				# loop through the valid file types for the options of a watch rule
				@@valid_file_types_.each_key { |file_ext|
					# check if all the valid paths point to files and if this file extension was given as an
					# option, but is not relevant for the valid file paths of this rule
					if only_file_paths && item_data[:opts].include?(file_ext) && !file_paths_exts.include?(file_ext)
						# yes
						# remove this option
						# NOTE: if any file extension is left in the options that doesn't match one of the specific file
						# paths then all files for that extension will be looked for, wasting resources
						item_data[:opts].delete(file_ext)
					# no -> check if this file extension is relevant for the valid file paths of this rule, but
					# isn't included as an option for this watch rule
					elsif !item_data[:opts].include?(file_ext) && file_paths_exts.include?(file_ext)
						# yes
						# add this option
						item_data[:opts].push(file_ext)

						# store this as an option that wasn't provided in the config file
						if !opts_added.include?(file_ext)
							opts_added.push(file_ext)
						end
					end
				}
			end

			# check if the relevant files for this watch path are to be bundled into 1 file
			if item_data[:opts].include?("join")
				# they are
				joining = true

				# stores, for each relevant file type, an array of file absolute paths to be bundled
				# format: [file type] = array of absolute paths
				files_to_join = Hash.new
			else
				# they aren't
				joining = false
			end

			# stores the file types that will need to be searched for
			search_file_types = Array.new

			# stores the file absolute paths that are not to be searched for
			search_ignore_paths = Array.new

			# stores the files found to be relevant for this watch path
			# format: [int index] = file abs path
			files_found = Array.new

			# loop through the supported bundle file types
			@@bundle_file_types_.each { |bundle_file_type, supported_file_types|
				# stores if at least 1 of this bundle's supported file types is relevant
				bundle_relevant = false

				# loop through this bundle's supported file types
				supported_file_types.each { |file_type|
					# check if this file type is relevant for this watch path
					if item_data[:opts].include?(file_type)
						# it is
						# check if specific file(s), for this type, were proivided
						# as entry points
						if item_data.has_key?("#{file_type}_in".to_sym)
							# they were
							# loop through each entry file
							item_data["#{file_type}_in".to_sym].each { |abs_path|
								# check if this path is a valid file
								if !File.exist?(abs_path)
									# it isn't
									# move to next entry file
									next
								end

								# check if this file's type is the same as the bundle's file type
								if !file_type.eql?(bundle_file_type)
								    # it isn't
									# check if a "crawl" action for this file type is defined
								    if @@file_type_callbacks_[file_type] != nil && @@file_type_callbacks_[file_type].has_key?(:crawl)
										# it is
										# stores the components needed to build the output absolute path for files of this type
										# format: [0] = dirname, [1] = extension (without the ".")
										out_path_parts = []

										# check if an explicit output path was provided
								        if item_data.has_key?("#{file_type}_out".to_sym)
								            # it was
								            out_path_parts[0] = item_data["#{file_type}_out".to_sym]
								        else
								            # it wasn't
								            # the output path will be in this file's directory
								            out_path_parts[0] = File.dirname(abs_path)
								        end

										# add the output file's extension
										out_path_parts[1] = bundle_file_type

										# execute the "crawl" action
								        if !self.send(@@file_type_callbacks_[file_type][:crawl], abs_path, out_path_parts)
								            # something went wrong while crawling this file
								            # NOTE: the error message was printed by the callback
								            next
								        end

										# stores the absolute paths that need to be checked for import path chain
										# starting with this entry point file
										files_to_check = [abs_path]

										# stores the files that have been identified as being in this entry point file's import chain
										files_checked = []

										# loop through all the files in this entry point file's import chain
										while !files_to_check.empty?
											# get this file's absolute path
											file_to_check = files_to_check.pop()

											# add this file's output path to the ignore paths, avoiding these output files
											# from being catched by the search files method
											search_ignore_paths.push(@file_crawl_data[file_to_check][:out_path])

											# add this file as having been identified as being part of the import chain
											files_checked.push(file_to_check)

											# add any new file paths in this import chain to the array of paths to check
											files_to_check = files_to_check | (@file_crawl_data[file_to_check][:imports] - files_checked)
										end
									else
										# it isn't
										# ignore this file
										next
									end
								end

								# add this relevant file to "files_found"
								files_found.push(abs_path)
							}
						end

						# check if this file type was provided as an "opts" in the config file and
						# if it is a bundle file type
						if !opts_added.include?(file_type) && file_type.eql?(bundle_file_type)
							# yes, so store it as a file type to search for in any valid path pointing to a directory
							search_file_types.push(file_type)
						end

						# flag this bundle as relevant
						bundle_relevant = true
					end
				}

				# check if this bundle is relevant and if a joint file will be created
				if bundle_relevant && joining
					# yes
					# create a key for this bundle's file type in files_to_join
					files_to_join[bundle_file_type] = Array.new
				end
			}

			# check if any files need to be searched for
			# only if there are file types to search and there are paths pointing to directories
			if !search_file_types.empty? && !dir_paths.empty?
				# yes
				# build the base search pattern to be used
				search_pattern = "*.{#{search_file_types.join(",")}}"

				# check if the search should go inside subfolders
				if !item_data[:opts].include?("nosub")
					# it should
					# adjust the search pattern to search folders recursively
					search_pattern = File.join("**", search_pattern)
				end

				# loop through each valid path of this rule that points to a directory
				dir_paths.each { |dir_path|
					# search for all files matching the search file types and add them to "files_found"
					files_found = files_found | findFiles(search_pattern, dir_path, search_ignore_paths)
				}
			end

			# check if any relevant files were found
			if files_found.empty?
				# no, so bail out
				return(files)
			end

			# create the regexp objects matching the file names that should not be captured by a watch rule
			regex_ignore = [
				Regexp.new(Regexp.escape("/#{@@output_file_names_[:join]}."), Regexp::IGNORECASE),
				Regexp.new("\\.(#{Regexp.escape(@@output_file_names_[:nojoin])}|#{Regexp.escape(@@ts_combined_extra_path_)})\\.", Regexp::IGNORECASE)
			]

			# stores the anonymous function that checks if the provided path matches any of the "regex_ignore" patterns
			# returns true if no pattern matched or false otherwise
			regex_ignore_lambda = lambda { |path|
				# loop through the regex with the ignore file patterns
				regex_ignore.each { |re_obj|
					# check if this path matches this pattern
					if re_obj.match(path) != nil
						# it does, so return false
						return(false)
					end
				}

				# at this point, no pattern matched
				return(true)
			}

			# check if these files will be joined
			if joining
				# they will
				# loop through each file found
				files_found.each { |file_abs_path|
					# check if this file found matches any of the ignore file patterns
					if !regex_ignore_lambda.call(file_abs_path)
						# it does, so ignore it
						next
					end

					# get this file's directory path
					file_dirname = File.dirname(file_abs_path)

					# find this file's type
					file_type = file_abs_path[file_abs_path.rindex(".") + 1..-1]

					# store this file's bundle file type
					bundle_file_type = @@valid_file_types_[file_type]

					# add this file to the array of files to be joined, based on this file's bundle type
					files_to_join[bundle_file_type].push(file_abs_path)
				}

				# loop through the files to join for each bundle file type
				files_to_join.each { |bundle_file_type, abs_paths|
					# if this file type has at least 1 file found, add it to the result set
					if !abs_paths.empty?
						# add these files to the final data
						files.push({
							# if no destination for the bundle file was provided, store it in the chosen joined location
							:out => item_data[:out],
							:file_paths => abs_paths
						})
					end
				}
			else
				# they won't
				# loop through each file found
				files_found.each { |file_abs_path|
					# check if this file found matches any of the ignore file patterns
					if !regex_ignore_lambda.call(file_abs_path)
						# it does, so ignore it
						next
					end

					# add this file to the final data
					files.push({
						# if no destination for the minimized file was provided, store it in this file's directory
						:out => item_data[:out],
						:file_paths => [file_abs_path]
					})
				}
			end

			# return the final data
			return(files)
		end

		# receives an absolute path to an entry file and will crawl it, storing
		# the files being included in @file_crawl_data
		# expects the callback function to a string or false if it failled
		# returns true if successful, false otherwise
		# NOTE: the callback can be a lambda or a Proc
		def crawlFile(entry_path, output_path_parts, re_pattern, callback)
			# store the dirname of the entry point file
			entry_dirname = File.dirname(entry_path)

			# stores the files that still need to be crawled
			# starts with the entry file's path
			file_queue = [entry_path]

			# stores the all imported file in this entry file's chain
			imported_abs_paths = []

			# loop while there are files left to crawl
			while !file_queue.empty?
				# extract the last element in the file queue
				crawl_path = file_queue.pop()

				# get the modify time of this file
				crawl_path_mtime = File.stat(crawl_path).mtime

				# check if this file needs to be crawled
				# by checking if it has been crawled already and if it has check if it
				# was modified since the last crawl
				if !@file_crawl_data.has_key?(crawl_path) || @file_crawl_data[crawl_path][:last_crawl] < crawl_path_mtime
					# this file needs to be crawled
					begin
						# read this file's content
						file_content = IO.read(crawl_path)
					rescue IOError
						# couldn't read this file
						# print warning message
						@cli_obj.printStr(
							"=> WARNING: Couldn't read the file \"#{crawl_path}\" while building the list of files "\
							"being included by the entry file \"#{entry_path}\"",
							true
						)

						# return a failure
						return(false)
					end

					# calculate this file's relative position to the entry_path
					crawl_path_rel_pos = File.dirname(crawl_path).gsub(Regexp.new("^#{Regexp.escape(entry_dirname)}", Regexp::IGNORECASE), "")

					# create the crawled file's entry in @file_crawl_data
					@file_crawl_data[crawl_path] = {
						:imports => [],
						:out_path => "#{output_path_parts[0]}#{crawl_path_rel_pos}/#{File.basename(crawl_path, ".*")}.#{output_path_parts[1]}",
						:last_crawl => crawl_path_mtime
					}

					# loop while there are re_pattern matches left in file_content
					while (re_match = re_pattern.match(file_content)) != nil
						# call the anonymous function
						callback_return = callback.call(crawl_path, re_match)

						# check if the lambda function returned a failure or an invalid data type
						if callback_return === false || !callback_return.class.to_s.eql?("Array")
							# it did
							# something went wrong while executing the lambda function
							# return a failure
							return(false)
						else
							# it didn't
							callback_return.each { |file_path|
								# check if the file found hasn't been encountered already
								if !imported_abs_paths.include?(file_path) && !file_queue.include?(file_path)
									# it hasn't
									# add it to the queue
									file_queue.push(file_path)
								end

								# add the file found to the crawled file's array of imported files
								@file_crawl_data[crawl_path][:imports].push(file_path)
							}
						end

						# change file_content to have all the text after this match
						file_content = re_match.post_match
					end
				else
					# this file doesn't needs to be crawled
					# add this file's imports to the queue
					file_queue = file_queue | (@file_crawl_data[crawl_path][:imports] - imported_abs_paths)
				end

				# add the crawled file to the array of relevant files
				imported_abs_paths.push(crawl_path)
			end

			# at this point everything went ok
			return(true)
		end

		# receives an absolute path to an SCSS or SASS file and will crawl it, storing
		# the files being included in @file_crawl_data
		# returns true if successful, false otherwise
		def crawlSASS(entry_path, output_path_parts)
			# build the lambda function that will be applied to each capture group
			lambda_func = lambda { |crawl_path, re_match|
				# stores the relevant files found
				files_found = Array.new

				# stores the file extensions assumed by the SASS compiler for "@import" statements
				# that don't have an explicit file extension
				# NOTE: add a "." to each extension here in order to allow code optimization below
				# NOTE: store the paths in reverse order to the intended order of their crawl
				assumed_ext = [".sass", ".scss"]

				# stores the character(s) at the start of a file's name that identify a "partial"
				partial_str = "_"

				# get the directory path of the file being crawled
				crawl_dirname = File.dirname(crawl_path)

				# split this "@import" by "," for the cases where multiple files are being imported in the
				# same "@import" statement, and loop through each one of the files
				re_match[1].split(",").each { |src_match|
					# stores the absolute path for this imported file, if one can be found
					import_path = ""

					# check if this src_match has a file path
					if (import = src_match.strip.match(/[\"\']?([^\"\']+)[\"\']?/i)) != nil
						# it has
						# check if this match is pointing to an external asset
						if import[1].index(/^(http|https):/i) != nil
							# it is, so ignore it
							next
						end

						# check if this match is using the "url()" function
						if import[1].index(/^url/i) != nil
							# it is, so ignore it
							next
						end

						# stores the extensions that will need to be looped over
						extensions = []

						# check if this match has an explicit file extension
						if import[1].index(/\.[^\.\/\\]+$/) == nil
							# it doesn't
							# loop through all the extensions assumed by the SASS compiler
							extensions = assumed_ext
						end

						# loop while there are relevant extensions left
						# can terminate early if a valid path is found
						begin
							# get an extension to use
							ext = extensions.pop()

							# build this tentative file's absolute path
							file_abs_path = File.absolute_path("#{import[1]}#{ext}", crawl_dirname)

							valid_path = (0..1).each { |i|
								# check if this file path is valid
								if File.exist?(file_abs_path)
									# it is
									# exit this loop returning TRUE
									break(true)
								# it isn't -> check if there is a need to check for a "partial"
								# only if this is the 1st iteration and the file path isn't already a "partial"
								elsif i == 0 && !file_abs_path.end_with?("#{partial_str}#{import[1]}#{ext}")
									# there is
									# split the file's path into dirname and basename
									file_abs_path_parts = File.split(file_abs_path)

									# add the "partial" identifier to the start of the basename
									file_abs_path_parts[1] = "#{partial_str}#{file_abs_path_parts[1]}"

									# build the partial file's path
									file_abs_path = File.join(file_abs_path_parts)
								end
							}

							# check if a valid path was found
							if valid_path === true
								# it was
								# store this file's absolute path
								import_path = file_abs_path

								# exit this loop
								break
							end
						end while !extensions.empty?
					end

					# check if a matching file was found
					if import_path.empty?
						# it wasn't
						# check if this match is a relevant one
						if import != nil
							# it is
							# print warning message
							@cli_obj.printStr(
								"=> WARNING: Couldn't find the file with signature \"#{import[1]}\" being imported in the file \"#{crawl_path}\"",
								true
							)

							# return a failure
							return(false)
						end
					else
						# it was
						# check if this file found hasn't been encountered in this file
						if !files_found.include?(import_path)
							# it hasn't
							# add it to the array of files found
							files_found.push(import_path)
						end
					end
				}

				# return the files found
				return(files_found)
			}

			# check if this entry point file is an SCSS file
			if entry_path.index(/\.scss$/i) != nil
				# it is
				# build the import finding pattern
				import_pattern = /@import[\t ]+([\w\.\-\\\/\"\':, ]+)[^;"']*;/i
			else
				# it is a SASS file
				# build the import finding pattern
				import_pattern = /@import[\t ]+([\w\.\-\\\/\"\':, ]+)[^;"'\n]*\n/i
			end

			# call the method that will crawl the relevant files for this entry_path
			if !crawlFile(entry_path, output_path_parts, import_pattern, lambda_func)
				# something went wrong while crawling the relevant files for this entry path
				# return a failure
				return(false)
			end

			# at this point everything went OK
			return(true)
		end

		# receives an absolute path to an TypeScript file and will crawl it, storing
		# the files being included in @file_crawl_data
		# returns true if successful, false otherwise
		def crawlTypeScript(entry_path, output_path_parts)
			# build the lambda function that will be applied to each capture group
			lambda_func = lambda { |crawl_path, re_match|
				path = resolveNodeImportPath(crawl_path, re_match[1], [".tsx", ".ts"])

				return(path.class.to_s.eql?("String") ? [path] : path)
			}

			# check if a path to a tsconfig.json file was provided in the configuration file
			if @config_content["options"] != nil && @config_content["options"].has_key?("tsconfig")
				# it was
				# in this case the output files' paths will be determined by the TS compiler, based on the tsconfig.json file
				# which means the "output_path_parts" provided, that were built using the bundler.config.json file might
				# not be in synch and will cause the bundler program to be looking for the compiled JS files in the wrong path
				# build the absolute path to the relevant tsconfig.json file
				tsconfig_abs_path = File.absolute_path(@config_content["options"]["tsconfig"].to_s.strip.gsub(/\\/, "/"), @config_file_dirname)

				begin
					# parse the tsconfig JSON file's content
					tsconfig_content = JSON.parse(IO.read("#{tsconfig_abs_path}/tsconfig.json"))
				rescue IOError
					# the file couldn't be read
					# print error message
					@cli_obj.printStr("=> ERROR: Couldn't open the \"tsconfig.json\" file at \"#{tsconfig_abs_path}\", provided in the \"bundler.config.json\" file", false)

					# return a failure
					return(false)
				end

				# check if the tsconfig file has an explicit "outDir" property in the "compilerOptions" key
				if tsconfig_content["compilerOptions"] != nil && tsconfig_content["compilerOptions"].has_key?("outDir")
					# it has
					# store that path as this entry point TS file's output_path_parts[0]
					output_path_parts[0] = File.absolute_path(tsconfig_content["compilerOptions"]["outDir"].to_s.strip.gsub(/\\/, "/"), tsconfig_abs_path)
				else
					# it hasn't
					# store this entry point TS file's dirname as its output_path_parts[0]
					output_path_parts[0] = File.dirname(entry_path)
				end
			end

			# call the method that will crawl the relevant files for this entry_path
			if !crawlFile(entry_path, output_path_parts, /(import[^"']*["'][^"']+["']\)?;|\/\/\/[\t ]*<reference path=["'][^"']+["'][\t ]*\/>\n)/i, lambda_func)
				# something went wrong while crawling the relevant files for this entry path
				# return a failure
				return(false)
			end

			# at this point everything went OK
			return(true)
		end

		# resolves a module import, based on Node's import resolution rules, on file crawl_path
		# with import path import_path receives an optional array with specific extensions
		# to look for in imports without an extension these extensions will have a higher
		# priority than the default ones
		# returns a string with an absolute paths or false if the import couldn't be resolved
		def resolveNodeImportPath(crawl_path, import_path, specific_exts = [])
			# stores the file extensions assumed Node for "import" statements
			# that don't have an explicit file extension
			# NOTE: add a "." to each extension here in order to allow code optimization below
			# NOTE: since this program is built with websites in mind, the extension ".node"
			# 			is not being considered
			assumed_exts = [".js", ".json"]

			# check if any specific extensions were provided
			if specific_exts.class.to_s === "Array" && !specific_exts.empty?
				# there were
				# add them to the start of assumed_ext (so that they will be used first)
				assumed_exts = specific_exts | assumed_exts
			end

			# stores the anonymous function used to load an import as a file
			# returns a string with the file's absolute path, a "" if no valid path could be found
			# or false if an error occured (the message will be printed here)
			load_as_file = lambda { |dir_abs_path, import_rel_path, search_exts|
				# check if the "import_rel_path" has an explicit file extension
				if (re_match = /\.([^\.\/\\]+)$/i.match(import_rel_path)) != nil
					# it does
					# search only for that extension
					search_exts = [re_match[1]]
				end

				# loop through each search extension
				search_exts.each { |ext|
					# build the "import_rel_path"'s tentative absolute path, using "dir_abs_path"
					# as the reference point
					file_abs_path = File.absolute_path("#{import_rel_path}#{ext}", dir_abs_path)

					# check if this file path is valid
					if File.exist?(file_abs_path)
						# it is
						# return this file's absolute path
						return(file_abs_path)
					end
				}

				# at this point no valid file absolute path was found
				return("")
			}

			# stores the anonymous function used to load an import as a directory
			# returns a string with the file's absolute path, a "" if no valid path could be found
			# or false if an error occured (the message will be printed here)
			# NOTE: needs to be provided the search extensions because this anonymous function might
			# 			call load_as_file, which requires that information
			load_as_dir = lambda { |dir_abs_path, import_rel_path, search_exts|
				# build the absolute path to the assumed directory, using "dir_abs_path"
				# as the reference point
				assumed_abs_path = File.absolute_path(import_rel_path, dir_abs_path)

				# check if a "package.json" file exists in this directory
				if File.exist?("#{assumed_abs_path}/package.json")
					# it does
					begin
						# open and parse the package.json file
						package_json_content = JSON.parse(IO.read("#{assumed_abs_path}/package.json"))
					rescue Errno::ENOENT
						# something went wrong while opening and parsing the JSON file
						# print warning message
						@cli_obj.printStr(
							"=> WARNING: Couldn't parse the \"package.json\" located at \"#{assumed_abs_path}\"",
							true
						)

						# return a failure
						return(false)
					end

					# check if the "package.json" file has a "main" field
					if package_json_content.has_key?("main")
						# it has
						# try loading the combined path of "assumed_abs_path" + "path in main field"
						# as a file
						lambda_return = load_as_file.call(assumed_abs_path, package_json_content["main"], search_exts)

						# check if an absolute path for the import was found or an error occured
						if lambda_return === false || !lambda_return.empty?
							# yes, so return it
							return(lambda_return)
						end

						# try loading the combined path of "assumed_abs_path" + "path in main field"
						# as an index (use "load_as_file" giving ./index as the relative path)
						lambda_return = load_as_file.call(assumed_abs_path, "#{package_json_content["main"]}/index", search_exts)

						# check if an absolute path for the import was found or an error occured
						if lambda_return === false || !lambda_return.empty?
							# yes, so return it
							return(lambda_return)
						end
					end
				end

				# try loading "assumed_abs_path" as an index (use "load_as_file" giving ./index as the relative path)
				lambda_return = load_as_file.call(assumed_abs_path, "./index", search_exts)

				# check if an absolute path for the import was found or an error occured
				if lambda_return === false || !lambda_return.empty?
					# yes, so return it
					return(lambda_return)
				end

				# at this point no valid file absolute path was found
				return("")
			}

			# get the directory path of the file being crawled
			crawl_dirname = File.dirname(crawl_path)

			# check if the provided import path is wrapped in quotes or hasn't been
			# extracted from the import statement
			if (re_match = /["']([^"']+)["']/i.match(import_path)) != nil
				# it does
				# get the actual import path
				import_path = re_match[1]
			end

			# check if the import path is a relative path
			if import_path.start_with?("/", "./", "../")
				# it is
				# treat the import as being a FILE
				# call the anonymous function to load the import path as a file
				# using the file with the import statement as the reference point
				lambda_return = load_as_file.call(crawl_dirname, import_path, assumed_exts)

				# check if an absolute path for the import was found or an error occured
				if lambda_return === false || !lambda_return.empty?
					# yes, so return it
					return(lambda_return)
				end

				# treat the import as being a DIRECTORY
				# call the anonymous function to load the import path as a directory
				# using the file with the import statement as the reference point
				lambda_return = load_as_dir.call(crawl_dirname, import_path, assumed_exts)

				# check if an absolute path for the import was found or an error occured
				if lambda_return === false || !lambda_return.empty?
					# yes, so return it
					return(lambda_return)
				end
			end

			# stores the dirname to check for the existance of a "node_modules" directory
			# starting with the directory of the file being crawled
			cur_dirname = crawl_dirname

			# try loading the import as a NODE MODULE
			# loop through each directory in "crawl_dirname"'s directory tree,
			while !cur_dirname.empty?
				# check if "cur_dirname" ends with "node_modules"
				if cur_dirname.index(/\/node_modules\/?$/i) === nil
					# it doesn't, so add "/base_dirname" to it
					base_dirname = "#{cur_dirname}/node_modules"
				else
					# it does, so it can be used as is
					base_dirname = cur_dirname
				end

				# try loading base_dirname/import_path as a file
				lambda_return = load_as_file.call(base_dirname, import_path, assumed_exts)

				# check if an absolute path for the import was found or an error occured
				if lambda_return === false || !lambda_return.empty?
					# yes, so return it
					return(lambda_return)
				end

				# try loading base_dirname/import_path as a directory
				lambda_return = load_as_dir.call(base_dirname, import_path, assumed_exts)

				# check if an absolute path for the import was found or an error occured
				if lambda_return === false || !lambda_return.empty?
					# yes, so return it
					return(lambda_return)
				end

				# get the directory to be used in the next iteration
				next_dirname = File.dirname(cur_dirname)

				# check if the directory used in this iteration is the root of "crawl_path"
				if cur_dirname.eql?(next_dirname)
					# it is, so exit the loop
					break
				end

				# update the directory path for the next iteration
				cur_dirname = next_dirname
			end

			# at this point a valid file path couldn't be found for this match
			# print warning message
			@cli_obj.printStr(
				"=> WARNING: Couldn't find the file with signature \"#{import_path}\" being imported in the file \"#{crawl_path}\"",
				true
			)

			# return a failure
			return(false)
		end

		# handles checking if an entry point SCSS or SASS file needs to be compiled and
		# calling the SASS compiler if needed
		# returns 0 if no compilation was needed, 1 if the compilation was successful or -1
		# if the compilation failed
		def processSASS(entry_path)
			# check if this entry point file's crawl data is available
			if !@file_crawl_data.has_key?(entry_path)
				# it isn't
				# return a failure
				return(-1)
			end

			# stores whether this entry point file needs to be compiled
			# if the compiled file already exists then by default there is no need to compile
			compile_file = !File.exist?(@file_crawl_data[entry_path][:out_path])

			# check if the scan cycle this method was called from is in "force build" mode
			if @force_build
				# it is
				# compile this entry point file
				compile_file = true
			# it isn't -> check if this entry point file is still flagged as not needing compilation
			elsif !compile_file
				# it is
				# stores the files that need to be checked for their modify times
				# starting with the entry point file itself and its direct imported files
				files_to_check = @file_crawl_data[entry_path][:imports].clone.push(entry_path)

				# stores the files that have already been checked
				files_checked = []

				# store the modify time of this entry file's compiled output
				compiled_mtime = File.stat(@file_crawl_data[entry_path][:out_path]).mtime

				# loop through each relevant file
				begin
					# get the next file to check
					abs_path = files_to_check.pop()

					# check if this file was modified after the compilation was last executed
					if File.stat(abs_path).mtime > compiled_mtime
						# it was
						# the compiler needs to be executed again
						compile_file = true

						# no need to continue checking the remaining files
						break
					end

					# add this iteration's file to the array of checked files
					files_checked.push(abs_path)

					# add this iteration file's imported files to be checked
					# NOTE: only the files that haven't been found yet
					files_to_check = files_to_check | (@file_crawl_data[abs_path][:imports].clone - files_checked)
				end while !files_to_check.empty?
			end

			# check if the compiler needs to be called
			if compile_file
				# it does
				# print message informing that the SASS compiler is being executed
				@cli_obj.printStr("The entry file \"#{entry_path}\" is being compiled by the SASS compiler\n", true)

				# stores the command line instruction
				cmd_string = "sass"

				# check if the configuration file has any options for the SASS compiler
				if @config_content["options"] != nil && @config_content["options"].has_key?("sass_opts")
					# it has, so add them to the command line instruction
					cmd_string += " #{@config_content["options"]["sass_opts"]}"
				else
					# it hasn't, so add the default SASS compiler options
					cmd_string += " #{@@config_validation_content_["key_accepts"]["options"]["each_value"]["key_accepts"]["sass_opts"]["default_value"].to_s}"
				end

				# add the input and output paths to the command line instruction
				cmd_string += " #{entry_path} #{@file_crawl_data[entry_path][:out_path]}"

				# execute the command line instruction calling the SASS compiler
				result = system(cmd_string)

				if result === nil || result === false
					# something went wrong with the SASS compiler
					@cli_obj.printStr("=> ERROR: The file \"#{entry_path}\" couldn't be compiled by the SASS compiler", true)

					# return a failure
					return(-1)
				end

				# at this point, the compilation was successful
				return(1)
			else
				# it doesn't
				return(0)
			end
		end

		# handles checking if an entry point TypeScript file needs to be compiled and
		# calling the TS compiler if needed
		# returns 0 if no compilation was needed, 1 if the compilation was successful or -1
		# if the compilation failed
		def processTypeScript(entry_path)
			# check if this entry point file's crawl data is available
			if !@file_crawl_data.has_key?(entry_path)
				# it isn't
				# return a failure
				return(-1)
			end

			# stores this method return value
			return_value = 0

			# stores whether the TS compiler needs to be executed
			compile_file = false

			# stores whether this TS file's combined JS file needs to be built
			combine_file = false

			# build the path for this TypeScript entry point file's combined JS file
			combined_path = "#{File.dirname(@file_crawl_data[entry_path][:out_path])}/#{File.basename(@file_crawl_data[entry_path][:out_path], ".*")}.#{@@ts_combined_extra_path_}.js"

			# stores the files that need to be checked for their modify times
			files_to_check = []

			# stores the files that have already been checked
			files_checked = []

			# check if the scan cycle this method was called from is in "force build" mode
			if @force_build
				# it is
				# compile this entry point file
				compile_file = true

				# build this entry point file's combined file
				combine_file = true
			else
				# it isn't
				# check if the combined JS file exists
				if !File.exist?(combined_path)
					# it doesn't
					# the combined file needs to be built
					combine_file = true
				else
					# it does
					# store the combined file's modify time
					combined_path_mtime = File.stat(combined_path).mtime
				end

				# add the entry point file and its direct imported files to the files to be checked
				files_to_check = @file_crawl_data[entry_path][:imports].clone.push(entry_path)

				# loop through each relevant file
				begin
					# get the next file to check
					abs_path = files_to_check.pop()

					# check if this file's compiled file already exists
					if File.exist?(@file_crawl_data[abs_path][:out_path])
						# it does
						# store this file's modify time
						abs_path_mtime = File.stat(abs_path).mtime

						# check if this file was modified after it was last compiled
						if abs_path_mtime > File.stat(@file_crawl_data[abs_path][:out_path]).mtime
							# it was
							# the compiler needs to be executed again and the combined file needs to be built
							compile_file = true
							combine_file = true

							# no need to continue checking the remaining files
							break
						# it wasn't -> check if it was modified after it was used in the entry point's combined JS file
						# only relevant if the combined file is still flagged as not needing to be built
						elsif !combine_file && abs_path_mtime > combined_path_mtime
							# it was
							# the combined file needs to be built
							combine_file = true
						end

						# add this iteration's file to the array of checked files
						files_checked.push(abs_path)

						# add this iteration file's imported files to be checked
						# NOTE: only the files that haven't been found yet
						files_to_check = files_to_check | (@file_crawl_data[abs_path][:imports].clone - files_checked)
					else
						# it doesn't
						# the compiler needs to be executed again and the combined file needs to be built
						compile_file = true
						combine_file = true

						# no need to continue checking the remaining files
						break
					end
				end while !files_to_check.empty?
			end

			# check if the compiler needs to be called
			if compile_file
				# it does
				# print message informing that the TS compiler is being executed
				@cli_obj.printStr("The TypeScript files are being compiled by the TS compiler\n", true)

				# stores the command line instruction
				cmd_string = "tsc"

				# check if a path to a tsconfig.json file is set
				if @config_content["options"] != nil && @config_content["options"].has_key?("tsconfig")
					# it is, so run tell the "tsc" to run the project at that path
					cmd_string += " -p #{File.absolute_path(@config_content["options"]["tsconfig"].to_s.strip.gsub(/\\/, "/"), @config_file_dirname)}"
				else
					# it isn't
					# check if there are any explicit options for the TS compiler
					if @config_content["options"] != nil && @config_content["options"].has_key?("tsc_opts")
						# there are, so add them to the sommand line instruction
						cmd_string += " #{@config_content["options"]["tsc_opts"]}"
					else
						# there aren't, so add the default TS compiler options
						cmd_string += " #{@@config_validation_content_["key_accepts"]["options"]["each_value"]["key_accepts"]["tsc_opts"]["default_value"].to_s} --outDir #{File.dirname(@file_crawl_data[entry_path][:out_path])}"
					end

					# build an array with all the files that need to be compiled
					# NOTE: will use the data already gathered from the algorithm, at the start of this method,
					# 		that determined there are files in need of compilation
					files_to_check = files_to_check | (@file_crawl_data[entry_path][:imports].clone - files_checked)

					# loop while there are relevant files to check
					while !files_to_check.empty?
						# get the next path to check
						abs_path = files_to_check.pop()

						# add this file's imports to be checked
						files_to_check = files_to_check | (@file_crawl_data[abs_path][:imports].clone - files_checked)

						# add the file crawled to the files to be compiled
						files_checked.push(abs_path)
					end

					# add the file paths to the command line instruction
					cmd_string += " #{files_checked.join(" ")}"
				end

				# execute the command line instruction calling the SASS compiler
				result = system(cmd_string)

				if result === nil || result === false
					# something went wrong with the SASS compiler
					# print error message
					@cli_obj.printStr("=> ERROR: The TypeScript files couldn't be compiled by the TS compiler", true)

					# return a failure
					return(-1)
				end

				# at this point, the compilation was successful
				return_value = 1
			end

			# check if this TS entry point file's combined JS file needs to be built
			if combine_file
				# it does
				# call for this entry point file's combined JS file to be (re)built
				if !combineTypeScript(entry_path, combined_path)
					# something went wrong while building the combined JS file
					# print error message
					@cli_obj.printStr("=> ERROR: The TypeScript file \"#{entry_path}\" associated combined javascript file couldn't be built", true)

					# return a failure
					return(-1)
				end
			end

			# return
			return(return_value)
		end

		# handles creating a JS file for each TypeScript entry point file that is the entry point and all its
		# imports combined in 1 JS file, which will then be added to the watch rule's JS output file
		# receives the absolute path to an entry point TypeScript file and its combined JS absolute path
		# returns true if successful, false otherwise
		def combineTypeScript(entry_path, combined_path)
			# store the lambda that will read a file and paste all the imported files' content
			# returns the content of all the files in the import chain together or
			# false on failure
			# NOTE: will be called recursively
			lambda_func = lambda { |files_handled, file_path|
				# add this file's absolute path to the files that have been handled
				# this avoids a potential endless loop (if 2 files import each other) and ending up
				# with multiple copies of a file in the combined file
				files_handled.push(file_path)

				# check if this file exists
				if !File.exist?(file_path)
					# it doesn't
					# print error message
					@cli_obj.printStr("=> ERROR: The file \"#{file_path}\" couldn't be found", true)

					# return failure
					return(false)
				end

				# open the file in read-write mode, without truncating
				file_content = IO.read(file_path, mode: "r")

				# remove all the references defining the "__esModule" property on the "exports" object
				file_content.gsub!(/Object\.defineProperty\(exports, "__esModule"[^;]+;\n?/i, "")

				# loop through all the imports
				while (re_match = /(?:var|let|const)[\t ]+([^;=\t ]+)[\t ]*=[\t ]*require\(([^\);]+)\);/i.match(file_content)) != nil
					# resolve this import path to get an absolute path to the imported JS file
					import_path = resolveNodeImportPath(file_path, re_match[2], [])

					# check if an absolute path for this imported file was found
					if import_path === false
						# it wasn't
						# print error message
						@cli_obj.printStr("=> ERROR: The file \"#{re_match[2]}\", being imported in \"#{file_path}\", couldn't be found", true)

						# return failure
						return(false)
					end

					# check if the imported file is a JSON file
					if import_path.index(/\.json$/i) != nil
						# it is
						begin
							# read and parse the imported JSON file
							import_json_content = JSON.parse(IO.read(import_path))
						rescue Errno::ENOENT
							# something went wrong while opening and parsing the JSON file
							# print error message
							@cli_obj.printStr("=> ERROR: An error occured while opening/parsing the file \"#{import_path}\"", true)

							# return failure
							return(false)
						end

						# update the file content by removing the import statement
						file_content = "#{re_match.pre_match}#{re_match.post_match}"

						# loop through all the references to the variable this import was being stored in
						while (ref_re_match = Regexp.new("#{Regexp.escape("#{re_match[1]}")}((?:\\.\\w+)+)", Regexp::IGNORECASE).match(file_content)) != nil
							# stores the value to be replaced by this reference
							ref_replace_value = import_json_content

							# loop through the chain of properties being called in this reference
							ref_re_match[1].split(".").each { |property|
								# check if this "property" is empty
								if property.empty?
									# it is, so move on to next one
									next
								end

								# check if the current chunk of the imported JSON file has this property
								if ref_replace_value[property] === nil
									# it doesn't
									# print error message
									@cli_obj.printStr(
										"=> ERROR: The imported JSON file \"#{import_path}\" doesn't have the property \"#{property}\" in the reference \"#{re_match[1]}#{ref_re_match[1]}\"",
										true
									)

									# return failure
									return(false)
								end

								# advance deeper in the imported JSON file's content
								ref_replace_value = ref_replace_value[property]
							}

							# update the file content by replacing this reference with the replacement value
							file_content = "#{ref_re_match.pre_match}\"#{ref_replace_value}\"#{ref_re_match.post_match}"
						end
					else
						# it isn't
						# stores the string that will replace this import statement
						replacement_str = ""

						begin
							# check if the imported file has already been pasted somewhere else in the import chain
							if !files_handled.include?(import_path)
								# it hasn't
								# get the imported file's processed content
								replacement_str = lambda_func.call(files_handled, import_path)

								# check if the imported file was successfully processed
								if replacement_str === false
									# it wasn't
									# return failure
									# NOTE: any error messages were printed by the lambda function call
									return(false)
								end
							end
						rescue IOError
							# couldn't read this file
							# print error message
							@cli_obj.printStr("=> ERROR: The file \"#{import_path}\", being imported in \"#{file_path}\", couldn't be read", true)

							# return failure
							return(false)
						end

						# update the file content replacing the import statement with that file's processed content
						file_content = "#{re_match.pre_match}#{replacement_str}#{re_match.post_match}"

						# stores the regex object used to find any references to the variable this import was being stored in
						# being used to import that module's default export
						default_import_re = Regexp.new(Regexp.escape("#{re_match[1]}.default("), Regexp::IGNORECASE)

						# check if there are any references to the import of the default export
						if file_content.index(default_import_re) != nil
							# there are
							# acquire the contents of the file being imported
							imported_file_content = IO.read(import_path, mode: "r")

							# find the name of property that is the imported module's default export
							# NOTE: it might not exist if, for example, the imported module has a function named "default"
							if (re_match_default_export = /exports\.default[\t\n ]*=[\t\n ]*([\w]+);/i.match(imported_file_content)) != nil
								# a default export was found
								# replace all references to this default import with the corresponding property's name
								file_content.gsub!(default_import_re, "#{re_match_default_export[1]}(")
							end
						end

						# remove any remaining references to the variable this import was being stored in
						file_content.gsub!(Regexp.new(Regexp.escape("#{re_match[1]}."), Regexp::IGNORECASE), "")
					end
				end

				# return the processed file content
				# handling the "use strict" cases
				return(handleUseStrict(file_content))
			}

			# call the lambda function to process the imports
			combined_file_content = lambda_func.call([], @file_crawl_data[entry_path][:out_path])

			# check if the combined file's content was successfully created
			if combined_file_content === false
				# it wasn't
				# print error message
				@cli_obj.printStr("=> ERROR: The combined JS file for the entry point file \"#{entry_path}\" couldn't be built", true)

				# return failure
				return(false)
			end

			# stores the variable names already encountered in the global scope
			# NOTE: used in the loop below to add a "var " to any variables in the global scope
			# 			as the "exports." statement is remmoved from them
			declared_vars = []

			# process all "exports." statements and for each one decide how to handle it
			# loop while there are "exports." statements left to handle
			while (re_match = /exports\.([\w]+)[\t\n ]*([^\t\n ])[\t\n ]*([^;]+)[;,\n\)\}]\n?/i.match(combined_file_content)) != nil
				# check if this match is an assignment and if the assigned value and the receiver have the same content
				# or if it's a default export
				if re_match[2].eql?("=") && (re_match[1].eql?(re_match[3]) || re_match[1].eql?("default"))
					# yes
					# in these cases the entire match will be removed
					replacement_str = ""
				else
					# no -> either this match is not an assignment or the assigned value
					# and receiver don't have the same content
					# check if this match isn't an assignment
					if !re_match[2].eql?("=")
						# it isn't an assignment
						# in these cases remove the "exports."
						gsub_str = ""
					else
						# it is an assignment
						# build the anonymous function that removes all "{" from a string
						lambda_func = lambda { |file_path, text|
							# return the text with all "{" removed
							return(text.gsub(/\{/i, ""));
						}

						# count the number of relevant "{" that exist before this match
						open_bracket_count = re_match.pre_match.length - transformFile(@file_crawl_data[entry_path][:out_path], lambda_func, re_match.pre_match.clone).length

						# build the anonymous function that removes all "}" from a string
						lambda_func = lambda { |file_path, text|
							# return the text with all "{" removed
							return(text.gsub(/\}/i, ""));
						}

						# count the number of relevant "}" that exist before this match
						close_bracket_count = re_match.pre_match.length - transformFile(@file_crawl_data[entry_path][:out_path], lambda_func, re_match.pre_match.clone).length

						# check if this match is in the global scope and if it's the first
						# time this symbol is encountered
						if open_bracket_count === close_bracket_count && !declared_vars.include?(re_match[1])
							# it is
							# replace the "exports." with "var " since this variable is being declared here
							gsub_str = "var "

							# store that this symbol has been encountered in the global scope
							declared_vars.push(re_match[1])
						else
							# it isn't, so just remove the "exports."
							gsub_str = ""
						end
					end

					# store the replacement string
					replacement_str = re_match[0].gsub!(/^exports\./i, gsub_str)
				end

				# update the file content replacing the match string with its replacement
				combined_file_content = "#{re_match.pre_match}#{replacement_str}#{re_match.post_match}"
			end

			# check if the combined file already exists
			if File.exist?(combined_path)
				# it does
				begin
					# empty the combined file's content
					File.truncate(combined_path, 0)
				rescue Exception => e
					# something went wrong with the truncate() call
					# return failure
					return(false)
				end
			end

			# open the combined file in append mode (will create the file if it doesn't exist)
			file_obj = File.new(combined_path, "a")

			begin
				# write the combined file content
				file_obj << combined_file_content
			rescue Exception => e
				# something went wrong while writting to this file
				# print error message
				@cli_obj.printStr("=> ERROR: Couldn't write to the combined file at \"#{combined_path}\"", true)

				# return failure
				return(false)
			ensure
				# close the File object and resolve any pending write actions
				file_obj.close
			end

			# print message
			@cli_obj.printStr("The combined JavaScript file associated with the entry point TypeScript file \"#{entry_path}\" was successfully created", true)

			# at this point everything went ok
			return(true)
		end

		# receives a string and will check if it contains at least 1 reference to "use strict";
		# if it does then it will make sure that only 1 reference exists and it is at index zero
		# returns the processed string
		def handleUseStrict(text)
			# build the regexp pattern
			re_pattern = /"use strict";/i

			# check if there is at least 1 reference to - "use strict"; - in the provided string
			if (match_pos = text.index(re_pattern)) != nil
				# there is
				# check if the first occurance is at index zero
				if match_pos != 0
					# it isn't
					# add a new reference at the index zero
					text = "\"use strict\";#{text}"
				end

				# remove all references except for the one at index zero
				text = "#{text[0]}#{text[1..-1].gsub(re_pattern, "")}"
			end

			# return the final string
			return(text)
		end

		# receives the path to the output file and its source file(s)
		# will check if the output file needs to be rebuilt and will also call for the processing of
		# any non-bundle type files relevant for this output file
		# return TRUE if the output file is up-to-date or FALSE if it needs to be rebuilt
		def outputUpToDate(output_path, sources)
			# stores the return boolean
			# if the scan cycle this method was called from is in "force build" mode or the file
			# doesn't exist then flag the output file as not up-to-date to force its rebuilding
			up_to_date = !@force_build && File.exist?(output_path)

			# check if this output file is a bundle from multiple files
			joining = sources.length > 1

			# loop through each file in "sources"
			sources.each { |sources_current|
				# check if the current source file exists
				if !File.exist?(sources_current)
					# it doesn't
					# the output file needs to be rebuilt
					up_to_date = false
				else
					# it does
					# get the current source file's extension
					sources_current_ext = sources_current[sources_current.rindex(".") + 1..-1]

					# check if the current source file has a valid extension
					if @@valid_file_types_.has_key?(sources_current_ext)
						# it has
						# stores the absolute path of the file which modify time needs to be
						# compared to the output file's modify time
						relevant_file = sources_current

						# check if the current source file is of the same type as a bundle file
						if !@@valid_file_types_[sources_current_ext].eql?(sources_current_ext)
							# it isn't
							# check if a "process" action for this file type is defined
							if @@file_type_callbacks_[sources_current_ext] != nil && @@file_type_callbacks_[sources_current_ext].has_key?(:process)
								# it is
								# execute the "process" action
								process_result = self.send(@@file_type_callbacks_[sources_current_ext][:process], sources_current)

								# check if there was a successfull compilation of the file
								if process_result === 1
									# there was
									# the output file needs to be rebuilt
									up_to_date = false
								# check if there was a failled compilation of the file
								elsif process_result === -1
									# there was
									# print error message
									@cli_obj.printStr("=> ERROR: The file \"#{output_path}\" couldn't be built", true)

									# this output file needs to be rebuilt, but it can't since this relevant
									# file wasn't successfully updated, so return TRUE to signal scan() to move on
									# to the next bundle file
									return(true)
								else
									# there was no need to compile the file, which means the existing compiled file
									# is up-to-date and its modified time will need to be compared to the output file
									relevant_file = @file_crawl_data[sources_current][:out_path]
								end
							end
						end

						# check if the relevant file is newer than the output file
						# NOTE: only relevant if the output file is still flagged as being up-to-date
						if up_to_date && File.stat(relevant_file).mtime > File.stat(output_path).mtime
							# it is
							# the output file needs to be rebuilt
							up_to_date = false
						end
					end
				end
			}

			# check if the output file is still flagged as up-to-date and if it is check if
			# an associated auxiliary file exists
			if up_to_date && File.exist?("#{output_path}#{@@aux_file_extra_path_}")
				# it is flagged as up-to-date and an auxiliary file exists
				# open this output file's auxiliary file in read mode and get its contents
				aux_file_content = JSON.parse(IO.read("#{output_path}#{@@aux_file_extra_path_}", mode: "r"))

				# create an array with the absolute paths stored in the auxiliary file
				old_sources = aux_file_content["sources"].split(" ")

				# check if the relevant files used to build the current output file are still the
				# same relevant files for this output file (and in the same order)
				if sources != old_sources
					# they aren't -> either the files are different or they are in a different order
					# the output file needs to be built
					up_to_date = false
				end
			end

			# return the up-to-date status of this output file
			return(up_to_date)
		end

		# handles removing any text, from the provided string, that is inside a "#bundler remove" tag
		def removeTaggedText(text)
			# create the regexp pattern
		    re_pattern = /\/\*[\n\t ]*#bundler remove[\n\t ]*\*\//i

		    # stores the index of the starting tag or nil if not inside a tag
		    tag_block_start = nil

		    # auxiliary variable used to calculate the index in "text" that the search is in
		    cur_text_index = 0

		    # loop while there are tags left to process
		    while (re_match = re_pattern.match(text[cur_text_index..-1])) != nil
		        # check if this tag is opening a tag block
		        if tag_block_start == nil
		            # it is
		            # store the starting index, in "text", for this tag block
		            tag_block_start = cur_text_index + re_match.pre_match.length

		            # advance "cur_text_index" to the index of the character after the start of this match
		            cur_text_index = tag_block_start + 1
		        else
		            # it isn't
		            # store the ending index, in "text", for this tag block
		            tag_block_end = cur_text_index - 1 + re_match.pre_match.length + re_match[0].length

		            # change "text" to have all the text outside this tag block
		            text = "#{text[0...tag_block_start]}#{text[tag_block_end + 1..-1]}"

		            # reset "cur_text_index" to where this tag block started, since it was removed
		            cur_text_index = tag_block_start

		            # reset "tag_block_start" to nil since the next match will start a new tag block
		            tag_block_start = nil
		        end
		    end

		    # return the processed string
		    return(text)
		end

		# receives the path to the desired output file and its source file(s)
		# return TRUE if the output file was created or FALSE otherwise
		def createOutputFile(output_path, sources)
			# stores if the output file was successfully created
			result = true

			# check if the output file already exists
			if !File.exist?(output_path)
				# it doesn't
				# get the directory hierarchy of the output file
				directories = File.dirname(output_path).split("/")

				# if any of those directories doesn't exist, create them
				dir_path = ""
				directories.each { |directory|
					# build the absolute path so far
					dir_path += (dir_path.empty? ? "" : "/") + directory

					# check if this directory exists
					if !Dir.exist?(dir_path)
						# it doesn't
						begin
							# create this directory
							Dir.mkdir(dir_path)
						rescue SystemCallError
							# couldn't create this directory
							# return failure
							return(false)
						end
					end
				}
			end

			# stores the content of the output file
			output_file_content = ""

			# loop through each source files
			sources.each { |sources_current|
				# get the current source file's extension
				sources_current_ext = sources_current[sources_current.rindex(".") + 1..-1]

				# check if the current source file has a valid extension
				if @@valid_file_types_.has_key?(sources_current_ext)
					# it has
					# check if the current source file is of the same type as a bundle file
					if !@@valid_file_types_[sources_current_ext].eql?(sources_current_ext)
						# it isn't
						# check if files with this extension have a function that returns the relevant
						# file path to be used in the output file
						if @@file_type_output_basename_.has_key?(sources_current_ext)
							# they have
							# call the function that returns the relevant file's absolute path
							sources_current = @@file_type_output_basename_[sources_current_ext].call(sources_current)
						# they don't -> check if this file's crawl data is set and if a path to its compiled file is defined
						elsif @file_crawl_data.has_key?(sources_current) && @file_crawl_data[sources_current].has_key?(:out_path)
							# it is
							# change the current source file to be its respective compiled file
							sources_current = @file_crawl_data[sources_current][:out_path]
						end
					end

					# add this file to the output file's content
					output_file_content += IO.read(sources_current)
				else
					# return failure
					return(false)
				end
			}

			# handle any text that is inside a flag informing the program to remove it
			output_file_content = removeTaggedText(output_file_content)

			# check if this output file is a JS file
			if output_path.index(/\.js$/i) != nil
				# it is
				# call for the handling of "use strict" references
				output_file_content = handleUseStrict(output_file_content)
			end

			begin
				# open the output file in write mode (will create the file if it doesn't exist or truncate if it does)
				file_obj = File.new(output_path, "w")

				# add the current source file to the output file
				file_obj << output_file_content
			rescue Exception => e
				# something went wrong while reading/writting this file
				result = false
			ensure
				# close the File object and resolve any pending write actions
				file_obj.close
			end

			# check if the output file was created successfully
			if result
				# it was
				# create the auxiliary file, associated with this output file, that stores the
				# absolute paths of the files used to build the current output file
				# open the auxiliary file in append mode (will create the file if it doesn't exist)
				file_obj = File.new("#{output_path}#{@@aux_file_extra_path_}", "w")

				begin
					# store the contents of the auxiliary file
					file_obj << JSON.generate(
						{"sources": sources.join(" "), "minimized": false}
					)
				rescue Exception => e
					# something went wrong while writting this file
					# print warning message
					@cli_obj.printStr("=> WARNING: the file \"#{output_path}#{@@aux_file_extra_path_}\" couldn't be created", true)
				end

				# close the File object and resolve any pending write actions
				file_obj.close
			end

			# return the output creation status
			return(result)
		end

		# receives a path to a file and minimizes it
		# returns TRUE if successful or FALSE otherwise
		def minimizeFile(file_path)
			# create the anonymous function with the code to minimize the file's content
			lambda_func = lambda { |file_path, text|
				# stores all characters that don't need to have a whitespace before or after
				# NOTE: if they are inside a string, a regex or a comment they won't be considered for whitespace removal
				no_whsp_chars = [";",":",",","{","}","[","]","(",")","+","-","*","/","<",">","||","&&","=","!="]

				# stores the index to start searching for comments in this iteration chunk's text
				regex_start = 0

				# loop while there are inline comments to process
				while (match_data = text.match(@@re_inline_comment_, regex_start)) != nil
					# stores the start and end indexes of this comment
					comment_pos = Array.new

					# get the start index for this comment
					comment_pos[0] = match_data.begin(1)

					# check if the "//" found is an actual inline comment
					if text.slice(comment_pos[0]-5...comment_pos[0]).match(/http:/) != nil or text.slice(comment_pos[0]-6...comment_pos[0]).match(/https:/) != nil
						# it isn't, so ignore this "//"
						# advance the starting index for the next regex search to after this "//"
						regex_start = comment_pos[0] + 1
					else
						# it is
						# find the end of the next inline comment -> either the 1st line break or the end of this chunk of text
						regex_match = text.match(@@re_line_break_, comment_pos[0])

						# check if any line breaks were found after this comment's start index
						if regex_match === nil
							# no
							# this inline comment ends at this iteration chunk's text end
							comment_pos[1] = text.length - 1
						else
							# yes
							# this inline comment ends at that line break's index
							comment_pos[1] = regex_match.begin(1)
						end

						# edit the text by removing this inline comment
						text = text.slice(0...comment_pos[0]) + text.slice(comment_pos[1]..-1)
					end
				end

				# stores this iteration chunk's text in slices
				# those slices are formed by spliting the text across the multiline comments
				# this allows for different processing to be done to the comments
				# and to the non-comment text
				text_slices = Array.new

				# loop while there are multiline comments to process
				while (match_data = text.match(@@re_multiline_comment_start_)) != nil
					# stores the start and end indexes of this comment
					comment_pos = Array.new

					# get the start index for this comment
					comment_pos[0] = match_data.begin(1)

					# get the end index for this comment
					comment_pos[1] = text.index(@@re_multiline_comment_end_)

					# check if this comments end was found
					if comment_pos[1] === nil
						# it wasn't
						# assume the comment ends at the end of the text
						comment_pos[1] = text.length - 1

						# print error message
						@cli_obj.printStr("=> WARNING: In the file \"#{file_path}\", there is a multiline comment that doesn't have an explicit end symbol", true)
					else
						# it was -> advance the index to after the comment's end characters
						comment_pos[1] += 1
					end

					# store the non-comment text
					text_slices.push({
						:value => text.slice(0...comment_pos[0]),
						:type => :normal
					})

					# get the 2 characters after this comment's start characters
					comment_substr = text.slice(comment_pos[0]+2, 2)

					# check if those 2 characters indicate this comment is to be kept as is
					if comment_substr.match("^#{@@multiline_comment_keep_intact_}$") != nil
						# yes
						# store this comment's content, but remove the characters used to indicate
						# the comment is to be kept
						comment_value = text.slice(comment_pos[0], 2) + text.slice(comment_pos[0]+4..comment_pos[1])

						# store this comment type
						comment_type = :comment_intact
					# check if those 2 characters indicate this comment is to be kept, but collapsed to 1 line
					elsif comment_substr.match("^#{@@multiline_comment_keep_1line_}") != nil
						# yes
						# store this comment's content, but remove the characters used to indicate
						# the comment is to be kept
						comment_value = text.slice(comment_pos[0], 2) + text.slice(comment_pos[0]+3..comment_pos[1])

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
					text = text.slice(comment_pos[1]+1..-1)
				end

				# store the last non-comment text, if the loop run at least once, or the entire
				# chunk, if the loop didn't run
				text_slices.push({
					:value => text,
					:type => :normal
				})

				# in preparation for the removal of selected whitespaces
				# convert the no whitespace characters into a string ready for regex
				no_whsp_chars_str = Regexp.escape(no_whsp_chars.join("Q")).gsub(/Q/, "|")

				# reset this variable to store the rebuild string
				text = ""

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
							text_slice[:value].gsub!(@@re_line_break_, " ")
						else
							# it isn't, so remove all line breaks
							text_slice[:value].gsub!(@@re_line_break_, "")
						end

						# replace all multiple whitespaces (2+ whitespaces) with a single whitespace
						text_slice[:value].gsub!(/[[:space:]]{2,}/, " ")

						# remove whitespaces before specific characters
						text_slice[:value].gsub!(/[[:space:]](#{no_whsp_chars_str})/, "\\1")

						# remove whitespaces after specific characters
						text_slice[:value].gsub!(/(#{no_whsp_chars_str})[[:space:]]/, "\\1")
					end

					# add this text slice to the rebuilt string
					text += text_slice[:value]
				}

				# return the transformed text
				return(text)
			}

			# call the method that will apply the minimization code to all the parts
			# of the file's content that are not inside a string, a regex or a comment
			min_str = transformFile(file_path, lambda_func, "")

			# replace the content of the minimized file with the minimized text
			if IO.write(file_path, min_str) == 0
				# something went wrong while writing the minimized content to the file
				return(false)
			# the output file was successfully updated -> check if this output file's auxiliary file exists
			elsif File.exist?("#{file_path}#{@@aux_file_extra_path_}")
				# it does
				begin
					# read all of the auxiliary file's content and JSON parse it
					aux_file_content = JSON.parse(IO.read("#{file_path}#{@@aux_file_extra_path_}", mode: "r"))

					# update the "minimized" property to true
					aux_file_content["minimized"] = true

					# open the auxiliary file, truncating it
					file_obj = File.new("#{file_path}#{@@aux_file_extra_path_}", "w")

					# store the updated contents of the auxiliary file
					file_obj << JSON.generate(aux_file_content)
				rescue Exception => e
					# something went wrong while reading/writting this file
					# print warning message
					@cli_obj.printStr(
						"=> WARNING: the file \"#{file_path}#{@@aux_file_extra_path_}\" couldn't be updated with"\
						" the minimized status of its respective output file.",
						true
					)
				ensure
					# close the File object and resolve any pending write actions
					file_obj.close
				end
			end

			# at this point the minimization was successful (even if the auxiliary file couldn't be updated)
			return(true)
		end

		# receives an absolute path to a file that will be read and its contents crawled
		# any chunks of its content that are not inside a string or a regex will be passed
		# through the provided anonymous function
		# OPTIONALY: can receive the specific text to be transformed, in which case the file
		# at file_path will not be read
		# returns a string with the file's content after the transformation
		# NOTE: the anonymous function provided expects 2 parameters - the absolute path
		# 			to the file being transformed and the string to transform -
		# 			and should return the transformed string
		def transformFile(file_path, lambda_func, text = "")
			# check if a specific text to be transformed was provided
			if !text.empty?
				# it was
				file_contents = text
			else
				# it wasn't
				# open the file and read its contents
				file_contents = IO.read(file_path, mode: "r")
			end

			# stores the minimized text as it is built
			transformed_str = ""

			# stores temporary parts of the file for processing
			aux_str = ""

			# stores this iteration's text chunk starting index
			chunk_pos_i = 0
			# stores this iteration's text chunk ending index
			chunk_pos_e = 0

			# stores whether an iteration is handling a string
			inside_str = false

			# check if the first character in the file is a single or double quote or a ` (ES6 string)
			if file_contents[0].match(/[\'\"\`]/) != nil
				# it is, so the file starts with a string
				inside_str = true
			end

			# stores whether an iteration is handling a regex
			inside_regex = false

			# loop while there's content to process
			# NOTE: the logic used is based on the existance of strings and regexps in the file
			# 		since strings/regexps are not to be processed, the code will search for the start
			# 		of the next string/regexp and process any content that is in between
			while chunk_pos_e < file_contents.length - 1
				# calculate the index to start searching the next iteration's start index
				search_start_index = chunk_pos_e + 1

				# check if this iteration's chunk is handling a string or a regex
				if inside_str || inside_regex
					# it is
					# check if its handling a string
					if inside_str
						# it is
						# find the relevant closing quote to the currently open string
						# NOTE: the closing quote has to be of the same type as the opening quote (single or double) or
						# NOTE: the character at index "chunk_pos_e" is the currently open string's quote
						# the relevant quotes are the ones either not precided by a back slash OR with an even number
						# of backslashes preciding it -> in both cases the quote is not escaped

						# find the closest non-escaped quote with preciding backslashes
						match_even_slash = file_contents[search_start_index..-1].match("[^\\\\](?:\\\\\\\\)+(#{file_contents[chunk_pos_e]})")

						# check if the character at index "search_start_index" is the relevant closing quote
						# this catches an empty string
						if file_contents[search_start_index] === file_contents[chunk_pos_e]
							# it is -> this string in the source file is an empty string ("" or '')
							match_no_slash_re = "(#{file_contents[chunk_pos_e]})"
						else
							# it isn't, so find the closest relevant quote
							match_no_slash_re = "[^\\\\](#{file_contents[chunk_pos_e]})"
						end

						# find the closest non-escaped quote with preciding backslashes
						match_no_slash = file_contents[search_start_index..-1].match(match_no_slash_re)

						# check if a quote was found
						if match_no_slash === nil && match_even_slash === nil
							# it wasn't, so set the end index to the EOF
							chunk_pos_e = file_contents.length
						# check if only a quote precided by an even number of backslashes was found
						elsif match_no_slash === nil
							# it was, so calculate the index in "file_contents" of the quote found
							# NOTE: the capture group's index already compensates for the fact that the full match's index
							# 		is offset by the number of backslashes before the quote
							chunk_pos_e = search_start_index + match_even_slash.begin(1)
						# check if only a quote precided by no backslashes was found
						elsif match_even_slash === nil
							# it was, so calculate the index in "file_contents" of the quote found
							# NOTE: the capture group's index already compensates for the fact that the full match's index
							# 		is offset by the number of backslashes before the quote
							chunk_pos_e = search_start_index + match_no_slash.begin(1)
						else
							# both cases of a quote were found
							# determine the one that comes first
							if match_no_slash.begin(1) <= match_even_slash.begin(1)
								# the quote with no preciding backslashes comes first
								quote_index = match_no_slash.begin(1)
							else
								# the quote with even number of preciding backslashes comes first
								quote_index = match_even_slash.begin(1)
							end

							# NOTE: the capture group's index already compensates for the fact that the full match's index
							# 		is offset by the number of backslashes before the quote
							chunk_pos_e = search_start_index + quote_index
						end
					else
						# it isn't, its handling a regex
						chunk_pos_e += file_contents[chunk_pos_e..-1].match(@@re_regex_)[1].length - 1
					end

					# don't change any of the text inside a string or regex
					# get this iteration's text chunk, including both the start and end
					# string/regex delimiters
					aux_str = file_contents[chunk_pos_i..chunk_pos_e]

					# check if the quote or regex found as the end for this iteration's text chunk is inside a comment
					if insideComment?(aux_str)
						# it is, so ignore it
						next
					end

					# adjust control variables for next iteration
					# since this iteration was handling a string/regex, then the next iteration
					# won't be handling a string/regex
					inside_str = false
					inside_regex = false

					# the next iteration will start in the character after this iteration's
					# string/regex end delimiter
					chunk_pos_i = chunk_pos_e + 1
				else
					# it isn't inside a string or regex
					# find the next single or double quote and the next regex in the source file
					# NOTE: this pattern doesn't match a string in index zero of the file, but if there
					# 		is a string at index zero, this loop starts with inside_str = true
					str_index = file_contents.index(/[^\\][\"\'\`]/, search_start_index)
					re_index = file_contents.index(@@re_regex_, search_start_index)

					# check if a quote or regex was found
					if str_index === nil && re_index === nil
						# it wasn't
						# set the end index to the EOF
						chunk_pos_e = file_contents.length
					else
						# stores if this iteration stops on a string
						ends_on_str = false

						# check if only a string was found
						if re_index === nil
							# it was
							ends_on_str = true
						# check if both a string and a regex were found
						# and if the string comes first
						elsif str_index != nil && str_index <= re_index
							# the string comes first
							ends_on_str = true
						end

						# check if this iteration ends on a string
						if ends_on_str
							# it does
							# add 1 since the index of the match starts on the character before the quote
							# due to the regex pattern being used
							chunk_pos_e = str_index + 1

							# the next iteration will deal with a string
							inside_str = true
						else
							# it doesn't, it ends on a regex
							# set the end index to the regex's start delimiter
							chunk_pos_e = re_index

							# the next iteration will deal with a regex
							inside_regex = true
						end
					end

					# get this iteration's text chunk, excluding the quote at the end of the chunk
					aux_str = file_contents[chunk_pos_i...chunk_pos_e]

					# check if the quote or regex found as the end for this iteration's text chunk is inside a comment
					if insideComment?(aux_str)
						# it is
						# the next iteration won't be inside a string or a regex, since the found delimiter is going
						# to be ignored
						inside_str = false
						inside_regex = false

						# ignore it
						next
					end

					# execute the necessary transformation to this iteration chunk's text
					aux_str = lambda_func.call(file_path, aux_str)

					# adjust control variables for the next iteration chunk's text
					# next iteration will start searching for a string after this iteration's end index
					chunk_pos_i = chunk_pos_e
				end

				# add this iteration's text chunk to the minimized text
				transformed_str += aux_str
			end

			# return the transformed string
			return(transformed_str)
		end

		# checks if the minimizeFile()'s iteration end index (quote or regex) is inside a comment
		# returns true if it is or false if not
		def insideComment?(text)
			# stores the start index of a comment
			comment_start = nil

			# stores the end index of a comment
			comment_end = nil

			# multiline comment
			# find the start index of the multiline comment closest to the quote
			comment_start = text.rindex(@@re_multiline_comment_start_)

			# check if a multiline comment was found
			if comment_start != nil
				# it was
				# find the end index to this multiline comment
				comment_end = text.rindex(@@re_multiline_comment_end_)

				# check if this quote is inside this multiline comment
				if comment_end === nil or comment_start > comment_end
					# it is
					# NOTE: if there is no end to the comment or the closest end is before the start
					# 		then the quote is inside an open comment
					return(true)
				end
			end

			# inline comment
			# find the start index of the inline comment closest to the quote
			comment_start = text.rindex(@@re_inline_comment_)

			# check if a valid inline comment was found
			# NOTE: ignore a // if they are part of a URL
			if comment_start != nil and text[comment_start-5...comment_start].match(/http:/) === nil and text[comment_start-6...comment_start].match(/https:/) === nil
				# it was
				# find the end index to this inline comment, which is the closest line break
				comment_end = text.rindex(@@re_line_break_)

				# check if this quote is inside this inline comment
				# NOTE: the relation between start and end positions is reversed, because the reverse string was used to find those positions
				if comment_end === nil or comment_start > comment_end
					# it is
					# NOTE: if there is no end to the comment or the closest end is before the start
					# 		then the quote is inside an open comment
					return(true)
				end
			end

			# at this point the text is not inside a comment
			return(false)
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
end
