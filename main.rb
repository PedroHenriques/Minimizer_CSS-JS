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

require "#{File.dirname(__FILE__)}/includes/autoloader.rb"

begin
	# instantiate the Application class
	application_obj = Application.new()

	# start the program
	application_obj.run()
rescue Interrupt => e
	# check if the Application class was instantiated
	if application_obj != nil
		#it was
		# print outro message
		application_obj.printOutroMsg()
	else
		# it wasn't
		puts("\n")
	end
rescue Exception => e
	puts "\n=> ERROR: #{e}"
	puts e.backtrace.join("\n")
end
