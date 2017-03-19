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

require "#{File.dirname(__FILE__)}/Includes/autoloader.rb"

begin
	# instantiate the Application class
	application_obj = Application.new()

	# start the program
	application_obj.run()
rescue Interrupt => e
	# print outro message
	application_obj.printOutroMsg()
rescue Exception => e
	puts "\n=> ERROR: #{e}"
	puts e.backtrace.join("\n")
end
