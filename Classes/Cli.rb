# # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 																									 	#
# Bundler and Minimizer for Web files v3.1.0				 	#
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

class Cli
	# receives a reference to the object this class should communicate with
	def initialize(caller_obj)
		# class variable storing the valid commands
		@@valid_commands_ = ["run", "build", "help", "exit", "init"]

		# class variable storing the flag names and anonymous functions with their processing
		# format: array of flags = {:commands => array of commands for the flag, :anon_func => anonymous function}
		@@valid_flags_ = {
			# handles the flags that set the program to scan in "watch" mode
			["-w", "--watch"] => {
				:commands => ["run"],
				:anon_func => lambda { @caller_obj.cmd_line_args(:watch_mode, true) }
			},
			# handles the flags that set the program to scan only once
			["--no-watch"] => {
				:commands => ["run", "build"],
				:anon_func => lambda { @caller_obj.cmd_line_args(:watch_mode, false) }
			},
			# handles the flags that set the program to run in "force build" mode
			["-f", "--force"] => {
				:commands => ["run", "build"],
				:anon_func => lambda { @caller_obj.cmd_line_args(:force_build, true) }
			},
			# handles the flags that set the program to minimize the output files
			["-m", "--min"] => {
				:commands => ["run", "build"],
				:anon_func => lambda { @caller_obj.cmd_line_args(:minimize, true) }
			},
			# handles the flags that set the program to not minimize the output files
			["--no-min"] => {
				:commands => ["run", "build"],
				:anon_func => lambda { @caller_obj.cmd_line_args(:minimize, false) }
			}
		}

		# class variable storing the help text, extracted from the help_text.json file
		@@help_text_content_ = nil

		# stores caller_obj in an instance variable
		@caller_obj = caller_obj

		# print the welcome message
		printStr("Welcome to the CSS and JS Minimizer program!\nType HELP for a list of commands\n", false)
	end

	# receives a string to be printed to the console
	# and a boolean -> true = add the current time to the message; false = don't add
	def printStr(string, add_time)
		# stores the initial part of message to print, before the provided string
		message_intro = "\n"

		# check if the current time should be added
		if add_time
			# it should
			message_intro += "[" + Time.now.strftime("%H:%M:%S") + "] "
		end

		# print the message
		print(message_intro + string)
	end

	# prompts the user for a command to execute and then calls the respective method
	# to process that command
	def askCommand()
		# The value that will be returned by this method
		# 0 = end program | 1 = start running the program
		output = 0

		begin
			# loop untill the user calls the RUN command or one of the program termination commands
			end_scan = false
			while !end_scan
				# ask the user for a command
				printStr("\n--> Please type a command: ", false)
				user_input = gets.strip

				# get the relevant data from the command given
				# NOTE: 1st pass on the input to grab the command
				# 		Any parameters provided will be processed by the command's method
				re_match = user_input.match(/^([^\s]+)[ ]*((?:[^-\s]+[ ]*)+)?((?:[ ]+-{1,2}[\w-]+)+)?$/i)

				# check if the input matched the regexp
				if (re_match === nil)
					# it didn't
					# print error message
					printStr("=> Error: The input provided is not valid.\nType \"help\" for a list of valid commands", true)

					next
				end

				# extract the command, parameters and flags
				command = re_match[1].downcase
				parameters = re_match[2]
				flags = re_match[3]

				# check if the command is valid
				if !@@valid_commands_.include?(command)
					# it isn't
					# print error message
					printStr("=> ERROR: The command \"#{command}\" is not valid.\nType \"help\" for a list of valid commands", true)

					# continue the loop alive
					output = 0
				else
					# it is -> try calling a method to process this command
					# if the method is called, store the return value
					output = self.send("process" + command.capitalize, parameters, flags)

					# check if this loop should continue
					if output != 0
						# the loop should end
						end_scan = true
					end
				end
			end
		rescue Interrupt => e
			# the user pressed CTRL-C so terminate the program
			output = -1
		end

		return(output)
	end

	private

		# builds an array with all the individual flags provided in the command line argument
		# will split short flags given together into separate flags
		def buildFlags(flag_str)
			# check if the parameter is "empty"
			if flag_str === nil || flag_str.empty?
				# it is -> nothing to do
				return([])
			end

			# stores the individual flags
			flags = Array.new

			# loop while there are flags left to process
			while (re_match = /(-{1,2}[\w-]+)/i.match(flag_str)) != nil
				# check if this is a long flag
				if re_match[1].index(/--[^-]/i) != nil
					# it is
					# no processing needed, so store this flag as is
					flags.push(re_match[1])
				else
					# it isn't -> it's a short flag
					# loop through each character of this short flag
					# NOTE: starting at index 1, since index 0 is the "-"
					(1...re_match[1].length).each { |flag_char|
						# add this flag to the end of "flags"
						# NOTE: adding an "-" before this character
						flags.push("-#{re_match[1][flag_char]}")
					}
				end

				# change flag_str to have all the text after this match
				flag_str = re_match.post_match
			end

			# return the unique split flags
			return(flags.uniq)
		end

		# go through each flag, checks if it's valid for the given command, and executes
		# that flag's anonymous function if needed
		def implementFlags(command, flag_str)
			# build an array with all the individual flags provided
			flags = buildFlags(flag_str)

			# check if any relevant flag was provided
			if flags.empty?
				# no, so bail out
				return
			end

			# loop through all the relevant flags
			@@valid_flags_.each { |flag_array, flag_data|
				# check if these flags are supported by the proided command
				if !flag_data[:commands].include?(command)
					# they aren't, so move on
					next
				end

				# check if the provided flags include these relevant flags
				# NOTE: checking if the length of the union of the 2 arrays minus the length of "flags"
				# 		is lower than the length of "flag_array", which indicates that at least 1 of the
				# 		"flag_array" elements is present in "flags"
				if (flags | flag_array).length - flags.length < flag_array.length
					# it does
					# call this flag's anonymous function
					flag_data[:anon_func].call()
				end
			}
		end

		# processes the "run" command
		def processRun(parameters, cmd_flags)
			# check if any parameters were provided
			if parameters != nil
				# yes
				# process the parameters to check if a sleep timer was provided
				# check if a timer was provided
				if (re_match = parameters.match(/(\d+)/i)) != nil
					# it was
					# get the value and type cast to float
					timer = re_match[1].to_f

					# check if the timer value is positive
					if timer > 0.0
						# it is
						# pass the timer to the Application class instance
						@caller_obj.cmd_line_args(:sleep_timer, timer)
					end
				end
			end

			# check if any flags were provided
			if cmd_flags != nil
				# yes, there are flags
				# process them
				implementFlags("run", cmd_flags)
			end

			# signal this class that it should stop asking for commands and inform
			# the caller object to start running the program
			return(1)
		end

		# processes the "help" command
		def processHelp(parameters, cmd_flags)
			begin
				# check if the help text has been extracted from the help_text.json file
				if @@help_text_content_ === nil
					# it hasn't
					@@help_text_content_ = JSON.parse(IO.read("#{File.dirname(File.dirname(__FILE__))}/data/help_text.json"))
				end
			rescue Errno::ENOENT
				# something went wrong while opening and parsing the JSON file
				# raise an error message
				raise("=> ERROR: An error occured while opening/parsing the file #{File.dirname(File.dirname(__FILE__))}/data/help_text.json.")
			end

			# check if any flags were provided
			if cmd_flags != nil
				# yes, there are flags
				# process them
				implementFlags("help", cmd_flags)
			end

			# build the start of the help text
			message = "\n------\n"

			# stores the specific command help text should be given for
			help_command = ""

			# check if a specific command to get help text for was provided
			if parameters != nil && (re_match = parameters.match(/(\w+)/i)) != nil
				# yes
				# get the value of the command specific help text is being requested
				command_name = re_match[1].strip

				# check if the help_text.json file has detail help text for this command
				if @@help_text_content_.has_key?(command_name) && @@help_text_content_[command_name].has_key?("detail")
					# it does
					# check if the requested detail text is for the valid flags
					if command_name == "flags"
						# it is
						# add the help text to the message to print
						message += "the valid flags are:"

						# loop through the valid flags
						@@valid_flags_.each { |flag_names, flag_data|
							# check if the help_text.json file has information for this flag
							if @@help_text_content_[command_name]["detail"].has_key?(flag_names.first)
								# it does
								# add the help text to the message to print
								message += "\n\n#{flag_names.join(" ")}\n   valid for the commands: #{flag_data[:commands].join(", ")}\n   #{@@help_text_content_[command_name]["detail"][flag_names.first]}"
							end
						}
					else
						# it isn't
						# add the help text to the message to print
						message += "the syntax for the \"#{command_name}\" command is: #{@@help_text_content_[command_name]["detail"]}"
					end
				end
			else
				# no
				# continue building the message to print
				message += "the valid commands are:\n"

				# loop through the valid commands
				@@valid_commands_.each { |command_name|
					# check if the help_text.json file has intro help text for this command
					if @@help_text_content_.has_key?(command_name) && @@help_text_content_[command_name].has_key?("intro")
						# it does
						# add the help text to the message to print
						message += "\n-> \"#{command_name}\": #{@@help_text_content_[command_name]["intro"]}\n"
					end
				}
			end

			# add the end of the help text
			message += "\n------"

			# print the valid commands
			printStr(message, false)

			# signal this class to continue asking for commands
			return(0)
		end

		# processes the "exit" command
		def processExit(parameters, cmd_flags)
			# check if any flags were provided
			if cmd_flags != nil
				# yes, there are flags
				# process them
				implementFlags("exit", cmd_flags)
			end

			# signal this class that it should stop asking for commands and inform
			# the caller object to terminate the program
			return(-1)
		end

		# process the "init" command
		def processInit(parameters, cmd_flags)
			# check if any flags were provided
			if cmd_flags != nil
				# yes, there are flags
				# process them
				implementFlags("init", cmd_flags)
			end

			# build the absolute path for the JSON config file
			json_path = "#{@caller_obj.config_file_dirname}/#{Application.config_file_basename_}"

			# check if a config JSON file already exists in the destination path
			if File.exist?(json_path)
				# it does
				# print warning message
				printStr("=> WARNING: A config file already exists in \"#{@caller_obj.config_file_dirname}\"", false)
			else
				# it doesn't
				begin
					# check if a directory for the config file is set
					if @caller_obj.config_file_dirname.empty?
						# it isn't
						# build the absolute path for the JSON config file, on the CWD
						json_path = "#{Dir.getwd}/#{Application.config_file_basename_}"
					end

					# create and open the JSON file
					file_obj = File.new(json_path, "w")

					# create the JSON string and write it to the config file
					file_obj << JSON.pretty_generate(
						{"watch":[{"paths":["."],"out":"assets","scss_in":[],"sass_in":[],"ts_in":[]}],"ignore":[],"options":{"watch_mode":true,"sleep_timer":5,"minimize":false}}
					)

					# close the File object and resolve any pending write actions
					file_obj.close

					# informe the Application class to search for the config file and handle it
					@caller_obj.handleConfigFile(Dir.getwd)

					# print the confirmation message
					printStr("=> The config file was created at \"#{json_path}\"", true)
				rescue Interrupt => e
					# something went wrong while handling the config file
					# bubble the exception up
					raise(e)
				rescue Exception => e
					# an error occured while creating and writing the JSON config file
					# print error message
					printStr("=> ERROR: The config file couldn't be created at \"#{json_path}\"", true)
				end
			end

			# signal this class to continue asking for commands
			return(0)
		end

		# processes the "build" command
		def processBuild(parameters, cmd_flags)
			# this command will run the application in no-watch mode and force build mode
			# store the flags that will configure the program for this effect
			required_flags = "--no-watch -f"

			# check if any flags were provided
			if cmd_flags != nil
				# yes, there are flags
				# add the required flags
				cmd_flags += " #{required_flags}"
			else
				# no, there are no flags
				# add the required flags
				cmd_flags = required_flags
			end

			# process the flags
			implementFlags("build", cmd_flags)

			# signal this class that it should stop asking for commands and inform
			# the caller object to start running the program
			return(1)
		end
end
