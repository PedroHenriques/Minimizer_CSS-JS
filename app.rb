# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 															 #
# Ruby Minimizer for CSS and JS files v1.2.2				 #
# 															 #
# Copyright 2015, PedroHenriques 							 #
# http://www.pedrojhenriques.com 							 #
# https://github.com/PedroHenriques 						 #
# 															 #
# Free to use under the MIT license.			 			 #
# http://www.opensource.org/licenses/mit-license.php 		 #
# 															 #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

require "#{File.dirname(__FILE__)}/Includes/autoloader.rb"

begin
	# create an object with the Minimize class
	minimize = Minimize.new()

	# store the outro message
	outro_msg = "\n\r=> Thank you for using this application!\n\rFollow this application at https://github.com/PedroHenriques/Minimizer_CSS-JS"
	# set the default command
	command = :none

	# print welcome message
	puts "\n\rWelcome to the CSS and JS Minimizer application!"
	puts "Type HELP for a list of commands.\n\r"

	# application loop
	# exit the app by terminating the console task (EX: CTRL + c) or issuing the close command
	exit = false
	while !exit
		begin
			# set default #seconds to wait between file scan cycles
			default_sleep_time = 5

			# if no command is currently active, ask for one
			if command == :none
				# grab the user's input
				print "\n\rPlease type your command: "
				action = gets.strip

				# validate action and set command + required data
				if action.downcase.eql?("help") # the user wants to see the help information
					command = :help
				elsif action.downcase.eql?("close") or action.downcase.eql?("exit") # the user wants to exit the application
					command = :close
				elsif aux_regex = action.match(/run\s?(\d*)/i) # the user wants to start the scan for documents
					command = :run

					# grab the inserted sleep time
					cg1 = aux_regex.captures

					# validate the captured value
					aux_sleep = cg1[0].to_f
					if cg1[0].length == 0 or aux_sleep < 0
						# if no sleep time wasn't specified, use the default vale
						sleep_time = default_sleep_time
					else
						# if a sleep time was specified, convert it to float and use it
						sleep_time = aux_sleep
					end

					# print running message
					puts "\n\rwatching for changes..."
					puts "=> CTRL-C to terminate\n\r"
				else
					command = :none
				end
			end

			# execute command
			case command
			when :help
				# print HELP information
				puts "\n\r---------------------------------\n\r"
				puts "You can use the following commands:\n\r"
				puts "	help => Help information"
				puts "	close OR exit => Exit application"
				puts "	run => Start the scan of files and minimizing them\n\r"
				puts "By default the application will wait " + default_sleep_time.to_s + " seconds between scanning the selected files for changes and, if needed, minimize them"
				puts "If, however, you want the application to use a different wait time, you can specify the desired wait time when calling the RUN command"
				puts "EX: The command \"run 10\" will start the file scan with a 10 second wait time between scan cycles\n\r"
				puts "NOTE: The wait time has to be positive and can be a decimal number"
				puts "\n\r---------------------------------\n\r"

				# reset command to none, for next loop iteration to ask for a command
				command = :none
			when :close
				# print outro message
				puts outro_msg

				# force application loop to end
				exit = true
				next
			when :run
				# call main method of the class that will check the specified files for changes and update the minimized versions when needed
				minimize.watch()

				# wait before starting the next scan cycle
				sleep sleep_time
			else
				puts "\n\rThe command inserted is not valid!"
				puts "Type HELP for a list of valid commands.\n\r"
			end
		rescue Interrupt => e
			# if currently running scan, stop and ask for next command
			if command == :run
				# reset command to none, for next loop iteration to ask for a command
				command = :none
			else
				# else, exit application
				raise e
			end
		rescue Exception => e
			raise e
		end
	end
rescue Interrupt => e
	# print outro message
	puts outro_msg
rescue Exception => e
	puts "\n\r=> ERROR: #{e}"
end
