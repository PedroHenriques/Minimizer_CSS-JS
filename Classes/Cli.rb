############################################################
#															#
# Ruby Minimizer for CSS and JS files v2.0.0				#
# 															#
# Copyright 2017, PedroHenriques 							#
# http://www.pedrojhenriques.com							#
# https://github.com/PedroHenriques							#
#															#
# Free to use under the MIT license.						#
# http://www.opensource.org/licenses/mit-license.php		#
#															#
############################################################

class Cli
	# receives a reference to the object this class should communicate with
	def initialize(caller_obj)
		# store caller_obj in an instance variable
		@caller_obj = caller_obj

		# print the welcome message
		printStr("Welcome to the CSS and JS Minimizer program!\nType HELP for a list of commands.\n", false)
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
				re_match = user_input.match(/^([^\s]+)(.+)?$/i)

				# check if the input matched the regexp
				if (re_match === nil)
					# it didn't
					# print error message
					printStr("=> Error: The input provided is not valid.\nType \"help\" for a list of valid commands.", true)

					next
				end

				# extract the command and parameters
				command = re_match[1].downcase
				parameters = re_match[2]

				# check if the command is valid
				if !["run", "help", "exit"].include?(command)
					# it isn't
					# print error message
					printStr("=> ERROR: The command " + command + " is not valid.\nType \"help\" for a list of valid commands.", true)

					# continue the loop alive
					output = 0
				else
					# it is -> try calling a method to process this command
					# if the method is called, store the return value
					output = self.send("process" + command.capitalize, parameters)

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

		# processes the "run" command
		def processRun(parameters)
			# check if any parameters were provided
			if parameters === nil
				# no
				re_match = nil
			else
				# yes
				# process the parameters to check if a sleep timer was provided
				re_match = parameters.match(/(\d*)/i)
			end

			# check if a timer was provided
			timer = -1.0
			if re_match != nil
				# it was
				# get the value and type cast to float
				timer = re_match[1].to_f
			end

			# pass the timer to the Application class
			@caller_obj.sleep_time = timer

			# signal this class that it should stop asking for commands and inform
			# the caller object to start running the program
			return(1)
		end

		# processes the "help" command
		def processHelp(parameters)
			# build the help text
			message = "---------------------------------\nThe valid commands are:\n"
			message += "\thelp: Help information\n"
			message += "\texit: Exit application\n"
			message += "\trun: Start the scan of files and minimizing them\n"
			message += "\tAn optional parameter can be provided, indicating the number of seconds to wait between each scan of the relevant files.\n"
			message += "\tEx: the command \"run 2\" will cause the program to wait 2 seconds between each scan.\n"
			message += "\tIf no value is provided, the default of #{Application.sleep_time_default} will be used.\n"
			message += "---------------------------------"

			# print the valid commands
			printStr(message, false)

			# signal this class to continue asking for commands
			return(0)
		end

		# processes the "exit" command
		def processExit(parameters)
			# signal this class that it should stop asking for commands and inform
			# the caller object to terminate the program
			return(-1)
		end
end
