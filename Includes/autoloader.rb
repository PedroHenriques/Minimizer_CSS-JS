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

# load classes
dir = Dir.new("#{File.dirname(File.dirname(__FILE__))}/Classes")
dir.each do |file|
	if file.match(/^(.|..)$/)
		next
	end

	require "#{File.dirname(File.dirname(__FILE__))}/Classes/#{file}"
end
dir.close
